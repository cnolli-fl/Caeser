"""Caeser desktop window for Fedora KDE and other Linux desktops."""

from __future__ import annotations

import json
import math
import os
import re
import signal
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

from PySide6.QtCore import (QEasingCurve, QObject, QProcess, QProcessEnvironment, QPropertyAnimation,
                            QRectF, QRunnable, QSettings, QSize, QThreadPool, QTimer, Qt, QUrl,
                            QVariantAnimation, Signal)
from PySide6.QtGui import QAction, QColor, QDesktopServices, QIcon, QKeySequence, QPainter, QPixmap
from PySide6.QtWidgets import (QApplication, QComboBox, QDialog, QFileDialog, QFrame,
                               QGraphicsOpacityEffect, QHBoxLayout, QLabel, QLineEdit, QListWidget,
                               QListWidgetItem, QMainWindow, QPushButton, QProgressBar, QScrollArea, QStyle,
                               QTextEdit, QVBoxLayout, QWidget)

from core import output_name
from core import (Clip, Download, FORMATS, Library, QUALITY_HEIGHT, batch_urls, clip_source,
                  parse_clip, spotify_match, spotify_match_command, timestamp, tool_command,
                  tool_environment, tool_path, validate_url)


BG, SURFACE, FIELD, BORDER = "#0D2666", "#102D6C", "#244580", "#6086BB"
TEXT, MUTED, ACCENT, STRONG = "#FFFFFF", "#CFDFF5", "#94D2FF", "#0099FF"

STYLE = f"""
QWidget {{ color: {TEXT}; font-family: 'Noto Sans', 'Inter', sans-serif; }}
QMainWindow, QDialog, QScrollArea, QWidget#body, QWidget#page {{ background: {BG}; }}
QLabel, QWidget#options {{ background: transparent; }}
QFrame#card {{ background: {SURFACE}; border: 1px solid {BORDER}; border-radius: 20px; }}
QFrame#preview, QFrame#status {{ background: {FIELD}; border: 0; border-radius: 14px; }}
QFrame#clipPanel {{ background: #173574; border: 1px solid #5576AC; border-radius: 16px; }}
QLabel#clipFormat {{ background: {FIELD}; color: {MUTED}; border-radius: 11px; padding: 4px 10px; }}
QLabel#clipIcon {{ background: {FIELD}; color: {ACCENT}; border-radius: 8px; }}
QLabel#muted {{ color: {MUTED}; }}
QTextEdit, QLineEdit, QComboBox, QListWidget {{ background: {FIELD}; border: 1px solid {BORDER}; border-radius: 9px; padding: 8px; selection-background-color: {STRONG}; font-size: 13px; }}
QTextEdit:focus, QLineEdit:focus, QComboBox:focus, QPushButton:focus {{ border: 2px solid {ACCENT}; }}
QComboBox {{ min-height: 22px; padding-left: 12px; }}
QComboBox::drop-down {{ border: none; width: 28px; }}
QComboBox QAbstractItemView {{ background: {FIELD}; color: {TEXT}; selection-background-color: {STRONG}; }}
QPushButton {{ background: {FIELD}; border: 1px solid transparent; border-radius: 10px; padding: 8px 14px; min-height: 22px; font-size: 13px; }}
QPushButton:hover {{ background: #345795; }}
QPushButton:pressed {{ background: #1A3A78; }}
QPushButton:disabled {{ color: #91A4CA; background: #173671; }}
QPushButton#primary {{ background: {STRONG}; color: {TEXT}; border: 1px solid #48B9FF; border-radius: 18px; font-weight: 600; padding: 8px 18px; }}
QPushButton#primary:hover {{ background: #1EAAFF; }}
QPushButton#segment {{ border-radius: 10px; font-weight: 600; }}
QPushButton#segment:checked, QPushButton#clipToggle:checked {{
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #096DAE, stop:1 #084D82);
    border: 1px solid #58BDF9;
}}
QPushButton#segment:focus, QPushButton#clipToggle:focus {{ border: 2px solid {ACCENT}; }}
QPushButton#details {{ background: transparent; border: none; color: {MUTED}; padding-left: 0; }}
QPushButton#details:hover {{ color: {TEXT}; }}
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
    widget.setTextFormat(Qt.TextFormat.PlainText)
    font = widget.font()
    font.setPointSize(size)
    font.setBold(bold)
    widget.setFont(font)
    widget.setWordWrap(True)
    if muted:
        widget.setObjectName("muted")
    return widget


def motion_duration(widget: QWidget) -> int:
    config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "kdeglobals"
    settings = QSettings(str(config), QSettings.Format.IniFormat)
    if os.environ.get("CAESER_REDUCE_MOTION") == "1":
        return 0
    try:
        factor = float(settings.value("KDE/AnimationDurationFactor", "1"))
    except (TypeError, ValueError):
        factor = 1
    base = widget.style().styleHint(QStyle.StyleHint.SH_Widget_Animation_Duration)
    return min(420, round(base * min(max(factor, 0), 2))) if math.isfinite(factor) else base


class ClipTimeline(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(8)
        self.setAccessibleName("Posição do trecho na duração total")
        self.selection = QRectF()
        self.animation = QVariantAnimation(self)
        self.animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.animation.valueChanged.connect(self.animate_selection)

    def animate_selection(self, value):
        self.selection = value
        self.update()

    def set_selection(self, clip: Clip, duration: float):
        start, end = min(1, clip.start / duration), min(1, clip.end / duration)
        target = QRectF(start, 0, end - start, 1)
        self.animation.stop()
        duration_ms = motion_duration(self)
        if not duration_ms or self.isHidden():
            self.animate_selection(target)
        else:
            self.animation.setDuration(duration_ms)
            self.animation.setStartValue(self.selection)
            self.animation.setEndValue(target)
            self.animation.start()
        self.setAccessibleDescription(clip.title)
        self.show()

    def paintEvent(self, _event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(FIELD))
        painter.drawRoundedRect(QRectF(self.rect()), 4, 4)
        painter.setBrush(QColor(ACCENT))
        width = self.width()
        painter.drawRoundedRect(QRectF(self.selection.x() * width, 0, self.selection.width() * width, 8), 4, 4)


class PreviewSignals(QObject):
    ready = Signal(int, dict)
    failed = Signal(int, str)


class PreviewTask(QRunnable):
    def __init__(self, serial: int, url: str, source: str, need_duration: bool = False):
        super().__init__()
        self.serial, self.url, self.source = serial, url, source
        self.need_duration = need_duration
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
        if endpoint and (not self.need_duration or self.source == "Spotify"):
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
            trim = (f" · {entry.clip.title}" if entry.clip else "") + (f" · {entry.file_name}" if entry.file_name else "")
            row = QListWidgetItem(f"{entry.title or entry.url}\n{entry.source} · {entry.fmt}{trim} · {entry.state}  {entry.detail}")
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
        self.match_directory: tempfile.TemporaryDirectory | None = None
        self.download_directory: tempfile.TemporaryDirectory | None = None
        self.output_buffer = ""
        self.preview_serial = 0
        self.preview: dict | None = None
        self.cancel_requested = False
        self.pool = QThreadPool.globalInstance()
        self.setWindowTitle("Caeser")
        self.resize(860, 790)
        self.setMinimumSize(620, 580)
        self.setStyleSheet(STYLE)
        self.animation_ms = motion_duration(self)
        self.reveals = {}
        self.setWindowIcon(QIcon(str(asset("Sources/VideoDownloader/Resources/CaeserLogo.png"))))
        self.build_ui()
        self.refresh()
        self.preview_timer = QTimer(self)
        self.preview_timer.setSingleShot(True)
        self.preview_timer.setInterval(650)
        self.preview_timer.timeout.connect(self.load_preview)

    def build_ui(self):
        body = QWidget()
        body.setObjectName("body")
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
        page.setObjectName("page")
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
        tagline = label("Vídeos e músicas. Do link à sua pasta.", 13, muted=True)
        tagline.setMinimumWidth(350)
        title.addWidget(tagline)
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
        self.options.setObjectName("options")
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
        form.addWidget(label("Nome do arquivo", 13, True))
        self.file_name = QLineEdit()
        self.file_name.setPlaceholderText("Opcional · usar o título original")
        self.file_name.setAccessibleName("Nome do arquivo, opcional")
        form.addWidget(self.file_name)
        form.addWidget(label("A extensão acompanha o formato escolhido.", muted=True))
        form.addWidget(self.build_clip_panel())
        self.fmt.currentTextChanged.connect(self.update_clip)
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
        self.progress_motion = QPropertyAnimation(self.progress, b"value", self)
        self.progress_motion.setDuration(self.animation_ms)
        self.progress_motion.setEasingCurve(QEasingCurve.Type.OutCubic)
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
        self.detail_toggle.setObjectName("details")
        self.detail_toggle.clicked.connect(self.toggle_details)
        layout.addWidget(self.detail_toggle, 0, Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(self.details)
        layout.addStretch()
        self.make_shortcuts()

    def build_clip_panel(self) -> QFrame:
        panel = QFrame()
        panel.setObjectName("clipPanel")
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(14, 12, 14, 12)
        layout.setSpacing(11)
        heading = QHBoxLayout()
        icon = label("✂", 16, True)
        icon.setObjectName("clipIcon")
        icon.setFixedSize(32, 32)
        icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        heading.addWidget(icon)
        self.clip_title = label("Cortar vídeo", 13, True)
        heading.addWidget(self.clip_title)
        heading.addStretch()
        self.clip_toggle = QPushButton("Ativar")
        self.clip_toggle.setObjectName("clipToggle")
        self.clip_toggle.setCheckable(True)
        self.clip_toggle.setMinimumWidth(94)
        heading.addWidget(self.clip_toggle)
        layout.addLayout(heading)
        self.clip_body = QWidget()
        body = QVBoxLayout(self.clip_body)
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(10)
        fields = QHBoxLayout()
        fields.setSpacing(14)
        self.clip_start, self.clip_end = QLineEdit(), QLineEdit()
        for caption, example, field in (("Início", "1:20", self.clip_start), ("Fim", "1:50", self.clip_end)):
            column = QVBoxLayout()
            column.setSpacing(5)
            title = label(caption, 11, True)
            title.setBuddy(field)
            field.setAccessibleName(caption)
            field.setMinimumHeight(34)
            field.setMaximumWidth(130)
            field.setMaxLength(12)
            field.setPlaceholderText(example)
            field.textChanged.connect(self.update_clip)
            field.returnPressed.connect(self.enqueue)
            column.addWidget(title)
            column.addWidget(field)
            fields.addLayout(column)
        fields.addStretch()
        self.clip_format = label("MP4", 10, True)
        self.clip_format.setObjectName("clipFormat")
        fields.addWidget(self.clip_format, alignment=Qt.AlignmentFlag.AlignBottom)
        body.addLayout(fields)
        self.clip_timeline = ClipTimeline()
        self.clip_timeline.hide()
        body.addWidget(self.clip_timeline)
        self.clip_feedback = label("", 11, muted=True)
        body.addWidget(self.clip_feedback)
        layout.addWidget(self.clip_body)
        self.clip_body.hide()
        self.clip_toggle.toggled.connect(self.toggle_clip)
        return panel

    def reveal(self, widget: QWidget, visible: bool = True):
        if widget.isHidden() != visible:
            return
        if not visible or not self.animation_ms:
            animation = self.reveals.get(widget)
            if animation:
                animation.stop()
                widget.graphicsEffect().setOpacity(1)
            widget.setVisible(visible)
            return
        if widget not in self.reveals:
            effect = QGraphicsOpacityEffect(widget)
            widget.setGraphicsEffect(effect)
            animation = QPropertyAnimation(effect, b"opacity", widget)
            animation.setDuration(self.animation_ms)
            animation.setEasingCurve(QEasingCurve.Type.OutCubic)
            animation.setStartValue(0.0)
            animation.setEndValue(1.0)
            self.reveals[widget] = animation
        widget.show()
        self.reveals[widget].start()

    def toggle_clip(self, enabled: bool):
        self.reveal(self.clip_body, enabled)
        self.update_clip()
        if enabled and self.source() == "YouTube" and self.url_input.toPlainText().strip():
            self.preview_serial += 1
            self.preview_timer.start()

    def selected_clip(self) -> Clip:
        text = self.url_input.toPlainText().strip()
        if text:
            clip_source(batch_urls(text, self.source()))
        return parse_clip(self.clip_start.text(), self.clip_end.text(), self.media_duration())

    def media_duration(self) -> float | None:
        duration = self.preview.get("duration") if self.preview else None
        return duration if isinstance(duration, (float, int)) and math.isfinite(duration) and duration > 0 else None

    def update_clip(self):
        audio = self.source() == "Spotify" or self.fmt.currentText() == "MP3"
        self.clip_title.setText("Cortar áudio" if audio else "Cortar vídeo")
        active = self.clip_toggle.isChecked()
        self.clip_toggle.setText("Ativado" if active else "Ativar")
        self.clip_toggle.setAccessibleName(self.clip_title.text())
        self.clip_format.setText("MP3" if audio else "MP4")
        self.clip_format.setAccessibleName("Formato do trecho: " + self.clip_format.text())
        if self.source() == "Spotify":
            self.spotify_hint.setText("O trecho usa a versão da faixa encontrada no YouTube." if active else
                                      "Spotify → YouTube · MP3 com capa e metadados. A correspondência pode variar.")
        valid = True
        if active:
            try:
                clip = self.selected_clip()
            except ValueError as error:
                valid = False
                self.clip_timeline.hide()
                self.clip_feedback.setText("Use minutos e segundos, como 1:20."
                                           if str(error).startswith("Use mm:ss") and
                                           not (self.clip_start.text() and self.clip_end.text()) else str(error))
            else:
                self.clip_feedback.setText("Duração do trecho  ·  " + timestamp(clip.end - clip.start))
                if duration := self.media_duration():
                    self.clip_timeline.set_selection(clip, duration)
                else:
                    self.clip_timeline.hide()
        text = self.url_input.toPlainText().strip()
        has_pending = any(i.state == "Na fila" for i in self.library.items)
        self.primary.setEnabled(valid if text else has_pending)
        self.primary.setText("↓  Baixar trecho" if active and text else
                             "↓  Baixar e continuar fila" if has_pending else "↓  Baixar")

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
        self.reveal(self.options, not spotify)
        self.reveal(self.spotify_hint, spotify)
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
        task = PreviewTask(serial, url, self.source(), self.clip_toggle.isChecked())
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
        self.reveal(self.preview_card)
        self.update_clip()
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
            if self.preview:
                self.preview_hint.hide()
            else:
                self.preview_hint.setText(reason + " Você ainda pode baixar.")
                self.reveal(self.preview_hint)

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
                name = output_name(self.file_name.text())
                if name and (len(links) != 1 or (links[0][1] == "Spotify" and "/track/" not in links[0][0])):
                    raise ValueError("Para escolher um nome, cole apenas o link de um vídeo ou de uma faixa.")
                clip = self.selected_clip() if self.clip_toggle.isChecked() else None
                fmt = self.fmt.currentText()
                if clip and fmt != "MP3":
                    fmt = "MP4"
                items = [Download(url=url, source=source, destination=self.library.destination,
                                  quality=self.quality.currentText(),
                                  fmt="MP3" if source == "Spotify" else fmt, clip=clip, file_name=name,
                                  title=self.preview["title"] if len(links) == 1 and self.preview else url,
                                  creator=self.preview.get("creator", "") if len(links) == 1 and self.preview else "",
                                  artwork=self.preview.get("artwork", "") if len(links) == 1 and self.preview else "")
                         for url, source in links]
                added = self.library.add(items)
            except ValueError as error:
                self.status_label.setText(str(error))
                return
            if added:
                self.clip_toggle.setChecked(False)
                self.url_input.clear()
                self.file_name.clear()
                self.clip_start.clear()
                self.clip_end.clear()
                self.status_label.setText(f"{added} item(ns) adicionado(s) à fila.")
            else:
                self.status_label.setText("Este link já está na fila ou foi baixado nesta pasta.")
        else:
            self.library.paused = False
            self.library.save()
        self.refresh()
        self.start_next()

    def start_next(self):
        if self.current or self.library.paused:
            return
        pending = next((i for i in self.library.items if i.state == "Na fila"), None)
        if not pending:
            self.refresh()
            return
        missing = [name for name in (("ffmpeg", "deno") if pending.source == "YouTube" or pending.clip else ("ffmpeg",))
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
        self.cancel_requested = False
        self.progress.setRange(0, 0)
        self.reveal(self.progress)
        self.cancel.show()
        self.refresh()
        if pending.source == "Spotify" and pending.clip:
            try:
                self.match_directory = tempfile.TemporaryDirectory(prefix="caeser-faixa-")
            except OSError as error:
                pending.detail = str(error)
                self.process_finished(-1, QProcess.ExitStatus.CrashExit)
                return
            self.status_label.setText("Buscando a faixa no YouTube…")
            self.launch_process(spotify_match_command(pending.url, self.match_file))
            lookup = self.process
            if lookup:
                QTimer.singleShot(120_000, lambda: self.stop_lookup_if_current(lookup))
        else:
            self.launch_process(pending.command())

    @property
    def match_file(self) -> Path:
        return Path(self.match_directory.name) / "faixa.spotdl"

    def launch_process(self, command: list[str]):
        process = QProcess(self)
        self.process = process
        process.setWorkingDirectory(self.match_directory.name if self.match_directory else self.current.destination)
        process.setUnixProcessParameters(QProcess.UnixProcessFlag.CreateNewSession)
        env = QProcessEnvironment.systemEnvironment()
        for key, value in tool_environment().items():
            if key in ("PATH", "PYINSTALLER_RESET_ENVIRONMENT"):
                env.insert(key, value)
        process.setProcessEnvironment(env)
        process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        process.readyReadStandardOutput.connect(self.read_process)
        process.finished.connect(self.process_finished)
        self.details.append("Executando " + ("spotDL" if self.match_directory or
                            self.current.source == "Spotify" and not self.current.clip else "yt-dlp"))
        self.output_buffer = ""
        if self.current.file_name and "--ffmpeg-location" in command:
            try:
                self.download_directory = tempfile.TemporaryDirectory(prefix="caeser-media-")
            except OSError as error:
                self.current.detail = str(error)
                self.process_finished(-1, QProcess.ExitStatus.CrashExit)
                return
            position = command.index("--ffmpeg-location")
            command[position:position] = ["--paths", "temp:" + self.download_directory.name]
        process.start(command[0], command[1:])
        if not process.waitForStarted(5000):
            self.process_finished(-1, QProcess.ExitStatus.CrashExit)

    def stop_lookup_if_current(self, process: QProcess):
        if self.process is process and self.match_directory:
            self.current.detail = "A busca da faixa demorou demais. Tente novamente."
            self.stop_process(process)

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
                value = min(100, int(float(percent.group(1))))
                if self.progress.maximum() == 0:
                    self.progress.setRange(0, 100)
                    self.progress.setValue(0)
                if self.animation_ms:
                    self.progress_motion.stop()
                    self.progress_motion.setStartValue(self.progress.value())
                    self.progress_motion.setEndValue(value)
                    self.progress_motion.start()
                else:
                    self.progress.setValue(value)
            self.current.detail = " · ".join(v.strip() for v in values if v.strip() and v.strip() != "NA")
        elif line.startswith("[info]") and "time ranges" in line:
            self.current.detail = "Preparando o trecho " + self.current.clip.title if self.current.clip else "Preparando…"
        elif "ERROR" in line or "Error" in line:
            self.current.detail = line[-240:]
        self.details.append(line[-1000:])
        self.status_label.setText((self.current.title or "Baixando") + " · " + self.current.detail[:120])
        self.refresh_queue()

    def process_finished(self, code: int, _status):
        if not self.current:
            return
        self.read_process()
        if self.output_buffer:
            self.handle_line(self.output_buffer.strip())
            self.output_buffer = ""
        if self.process:
            self.process.deleteLater()
        self.process = None
        lookup = self.match_directory
        if lookup:
            match = None
            if code == 0 and not self.cancel_requested:
                try:
                    match = spotify_match(self.match_file)
                except (OSError, TypeError, ValueError):
                    self.current.detail = "Não encontrei uma versão da faixa no YouTube."
                    code = -1
            self.match_directory = None
            lookup.cleanup()
            if match:
                self.current.detail = "Preparando o trecho de áudio…"
                self.status_label.setText(self.current.detail)
                self.launch_process(self.current.command(match))
                return
        if code == 0 and not self.cancel_requested and self.current.source == "Spotify" and not self.current.clip:
            if self.current.file_name:
                saved = Path(self.current.destination) / (self.current.file_name + ".mp3")
                if saved.is_file():
                    self.current.files = [str(saved)]
            elif "/track/" in self.current.url:
                track_id = self.current.url.rsplit("/", 1)[-1]
                self.current.files = [str(path) for path in Path(self.current.destination).glob("*.mp3")
                                      if path.name.endswith(f"[{track_id}].mp3")]
        if self.cancel_requested:
            self.current.state, self.current.detail = "Cancelado", "Download cancelado."
        elif code == 0 and (not self.current.clip or any(Path(path).is_file() for path in self.current.files)):
            self.current.state, self.current.detail = "Concluído", "Salvo em " + self.current.destination
        else:
            self.current.state = "Falhou"
            if code == 0 and self.current.clip:
                self.current.detail = "Nenhum trecho foi salvo. Confira a duração e a disponibilidade da faixa ou vídeo."
            elif not self.current.detail or self.current.detail == "Iniciando…":
                self.current.detail = "Não foi possível concluir. Veja os detalhes e tente novamente."
        self.status_label.setText(self.current.state + " · " + self.current.title)
        self.library.save()
        if self.download_directory:
            self.download_directory.cleanup()
            self.download_directory = None
        self.current = None
        self.progress_motion.stop()
        self.progress.hide()
        self.cancel.hide()
        self.refresh()
        QTimer.singleShot(0, self.start_next)

    def cancel_current(self):
        if self.process and self.process.state() != QProcess.ProcessState.NotRunning:
            self.cancel_requested = True
            self.stop_process(self.process)

    def stop_process(self, process: QProcess):
        self.signal_process(process, signal.SIGTERM)
        QTimer.singleShot(3000, lambda: self.signal_process(process, signal.SIGKILL)
                          if self.process is process else None)

    @staticmethod
    def signal_process(process: QProcess, sig: int):
        if pid := process.processId():
            try:
                os.killpg(pid, sig)
            except ProcessLookupError:
                pass

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
            trim = (f" · {entry.clip.title}" if entry.clip else "") + (f" · {entry.file_name}" if entry.file_name else "")
            row = QListWidgetItem(f"{entry.title or entry.url}\n{entry.source} · {entry.fmt}{trim} · {entry.state}" +
                                  (f" · {entry.detail[:90]}" if entry.detail else ""))
            row.setData(Qt.ItemDataRole.UserRole, entry.id)
            row.setToolTip(entry.url)
            self.queue_list.addItem(row)
            if entry.id == selected_id:
                self.queue_list.setCurrentItem(row)
        self.reveal(self.queue_frame, bool(entries))
        self.pause.setText("Continuar fila" if self.library.paused else "Pausar fila")

    def refresh(self):
        self.refresh_queue()
        self.update_clip()

    def toggle_details(self):
        showing = not self.details.isVisible()
        self.reveal(self.details, showing)
        self.detail_toggle.setText(("⌄" if showing else "›") + "  Detalhes e ferramentas")

    def open_history(self):
        HistoryDialog(self.library, self).exec()

    def closeEvent(self, event):
        if self.process and self.current:
            self.process.blockSignals(True)
            self.signal_process(self.process, signal.SIGKILL)
            self.process.waitForFinished(2000)
            self.current.state = "Interrompido"
            self.current.detail = "Interrompido ao fechar. Tente novamente."
            self.library.paused = True
        if self.match_directory:
            self.match_directory.cleanup()
            self.match_directory = None
        if self.download_directory:
            self.download_directory.cleanup()
            self.download_directory = None
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
            window.set_source("YouTube")
            window.url_input.setPlainText("https://youtu.be/trecho-teste")
            window.clip_toggle.setChecked(True)
            window.preview_timer.stop()
            window.show_preview(window.preview_serial, {"title": "Vídeo de demonstração", "creator": "Caeser",
                                                        "duration": 166})
            window.clip_start.setText("1:20")
            window.clip_end.setText("1:10")
            if window.primary.isEnabled():
                app.exit(1)
                return
            window.clip_end.setText("1:50")
            if not window.primary.isEnabled() or "0:30" not in window.clip_feedback.text():
                app.exit(1)
                return
            destination = os.environ.get("CAESER_SMOKE_SCREENSHOT")
            if destination:
                window.resize(860, 1050)
            def confirm_spotify():
                if destination and not window.grab().save(destination):
                    app.exit(1)
                    return
                window.set_source("Spotify")
                window.url_input.setPlainText("spotify:album:0VjIjW4GlUZAMYd2vXMi3b")
                window.preview_timer.stop()
                if window.clip_title.text() != "Cortar áudio" or window.primary.isEnabled():
                    app.exit(1)
                    return
                dialog = HistoryDialog(window.library, window)
                QTimer.singleShot(150, dialog.accept)
                dialog.exec()
                app.quit()
            QTimer.singleShot(450, confirm_spotify)
        QTimer.singleShot(1200, finish_smoke)
    elif "--smoke-clip-download" in sys.argv:
        def run_clips():
            window.library.destination = os.environ["CAESER_SMOKE_DESTINATION"]
            for fmt in ("MP4", "MP3"):
                window.fmt.setCurrentText(fmt)
                window.url_input.setPlainText(os.environ["CAESER_SMOKE_VIDEO"])
                window.clip_toggle.setChecked(True)
                window.preview_timer.stop()
                window.file_name.setText("Meu trecho 100%")
                window.clip_start.setText("0:03")
                window.clip_end.setText("0:07")
                window.enqueue()
            timer = QTimer(window)
            def check_clips():
                if window.current or any(item.state == "Na fila" for item in window.library.items):
                    return
                ok = {item.fmt for item in window.library.items if item.state == "Concluído"} == {"MP4", "MP3"}
                if not ok:
                    print(window.details.toPlainText(), file=sys.stderr)
                app.exit(0 if ok else 1)
            timer.timeout.connect(check_clips)
            timer.start(100)
            QTimer.singleShot(75_000, lambda: app.exit(1))
        QTimer.singleShot(0, run_clips)
    return app.exec()
