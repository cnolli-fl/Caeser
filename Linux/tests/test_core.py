import tempfile
import unittest
from pathlib import Path
from core import Download, Library, batch_urls, clip_source, parse_clip, selector, spotify_match, validate_url


class CoreTests(unittest.TestCase):
    def test_spotify_validation(self):
        url = "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b?si=abc"
        self.assertEqual(validate_url(url, "Spotify"),
                         "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b")
        with self.assertRaises(ValueError):
            validate_url("https://evil.example/track/0VjIjW4GlUZAMYd2vXMi3b", "Spotify")
        with self.assertRaises(ValueError):
            validate_url(url, "YouTube")

    def test_mixed_batch(self):
        result = batch_urls("https://youtu.be/abc https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b", "YouTube")
        self.assertEqual([item[1] for item in result], ["YouTube", "Spotify"])

    def test_quality_and_mp3(self):
        self.assertIn("height<=1080", selector("1080p", "MP4"))
        self.assertEqual(selector("4K", "MP3"), "bestaudio/best")
        item = Download("https://youtu.be/abc", "YouTube", "/tmp", fmt="MP3")
        self.assertIn("--audio-quality", item.command())

    def test_library_recovers_interrupted(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "library.json"
            lib = Library(path)
            item = Download("https://youtu.be/abc", "YouTube", folder)
            self.assertEqual(lib.add([item, Download("https://youtu.be/abc", "YouTube", folder)]), 1)
            item.state = "Baixando"
            lib.save()
            reopened = Library(path)
            self.assertEqual(reopened.items[0].state, "Interrompido")
            self.assertTrue(reopened.paused)

    def test_preserves_distinct_ranges_in_the_saved_queue(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "library.json"
            lib = Library(path)
            url = "https://youtu.be/abc"
            first = Download(url, "YouTube", folder, fmt="MP4", clip=parse_clip("1:20", "1:50"))
            second = Download(url, "YouTube", folder, fmt="MP4", clip=parse_clip("1:50", "2:00"))
            self.assertEqual(lib.add([first, second, first]), 2)
            self.assertEqual([item.clip for item in Library(path).items], [first.clip, second.clip])
            for start, end in (("1:20", "1:20"), ("1:60", "2:10"), ("-1:00", "2:00"), ("1:20", "2:00")):
                with self.assertRaises(ValueError):
                    parse_clip(start, end, duration=110)

    def test_open_ended_clip_is_saved_and_uses_the_media_end(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "library.json"
            clip = parse_clip("1:20", " ", duration=110)
            self.assertIsNone(clip.end)
            self.assertEqual(clip.title, "1:20 até o fim")
            item = Download("https://youtu.be/abc", "YouTube", folder, fmt="MP3", clip=clip)
            lib = Library(path)
            lib.add([item])
            restored = Library(path).items[0]
            self.assertEqual(restored.clip, clip)
            args = restored.command()
            self.assertIn("*80-inf", args)
            self.assertIn("!is_live & duration >? 80", args)
            self.assertIn("[80s até o fim áudio]", args[args.index("-o") + 1])
        with self.assertRaises(ValueError):
            parse_clip("1:50", "", duration=110)

    def test_spotify_clip_follows_the_matched_track(self):
        link = "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b"
        clip_source(batch_urls(link, "Spotify"))
        with self.assertRaises(ValueError):
            clip_source(batch_urls(link.replace("track", "album"), "Spotify"))
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "track.spotdl"
            path.write_text('[{"download_url": "https://youtu.be/example"}]')
            matched = spotify_match(path)
            item = Download(link, "Spotify", folder, fmt="MP3", clip=parse_clip("1:20", "1:50"))
            command = item.command(matched)
            self.assertEqual(command[-1], "https://youtu.be/example")
            self.assertIn("*80-110", command)
            self.assertIn("ffmpeg_o:-vn -c:a libmp3lame -q:a 0 -f mp3", command)


if __name__ == "__main__":
    unittest.main()
