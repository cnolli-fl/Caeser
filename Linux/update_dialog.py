"""Linux update controls. Network and file operations run off the UI thread."""

import http.client
import platform
from pathlib import Path
from threading import Event

from PySide6.QtCore import QObject, QRunnable, QThreadPool, QUrl, Signal
from PySide6.QtGui import QDesktopServices
from PySide6.QtWidgets import QDialog, QHBoxLayout, QLabel, QProgressBar, QPushButton, QVBoxLayout

from updates import RELEASES_PAGE, appimage_path, check_for_update, install_update


CURRENT_VERSION = Path(__file__).with_name("VERSION").read_text(encoding="utf-8").strip()


class UpdateSignals(QObject):
    result = Signal(object)
    error = Signal(str)
    progress = Signal(int)


class UpdateTask(QRunnable):
    def __init__(self, action):
        super().__init__()
        self.action = action
        self.signals = UpdateSignals()

    def run(self):
        try:
            self.signals.result.emit(self.action(self.signals.progress.emit))
        except ValueError as error:
            self.signals.error.emit(str(error))
        except (OSError, http.client.HTTPException):
            self.signals.error.emit("Confira a conexão e a permissão de escrita na pasta do Caeser. Tente novamente.")


class UpdateDialog(QDialog):
    def __init__(self, parent):
        super().__init__(parent)
        self.setWindowTitle("Atualizações · Caeser")
        self.setMinimumWidth(420)
        self.target = None
        self.release = None
        self.operation = None
        self.cancelled = Event()

        root = QVBoxLayout(self)
        root.setContentsMargins(22, 20, 22, 20)
        root.setSpacing(14)
        title = QLabel(f"Caeser para Linux · {CURRENT_VERSION}")
        font = title.font()
        font.setBold(True)
        title.setFont(font)
        root.addWidget(title)
        self.status = QLabel()
        self.status.setWordWrap(True)
        root.addWidget(self.status)
        self.progress = QProgressBar()
        self.progress.setAccessibleName("Progresso da atualização")
        self.progress.hide()
        root.addWidget(self.progress)
        buttons = QHBoxLayout()
        root.addLayout(buttons)
        page = QPushButton("Ver versões")
        page.clicked.connect(self.open_releases)
        buttons.addWidget(page)
        buttons.addStretch()
        self.close_button = QPushButton("Fechar")
        self.close_button.clicked.connect(self.reject)
        buttons.addWidget(self.close_button)
        self.primary = QPushButton("Verificar")
        self.primary.setObjectName("primary")
        self.primary.clicked.connect(self.check)
        buttons.addWidget(self.primary)

    def open_releases(self):
        url = self.release.page_url if self.release else RELEASES_PAGE
        if not QDesktopServices.openUrl(QUrl(url)):
            self.status.setText(f"Abra este endereço no seu navegador: {url}")

    def run_task(self, action, success):
        self.primary.setEnabled(False)
        task = UpdateTask(action)
        self.operation = task
        task.signals.result.connect(success)
        task.signals.error.connect(self.show_error)
        task.signals.progress.connect(self.progress.setValue)
        QThreadPool.globalInstance().start(task)

    def check(self):
        self.status.setText("Procurando uma versão mais recente…")
        self.run_task(lambda _: check_for_update(CURRENT_VERSION, platform.machine()), self.show_release)

    def show_release(self, release):
        self.operation = None
        self.release = release
        self.primary.setEnabled(True)
        try:
            self.target = appimage_path() if release else None
        except OSError:
            self.target = None
        if release is None:
            self.status.setText("Você já está com a versão mais recente para Linux.")
        elif self.target is None:
            self.status.setText(f"A versão {release.version} está disponível. Baixe o AppImage em Ver versões.")
        else:
            size = release.size / 1_000_000
            self.status.setText(f"A versão {release.version} está disponível ({size:.0f} MB).")
            self.primary.setText("Baixar e instalar")
            self.primary.clicked.disconnect()
            self.primary.clicked.connect(self.download)
            self.primary.setEnabled(True)

    def download(self):
        release, target = self.release, self.target
        self.cancelled.clear()
        self.status.setText(f"Baixando a versão {release.version}…")
        self.close_button.setText("Cancelar")
        self.progress.setRange(0, 100)
        self.progress.setValue(0)
        self.progress.show()
        self.run_task(lambda report: install_update(release, target, report, self.cancelled.is_set), self.download_finished)

    def download_finished(self, installed):
        self.operation = None
        self.close_button.setText("Fechar")
        if installed:
            self.status.setText(f"Versão {self.release.version} instalada. Feche o Caeser e abra o mesmo AppImage.")
        else:
            self.progress.hide()
            self.status.setText("Download cancelado.")
            self.primary.setEnabled(True)

    def show_error(self, error):
        self.operation = None
        self.status.setText(error)
        self.close_button.setText("Fechar")
        self.progress.hide()
        self.primary.setEnabled(True)

    def reject(self):
        if self.operation is not None and self.progress.isVisible():
            self.cancelled.set()
            self.status.setText("Cancelando o download…")
        else:
            super().reject()
