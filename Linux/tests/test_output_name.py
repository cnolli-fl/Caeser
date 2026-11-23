import tempfile
import unittest
from pathlib import Path
from core import Download, Library, output_name


class OutputNameTests(unittest.TestCase):
    def test_literal_name_and_saved_queue(self):
        name = output_name("  Minha música 100%.MP3 ")
        self.assertEqual(name, "Minha música 100%")
        with tempfile.TemporaryDirectory() as folder:
            item = Download("https://youtu.be/example", "YouTube", folder, fmt="MP3", file_name=name)
            args = item.command()
            self.assertEqual(args[args.index("-o") + 1], "Minha música 100%%.%(ext)s")
            library = Library(Path(folder) / "library.json")
            library.add([item])
            self.assertEqual(Library(library.path).items[0].file_name, name)
            other = Download(item.url, item.source, folder, fmt="MP3", file_name="Outro")
            self.assertNotEqual(item.key(), other.key())
            item.source = "Spotify"
            args = item.command()
            self.assertEqual(args[args.index("--output") + 1], "Minha música 100%.{output-ext}")

    def test_unsafe_names(self):
        self.assertIsNone(output_name(" "))
        for name in ("../arquivo", "CON", "aux.mp3", "{title}", "a\\b", ".", ".mp4"):
            with self.subTest(name=name):
                with self.assertRaises(ValueError):
                    output_name(name)
