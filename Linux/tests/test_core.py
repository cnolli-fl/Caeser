import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from core import Download, Library, batch_urls, selector, validate_url


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


if __name__ == "__main__":
    unittest.main()
