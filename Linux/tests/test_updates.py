import hashlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from updates import RELEASES_PAGE, LinuxRelease, appimage_path, install_update, select_update


IMAGE = b"\x7fELF\x02\x01\x01\x00AI\x02"
CONTENT = IMAGE + b"new AppImage"
DIGEST = hashlib.sha256(CONTENT).hexdigest()


def release(version, arch="x86_64"):
    tag = f"linux-v{version}"
    name = f"Caeser-{version}-Linux-{arch}.AppImage"
    return {"tag_name": tag, "prerelease": True, "assets": [{
        "name": name, "state": "uploaded", "browser_download_url": f"{RELEASES_PAGE}/download/{tag}/{name}",
        "digest": "sha256:" + DIGEST, "size": len(CONTENT),
    }]}


class UpdateTests(unittest.TestCase):
    def test_selects_newest_linux_prerelease_for_running_arch(self):
        wrong_project = release("0.11.0")
        wrong_project["assets"][0]["browser_download_url"] = "https://example.com/caeser.AppImage"
        releases = [release("0.2.0"), release("0.10.0"), release("0.9.0"),
                    release("1.0.0", "aarch64"), dict(release("2.0.0"), draft=True),
                    dict(release("3.1.2"), tag_name="v3.1.2"), wrong_project]
        self.assertEqual(select_update(releases, "0.2.0", "x86_64").version, "0.10.0")
        self.assertEqual(select_update(releases, "0.2.0", "aarch64").version, "1.0.0")
        self.assertIsNone(select_update(releases, "0.10.0", "x86_64"))

    def test_installs_to_original_path_and_leaves_library_alone(self):
        update = select_update([release("0.4.0")], "0.3.0", "x86_64")
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "Caeser.AppImage"
            target.write_bytes(IMAGE + b"old AppImage")
            target.chmod(0o755)
            library = target.with_name("library.json")
            library.write_text("fila antiga", encoding="utf-8")
            progress = []
            with patch.dict("os.environ", {"APPIMAGE": str(target)}):
                self.assertEqual(appimage_path(), target.resolve())
            with patch("updates.urllib.request.urlopen", return_value=io.BytesIO(CONTENT)):
                self.assertTrue(install_update(update, target, progress.append, lambda: False))
            self.assertEqual(target.read_bytes(), CONTENT)
            self.assertTrue(target.stat().st_mode & 0o100)
            self.assertEqual(library.read_text(encoding="utf-8"), "fila antiga")
            self.assertEqual(progress[-1], 100)
            self.assertEqual(set(Path(directory).iterdir()), {target, library})

    def test_cancelled_or_corrupt_download_keeps_old_appimage(self):
        update = LinuxRelease("0.4.0", f"{RELEASES_PAGE}/download/fixture", DIGEST, len(CONTENT))
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "Caeser.AppImage"
            previous = IMAGE + b"previous"
            target.write_bytes(previous)
            with patch("updates.urllib.request.urlopen", return_value=io.BytesIO(IMAGE + b"corrupt")):
                with self.assertRaises(ValueError):
                    install_update(update, target, lambda _: None, lambda: False)
            with patch("updates.urllib.request.urlopen", return_value=io.BytesIO(CONTENT)):
                self.assertFalse(install_update(update, target, lambda _: None, lambda: True))
            self.assertEqual(target.read_bytes(), previous)
            self.assertEqual(list(Path(directory).iterdir()), [target])
