"""Caeser desktop window for Fedora KDE and other Linux desktops."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from PySide6.QtCore import QProcess, QProcessEnvironment, QRunnable, QThreadPool, QTimer, Qt, Signal, QObject, QUrl, QSize
from PySide6.QtGui import QAction, QDesktopServices, QIcon, QKeySequence, QPixmap
from PySide6.QtWidgets import (QApplication, QComboBox, QDialog, QFileDialog, QFrame,
                               QHBoxLayout, QLabel, QListWidget, QListWidgetItem, QMainWindow,
                               QPushButton, QProgressBar, QScrollArea,
                               QTextEdit, QVBoxLayout, QWidget)

from core import (Download, FORMATS, Library, QUALITY_HEIGHT, batch_urls, is_spotify,
                  tool_command, tool_environment, tool_path, validate_url)


BG, SURFACE, FIELD, BORDER = "#0D2666", "#102D6C", "#244580", "#6086BB"
TEXT, MUTED, ACCENT, STRONG = "#FFFFFF", "#CFDFF5", "#94D2FF", "#0099FF"

STYLE = f"""
QWidget {{ background: {BG}; color: {TEXT}; font-family: 'Noto Sans', 'Inter', sans-serif; font-size: 13px; }}
QMainWindow, QDialog, QScrollArea, QScrollArea > QWidget > QWidget {{ background: {BG}; }}
QFrame#card {{ background: {SURFACE}; border: 1px solid {BORDER}; border-radius: 20px; }}
QFrame#preview, QFrame#status {{ background: {FIELD}; border: 0; border-radius: 14px; }}
QLabel#muted {{ color: {MUTED}; }}
QTextEdit, QComboBox, QListWidget {{ background: {FIELD}; border: 1px solid {BORDER}; border-radius: 9px; padding: 8px; selection-background-color: {STRONG}; }}
QTextEdit:focus, QComboBox:focus, QPushButton:focus {{ border: 2px solid {ACCENT}; }}
QComboBox {{ min-height: 22px; padding-left: 12px; }}
QComboBox::drop-down {{ border: none; width: 28px; }}
QComboBox QAbstractItemView {{ background: {FIELD}; color: {TEXT}; selection-background-color: {STRONG}; }}
QPushButton {{ background: {FIELD}; border: 1px solid transparent; border-radius: 10px; padding: 8px 14px; min-height: 22px; }}
QPushButton:hover {{ background: #345795; }}
QPushButton:pressed {{ background: #1A3A78; }}
QPushButton:disabled {{ color: #91A4CA; background: #173671; }}
QPushButton#primary {{ background: {STRONG}; color: {TEXT}; border: 1px solid #48B9FF; border-radius: 18px; font-weight: 600; padding: 8px 18px; }}
QPushButton#primary:hover {{ background: #1EAAFF; }}
QPushButton#segment {{ border-radius: 10px; font-weight: 600; }}
QPushButton#segment:checked {{ background: #006CB6; border: 1px solid #58BDF9; }}
QProgressBar {{ background: {FIELD}; border: none; border-radius: 5px; height: 9px; text-align: center; }}
QProgressBar::chunk {{ background: {ACCENT}; border-radius: 5px; }}
QScrollBar:vertical {{ background: transparent; width: 9px; }}
QScrollBar::handle:vertical {{ background: {BORDER}; border-radius: 4px; min-height: 20px; }}
"""


def asset(name: str) -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys._MEIPASS) / "assets" / name
    return Path(__file__).resolve().parents[1] / name


def label(text: str, size: int = 13, bold: bool = False, muted: bool = False) -> QLabel:
    widget = QLabel(text)
    font = widget.font()
    font.setPointSize(size)
    font.setBold(bold)
    widget.setFont(font)
    widget.setWordWrap(True)
    if muted:
        widget.setObjectName("muted")
    return widget


class PreviewSignals(QObject):
    ready = Signal(int, dict)
    failed = Signal(int, str)


class PreviewTask(QRunnable):
    def __init__(self, serial: int, url: str, source: str):
        super().__init__()
        self.serial, self.url, self.source = serial, url, source
        self.signals = PreviewSignals()

    def run(self):
        try:
            preview = self.fetch()
            self.signals.ready.emit(self.serial, preview)
        except Exception as error:
            self.signals.failed.emit(self.serial, str(error))

    def fetch(self) -> dict:
        host = urllib.parse.urlparse(self.url).hostname
        if self.source == "Spotify":
            endpoint = "https://open.spotify.com/oembed?url=" + urllib.parse.quote(self.url, safe="")
        elif host in ("youtube.com", "www.youtube.com", "music.youtube.com", "youtu.be", "m.youtube.com"):
            endpoint = "https://www.youtube.com/oembed?format=json&url=" + urllib.parse.quote(self.url, safe="")
        else:
            endpoint = ""
        if endpoint:
            try:
                with urllib.request.urlopen(urllib.request.Request(endpoint, headers={"User-Agent": "Caeser/1.0"}), timeout=7) as response:
                    raw = response.read(128001)
                if len(raw) > 128000:
                    raise ValueError("Resposta de prévia muito grande.")
                obj = json.loads(raw)
                if obj.get("title"):
                    return {"title": obj["title"], "creator": obj.get("author_name", self.source),
                            "artwork": obj.get("thumbnail_url", ""), "duration": ""}
            except (OSError, ValueError):
                pass
        if self.source == "Spotify":
            raise ValueError("Prévia indisponível para este link.")
        args = ["--ignore-config", "--no-playlist", "--skip-download",
                  "--no-warnings", "--socket-timeout", "15", "--retries", "1", "--ignore-no-formats-error",
                  "--print", "{\"title\":%(title)j,\"creator\":%(uploader)j,\"artwork\":%(thumbnail)j,\"duration\":%(duration)j}",
                  "--", self.url]
        deno = Path(tool_path("deno"))
        if deno.is_file():
            args[0:0] = ["--js-runtimes", f"deno:{deno}"]
        command = tool_command("yt-dlp") + args
        result = subprocess.run(command, capture_output=True, text=True, timeout=55,
                                env=tool_environment(), check=False)
        if result.returncode:
            raise ValueError("Prévia indisponível para este link.")
        for line in result.stdout.splitlines():
            if line.startswith("{"):
                obj = json.loads(line)
                return {"title": obj.get("title") or "Vídeo", "creator": obj.get("creator") or "",
                        "artwork": obj.get("artwork") or "", "duration": obj.get("duration") or ""}
        raise ValueError("Prévia indisponível para este link.")


class HistoryDialog(QDialog):
    def __init__(self, library: Library, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Histórico · Caeser")
        self.setMinimumSize(670, 520)
        root = QVBoxLayout(self)
        root.setContentsMargins(28, 24, 28, 24)
        root.setSpacing(16)
        root.addWidget(label("Histórico", 24, True))
        root.addWidget(label("Seus downloads concluídos e os que precisam de atenção.", muted=True))
        self.list = QListWidget()
        self.list.setSpacing(8)
        for entry in reversed(library.items):
            if entry.state in ("Na fila", "Baixando"):
                continue
            row = QListWidgetItem(f"{entry.title or entry.url}\n{entry.source} · {entry.fmt} · {entry.state}  {entry.detail}")
            row.setData(Qt.ItemDataRole.UserRole, entry.destination)
            row.setToolTip(entry.url)
            self.list.addItem(row)
        if not self.list.count():
            self.list.addItem("Ainda não há downloads no histórico.")
        root.addWidget(self.list)
        actions = QHBoxLayout()
        open_folder = QPushButton("Mostrar pasta")
        open_folder.clicked.connect(self.open_selected_folder)
        actions.addWidget(open_folder)
        actions.addStretch()
        close = QPushButton("Fechar")
        close.clicked.connect(self.accept)
        actions.addWidget(close)
        root.addLayout(actions)

    def open_selected_folder(self):
        current = self.list.currentItem()
        if current and current.data(Qt.ItemDataRole.UserRole):
            QDesktopServices.openUrl(QUrl.fromLocalFile(current.data(Qt.ItemDataRole.UserRole)))


class Window(QMainWindow):
    def __init__(self):
        super().__init__()
        self.library = Library()
        self.current: Download | None = None
        self.process: QProcess | None = None
        self.output_buffer = ""
        self.preview_serial = 0
        self.preview: dict | None = None
        self.cancel_requested = False
        self.pool = QThreadPool.globalInstance()
        self.setWindowTitle("Caeser")
        self.resize(860, 790)
        self.setMinimumSize(620, 580)
        self.setStyleSheet(STYLE)
        self.setWindowIcon(QIcon(str(asset("Sources/VideoDownloader/Resources/CaeserLogo.png"))))
        self.build_ui()
        self.refresh()
        self.preview_timer = QTimer(self)
        self.preview_timer.setSingleShot(True)
        self.preview_timer.setInterval(650)
        self.preview_timer.timeout.connect(self.load_preview)

    def build_ui(self):
        body = QWidget()
        self.setCentralWidget(body)
        outer = QVBoxLayout(body)
        outer.setContentsMargins(24, 14, 24, 18)
        outer.setSpacing(10)
        toolbar = QHBoxLayout()
        toolbar.addWidget(label("Caeser", 15, True))
        toolbar.addStretch()
        history = QPushButton("◷  Histórico")
        history.setAccessibleName("Abrir histórico")
        history.clicked.connect(self.open_history)
        toolbar.addWidget(history)
        updates = QPushButton("↻  Atualizações")
        updates.clicked.connect(lambda: QDesktopServices.openUrl(QUrl("https://github.com/cnolli-fl/Caeser/releases")))
        toolbar.addWidget(updates)
        self.primary = QPushButton("↓  Baixar e continuar fila")
        self.primary.setObjectName("primary")
        self.primary.clicked.connect(self.enqueue)
        toolbar.addWidget(self.primary)
        outer.addLayout(toolbar)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        outer.addWidget(scroll, 1)
        page = QWidget()
        scroll.setWidget(page)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(12, 26, 12, 22)
        layout.setSpacing(22)
        hero = QHBoxLayout()
        logo = QLabel()
        image = QPixmap(str(asset("Sources/VideoDownloader/Resources/CaeserLogo.png")))
        logo.setPixmap(image.scaled(68, 68, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
        logo.setFixedSize(68, 68)
        hero.addWidget(logo)
        title = QVBoxLayout()
        title.setSpacing(2)
        title.addWidget(label("Caeser", 28, True))
        title.addWidget(label("Vídeos e músicas. Do link à sua pasta.", 13, muted=True))
        hero.addLayout(title)
        hero.addStretch()
        layout.addLayout(hero)

        card = QFrame()
        card.setObjectName("card")
        form = QVBoxLayout(card)
        form.setContentsMargins(24, 25, 24, 25)
        form.setSpacing(17)
        form.addWidget(label("Novo download", 19, True))
        sources = QHBoxLayout()
        sources.setSpacing(6)
        self.youtube = QPushButton("YouTube")
        self.spotify = QPushButton("Spotify")
        self.youtube.setIcon(QIcon(str(asset("Sources/VideoDownloader/Resources/YouTubeMark@3x.png"))))
        self.spotify.setIcon(QIcon(str(asset("Sources/VideoDownloader/Resources/SpotifyMark@3x.png"))))
        self.youtube.setIconSize(QSize(25, 20))
        self.spotify.setIconSize(QSize(25, 20))
        for button in (self.youtube, self.spotify):
            button.setObjectName("segment")
            button.setCheckable(True)
            button.setMinimumHeight(40)
            sources.addWidget(button, 1)
        self.youtube.setChecked(True)
        self.youtube.clicked.connect(lambda: self.set_source("YouTube"))
        self.spotify.clicked.connect(lambda: self.set_source("Spotify"))
        form.addLayout(sources)
        link_row = QHBoxLayout()
        self.link_title = label("Link do vídeo", 13, True)
        link_row.addWidget(self.link_title)
        link_row.addStretch()
        paste = QPushButton("▢  Colar")
        paste.clicked.connect(lambda: self.url_input.setPlainText(QApplication.clipboard().text()))
        link_row.addWidget(paste)
        form.addLayout(link_row)
        self.url_input = QTextEdit()
        self.url_input.setPlaceholderText("https://www.youtube.com/watch?v=...")
        self.url_input.setFixedHeight(61)
        self.url_input.textChanged.connect(self.on_link_changed)
        form.addWidget(self.url_input)
        self.link_help = label("Cole um link ou vários, um por linha.", muted=True)
        form.addWidget(self.link_help)
        self.preview_card = QFrame()
        self.preview_card.setObjectName("preview")
        preview_layout = QHBoxLayout(self.preview_card)
        preview_layout.setContentsMargins(14, 12, 14, 12)
        self.artwork = QLabel()
        self.artwork.setFixedSize(86, 65)
        self.artwork.setScaledContents(False)
        preview_layout.addWidget(self.artwork)
        preview_text = QVBoxLayout()
        self.preview_title = label("", 13, True)
        self.preview_creator = label("", muted=True)
        preview_text.addWidget(self.preview_title)
        preview_text.addWidget(self.preview_creator)
        preview_layout.addLayout(preview_text, 1)
        form.addWidget(self.preview_card)
        self.preview_card.hide()
        self.preview_hint = label("", muted=True)
        self.preview_hint.hide()
        form.addWidget(self.preview_hint)
        self.options = QWidget()
        opts = QHBoxLayout(self.options)
        opts.setContentsMargins(0, 9, 0, 9)
        opts.setSpacing(20)
        quality_col = QVBoxLayout()
        quality_col.addWidget(label("Qualidade", 13, True))
        self.quality = QComboBox()
        self.quality.addItems(QUALITY_HEIGHT.keys())
        quality_col.addWidget(self.quality)
        opts.addLayout(quality_col, 1)
        format_col = QVBoxLayout()
        format_col.addWidget(label("Formato", 13, True))
        self.fmt = QComboBox()
        self.fmt.addItems(FORMATS)
        format_col.addWidget(self.fmt)
        opts.addLayout(format_col, 1)
        form.addWidget(self.options)
        self.spotify_hint = label("Spotify → busca no YouTube → MP3 com capa e metadados. A correspondência pode variar.", muted=True)
        self.spotify_hint.hide()
        form.addWidget(self.spotify_hint)
        folder = QHBoxLayout()
        folder.addWidget(label("▱", 18, muted=True))
        folder_info = QVBoxLayout()
        folder_info.addWidget(label("Salvar em", muted=True))
        self.folder_label = label(self.library.destination, 13, True)
        self.folder_label.setToolTip(self.library.destination)
        folder_info.addWidget(self.folder_label)
        folder.addLayout(folder_info, 1)
        change = QPushButton("Alterar…")
        change.clicked.connect(self.change_folder)
        folder.addWidget(change)
        form.addLayout(folder)
        layout.addWidget(card)

        self.queue_frame = QFrame()
        queue_layout = QVBoxLayout(self.queue_frame)
        queue_layout.setContentsMargins(5, 2, 5, 2)
        queue_header = QHBoxLayout()
        queue_header.addWidget(label("Fila de downloads", 15, True))
        queue_header.addStretch()
        self.pause = QPushButton("Pausar fila")
        self.pause.clicked.connect(self.toggle_pause)
        queue_header.addWidget(self.pause)
        queue_layout.addLayout(queue_header)
        self.queue_list = QListWidget()
        self.queue_list.setMinimumHeight(80)
        self.queue_list.setMaximumHeight(180)
        queue_layout.addWidget(self.queue_list)
        controls = QHBoxLayout()
        self.retry = QPushButton("Tentar novamente")
        self.retry.clicked.connect(self.retry_selected)
        controls.addWidget(self.retry)
        self.remove = QPushButton("Remover da fila")
        self.remove.clicked.connect(self.remove_selected)
        controls.addWidget(self.remove)
        controls.addStretch()
        queue_layout.addLayout(controls)
        layout.addWidget(self.queue_frame)

        self.progress = QProgressBar()
        self.progress.setRange(0, 100)
        self.progress.setValue(0)
        self.progress.setTextVisible(False)
        self.progress.hide()
        layout.addWidget(self.progress)
        status = QHBoxLayout()
        self.status_label = label("Tudo pronto para baixar · ferramentas incluídas", 13, True)
        status.addWidget(self.status_label, 1)
        self.cancel = QPushButton("Cancelar download")
        self.cancel.clicked.connect(self.cancel_current)
        self.cancel.hide()
        status.addWidget(self.cancel)
        layout.addLayout(status)
        self.details = QTextEdit()
        self.details.setReadOnly(True)
        self.details.setFixedHeight(130)
        self.details.hide()
        self.detail_toggle = QPushButton("›  Detalhes e ferramentas")
        self.detail_toggle.clicked.connect(self.toggle_details)
        layout.addWidget(self.detail_toggle, 0, Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(self.details)
        layout.addStretch()
        self.make_shortcuts()

    def make_shortcuts(self):
        for shortcut, callback in (("Ctrl+Return", self.enqueue), ("Ctrl+L", self.url_input.setFocus),
                                   ("Escape", self.cancel_current)):
            action = QAction(self)
            action.setShortcut(QKeySequence(shortcut))
            action.triggered.connect(callback)
            self.addAction(action)

    def set_source(self, source: str):
        self.youtube.setChecked(source == "YouTube")
        self.spotify.setChecked(source == "Spotify")
        spotify = source == "Spotify"
        self.options.setVisible(not spotify)
        self.spotify_hint.setVisible(spotify)
        self.link_title.setText("Link da música, álbum ou playlist" if spotify else "Link do vídeo")
        self.url_input.setPlaceholderText("https://open.spotify.com/track/..." if spotify else "https://www.youtube.com/watch?v=...")
        self.on_link_changed()

    def source(self) -> str:
        return "Spotify" if self.spotify.isChecked() else "YouTube"

    def on_link_changed(self):
        self.preview_serial += 1
        self.preview = None
        self.preview_card.hide()
        self.preview_hint.hide()
        self.refresh()
        if hasattr(self, "preview_timer"):
            self.preview_timer.start()

    def load_preview(self):
        text = self.url_input.toPlainText().strip()
        if not text or len(text.split()) != 1:
            return
        try:
            url = validate_url(text, self.source())
        except ValueError:
            return
        serial = self.preview_serial
        self.preview_hint.setText("Buscando prévia…")
        self.preview_hint.show()
        task = PreviewTask(serial, url, self.source())
        task.signals.ready.connect(self.show_preview)
        task.signals.failed.connect(self.preview_failed)
        self.pool.start(task)

    def show_preview(self, serial: int, preview: dict):
        if serial != self.preview_serial:
            return
        self.preview = preview
        self.preview_hint.hide()
        self.preview_title.setText(preview["title"])
        self.preview_creator.setText(preview["creator"])
        self.artwork.clear()
        self.preview_card.show()
        url = preview.get("artwork", "")
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme == "https" and parsed.hostname:
            task = ArtworkTask(serial, url)
            task.signals.ready.connect(self.show_artwork)
            self.pool.start(task)

    def show_artwork(self, serial: int, data: bytes):
        if serial != self.preview_serial:
            return
        pixmap = QPixmap()
        if pixmap.loadFromData(data):
            self.artwork.setPixmap(pixmap.scaled(86, 65, Qt.AspectRatioMode.KeepAspectRatio,
                                                 Qt.TransformationMode.SmoothTransformation))

    def preview_failed(self, serial: int, reason: str):
        if serial == self.preview_serial:
            self.preview_hint.setText(reason + " Você ainda pode baixar.")
            self.preview_hint.show()

    def change_folder(self):
        selected = QFileDialog.getExistingDirectory(self, "Escolha a pasta de destino", self.library.destination)
        if selected:
            self.library.destination = selected
            self.library.save()
            self.folder_label.setText(selected)
            self.folder_label.setToolTip(selected)

    def enqueue(self):
        text = self.url_input.toPlainText().strip()
        if text:
            try:
                links = batch_urls(text, self.source())
                items = [Download(url=url, source=source, destination=self.library.destination,
                                  quality=self.quality.currentText(),
                                  fmt="MP3" if source == "Spotify" else self.fmt.currentText(),
                                  title=self.preview["title"] if len(links) == 1 and self.preview else url,
                                  creator=self.preview.get("creator", "") if len(links) == 1 and self.preview else "",
                                  artwork=self.preview.get("artwork", "") if len(links) == 1 and self.preview else "")
                         for url, source in links]
                added = self.library.add(items)
            except ValueError as error:
                self.status_label.setText(str(error))
                return
            if added:
                self.url_input.clear()
                self.status_label.setText(f"{added} item(ns) adicionado(s) à fila.")
            else:
                self.status_label.setText("Este link já está na fila ou foi baixado nesta pasta.")
        else:
            self.library.paused = False
            self.library.save()
        self.refresh()
        self.start_next()

    def start_next(self):
        if self.process or self.library.paused:
            return
        pending = next((i for i in self.library.items if i.state == "Na fila"), None)
        if not pending:
            self.refresh()
            return
        missing = [name for name in (("ffmpeg", "deno") if pending.source == "YouTube" else ("ffmpeg",))
                   if not Path(tool_path(name)).is_file()]
        if missing:
            pending.state, pending.detail = "Falhou", "Ferramenta ausente: " + ", ".join(missing)
            self.library.save()
            self.status_label.setText(pending.detail)
            self.refresh()
            QTimer.singleShot(0, self.start_next)
            return
        self.current = pending
        self.current.state = "Baixando"
        self.current.detail = "Iniciando…"
        self.library.save()
        self.process = QProcess(self)
        self.process.setWorkingDirectory(pending.destination)
        env = QProcessEnvironment.systemEnvironment()
        for key, value in tool_environment().items():
            if key in ("PATH", "PYINSTALLER_RESET_ENVIRONMENT"):
                env.insert(key, value)
        self.process.setProcessEnvironment(env)
        self.process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self.process.readyReadStandardOutput.connect(self.read_process)
        self.process.finished.connect(self.process_finished)
        command = pending.command()
        self.details.append("Executando " + ("spotDL" if pending.source == "Spotify" else "yt-dlp") + " para " + pending.url)
        self.output_buffer = ""
        self.cancel_requested = False
        self.process.start(command[0], command[1:])
        if not self.process.waitForStarted(5000):
            self.process_finished(-1, QProcess.ExitStatus.CrashExit)
            return
        self.progress.setRange(0, 0)
        self.progress.show()
        self.cancel.show()
        self.refresh()

    def read_process(self):
        if not self.process:
            return
        self.output_buffer += bytes(self.process.readAllStandardOutput()).decode("utf-8", errors="replace")
        lines = self.output_buffer.split("\n")
        self.output_buffer = lines.pop()
        for line in lines:
            self.handle_line(line.strip())

    def handle_line(self, line: str):
        if not line or not self.current:
            return
        if line.startswith("CAESER_TITLE:"):
            try:
                self.current.title = json.loads(line.split(":", 1)[1])
            except ValueError:
                pass
        elif line.startswith("CAESER_FILE:"):
            try:
                path = json.loads(line.split(":", 1)[1])
                if path not in self.current.files:
                    self.current.files.append(path)
            except ValueError:
                pass
        elif line.startswith("download:download:"):
            values = line.split(":", 2)[2].split("|")
            percent = re.search(r"([0-9]+(?:\.[0-9]+)?)%", values[0])
            if percent:
                self.progress.setRange(0, 100)
                self.progress.setValue(min(100, int(float(percent.group(1)))))
            self.current.detail = " · ".join(v.strip() for v in values if v.strip() and v.strip() != "NA")
        elif "ERROR" in line or "Error" in line:
            self.current.detail = line[-240:]
        self.details.append(line[-1000:])
        self.status_label.setText((self.current.title or "Baixando") + " · " + self.current.detail[:120])
        self.refresh_queue()

    def process_finished(self, code: int, _status):
        if not self.current:
            return
        if self.output_buffer:
            self.handle_line(self.output_buffer.strip())
            self.output_buffer = ""
        if self.cancel_requested:
            self.current.state, self.current.detail = "Cancelado", "Download cancelado."
        elif code == 0:
            self.current.state, self.current.detail = "Concluído", "Salvo em " + self.current.destination
        else:
            self.current.state = "Falhou"
            if not self.current.detail or self.current.detail == "Iniciando…":
                self.current.detail = "Não foi possível concluir. Veja os detalhes e tente novamente."
        self.status_label.setText(self.current.state + " · " + self.current.title)
        self.library.save()
        if self.process:
            self.process.deleteLater()
        self.process = None
        self.current = None
        self.progress.hide()
        self.cancel.hide()
        self.refresh()
        QTimer.singleShot(0, self.start_next)

    def cancel_current(self):
        if self.process and self.process.state() != QProcess.ProcessState.NotRunning:
            self.cancel_requested = True
            self.process.terminate()
            QTimer.singleShot(3000, self.kill_if_running)

    def kill_if_running(self):
        if self.process and self.process.state() != QProcess.ProcessState.NotRunning:
            self.process.kill()

    def toggle_pause(self):
        self.library.paused = not self.library.paused
        self.library.save()
        self.refresh()
        if not self.library.paused:
            self.start_next()

    def selected_item(self) -> Download | None:
        row = self.queue_list.currentItem()
        if row:
            return next((i for i in self.library.items if i.id == row.data(Qt.ItemDataRole.UserRole)), None)
        return None

    def retry_selected(self):
        item = self.selected_item()
        if item and item.state in ("Falhou", "Cancelado", "Interrompido"):
            item.state, item.detail = "Na fila", ""
            self.library.paused = False
            self.library.save()
            self.refresh()
            self.start_next()

    def remove_selected(self):
        item = self.selected_item()
        if item and item.state != "Baixando":
            self.library.items.remove(item)
            self.library.save()
            self.refresh()

    def refresh_queue(self):
        selected = self.selected_item()
        selected_id = selected.id if selected else None
        self.queue_list.clear()
        entries = [i for i in self.library.items if i.state in ("Na fila", "Baixando", "Falhou", "Cancelado", "Interrompido")]
        for entry in entries:
            row = QListWidgetItem(f"{entry.title or entry.url}\n{entry.source} · {entry.fmt} · {entry.state}" +
                                  (f" · {entry.detail[:90]}" if entry.detail else ""))
            row.setData(Qt.ItemDataRole.UserRole, entry.id)
            row.setToolTip(entry.url)
            self.queue_list.addItem(row)
            if entry.id == selected_id:
                self.queue_list.setCurrentItem(row)
        self.queue_frame.setVisible(bool(entries))
        self.pause.setText("Continuar fila" if self.library.paused else "Pausar fila")

    def refresh(self):
        self.refresh_queue()
        has_pending = any(i.state == "Na fila" for i in self.library.items)
        self.primary.setEnabled(bool(self.url_input.toPlainText().strip()) or has_pending)
        self.primary.setText("↓  Baixar e continuar fila" if has_pending else "↓  Baixar")

    def toggle_details(self):
        showing = not self.details.isVisible()
        self.details.setVisible(showing)
        self.detail_toggle.setText(("⌄" if showing else "›") + "  Detalhes e ferramentas")

    def open_history(self):
        HistoryDialog(self.library, self).exec()

    def closeEvent(self, event):
        if self.process and self.current:
            self.process.blockSignals(True)
            self.process.kill()
            self.process.waitForFinished(2000)
            self.current.state = "Interrompido"
            self.current.detail = "Interrompido ao fechar. Tente novamente."
            self.library.paused = True
        self.library.save()
        super().closeEvent(event)


class ArtworkSignals(QObject):
    ready = Signal(int, bytes)


class ArtworkTask(QRunnable):
    def __init__(self, serial: int, url: str):
        super().__init__()
        self.serial, self.url = serial, url
        self.signals = ArtworkSignals()

    def run(self):
        try:
            with urllib.request.urlopen(self.url, timeout=8) as response:
                data = response.read(2_000_001)
            if len(data) <= 2_000_000:
                self.signals.ready.emit(self.serial, data)
        except OSError:
            pass


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Caeser")
    app.setDesktopFileName("caeser.desktop")
    app.setStyle("Fusion")
    window = Window()
    window.show()
    if "--smoke" in sys.argv:
        def finish_smoke():
            destination = os.environ.get("CAESER_SMOKE_SCREENSHOT")
            if destination:
                window.grab().save(destination)
            window.set_source("Spotify")
            dialog = HistoryDialog(window.library, window)
            QTimer.singleShot(200, dialog.accept)
            dialog.exec()
            app.quit()
        QTimer.singleShot(1200, finish_smoke)
    return app.exec()
