"""Exercise the desktop update button without changing the test runner's application."""

import hashlib
import io
import os
import tempfile
from pathlib import Path
from unittest.mock import patch

from PySide6.QtCore import QTimer
from PySide6.QtWidgets import QApplication

from app import UpdateDialog, Window
from updates import LinuxRelease


def main():
    app = QApplication([])
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        target = root / "Caeser.AppImage"
        header = b"\x7fELF\x02\x01\x01\x00AI\x02"
        target.write_bytes(header + b"old")
        content = header + b"new"
        update = LinuxRelease("0.4.0", "https://github.com/cnolli-fl/Caeser/releases/download/fixture",
                              hashlib.sha256(content).hexdigest(), len(content))

        with patch.dict(os.environ, {"APPIMAGE": str(target), "XDG_DATA_HOME": directory}), \
             patch("update_dialog.check_for_update", return_value=update) as check, \
             patch("updates.urllib.request.urlopen", return_value=io.BytesIO(content)):
            window = Window()
            window.show()
            timer = QTimer()
            step = "check"
            installed = False

            def interact():
                nonlocal step, installed
                dialog = window.findChild(UpdateDialog)
                if not dialog or not dialog.isVisible():
                    return
                if step == "check" and dialog.primary.isEnabled():
                    if dialog.primary.text() != "Baixar e instalar":
                        app.exit(1)
                        return
                    step = "install"
                    dialog.primary.click()
                if step == "install" and "instalada" in dialog.status.text():
                    installed = target.read_bytes() == content and dialog.progress.value() == 100
                    dialog.close_button.click()
                    app.exit(0 if installed else 1)

            timer.timeout.connect(interact)
            timer.start(25)
            QTimer.singleShot(0, window.updates.click)
            QTimer.singleShot(5000, lambda: app.exit(1))
            result = app.exec()
            if result or not installed or check.call_count != 1:
                raise SystemExit("O botão Atualizações não concluiu a atualização de teste.")
            window.close()


if __name__ == "__main__":
    main()
