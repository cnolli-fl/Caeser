"""Platform-neutral download planning and persistent library for Caeser Linux."""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
import uuid
from dataclasses import asdict, dataclass, field
from pathlib import Path
from urllib.parse import urlparse, parse_qs


QUALITY_HEIGHT = {"Melhor disponível": None, "4K": 2160, "1440p": 1440, "1080p": 1080,
                  "720p": 720, "480p": 480}
FORMATS = ("Automático", "MP4", "WebM", "MP3")
SPOTIFY_ID = re.compile(r"^[A-Za-z0-9]{22}$")


def data_dir() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "Caeser"


def tool_path(name: str) -> str:
    if getattr(sys, "frozen", False):
        return str(Path(sys.executable).resolve().parent / "tools" / name)
    import shutil
    found = shutil.which(name)
    return found or name


def tool_command(name: str) -> list[str]:
    if getattr(sys, "frozen", False):
        return [sys.executable, "--tool", name]
    return [sys.executable, "-m", "yt_dlp" if name == "yt-dlp" else "spotdl"]


def tool_environment() -> dict[str, str]:
    env = os.environ.copy()
    if getattr(sys, "frozen", False):
        tools = str(Path(sys.executable).resolve().parent / "tools")
        env["PATH"] = tools + os.pathsep + env.get("PATH", "")
        env["PYINSTALLER_RESET_ENVIRONMENT"] = "1"
    return env


def is_spotify(text: str) -> bool:
    try:
        return text.lower().startswith("spotify:") or urlparse(text).hostname == "open.spotify.com"
    except ValueError:
        return False


def validate_url(text: str, source: str) -> str:
    value = text.strip()
    if value.lower().startswith("spotify:"):
        parts = value.split(":")
        if len(parts) != 3:
            raise ValueError("Cole um link público de música, álbum ou playlist do Spotify.")
        value = f"https://open.spotify.com/{parts[1]}/{parts[2]}"
    try:
        parsed = urlparse(value)
        valid = parsed.scheme in ("http", "https") and parsed.hostname and not parsed.username and not parsed.password
    except ValueError:
        valid = False
    if not valid:
        raise ValueError("Cole um link completo começando com https://.")
    if source == "Spotify":
        segments = [p for p in parsed.path.split("/") if p]
        if segments and segments[0].startswith("intl-"):
            segments = segments[1:]
        if (parsed.hostname != "open.spotify.com" or parsed.netloc.lower() != "open.spotify.com" or len(segments) != 2
                or segments[0] not in ("track", "album", "playlist") or not SPOTIFY_ID.fullmatch(segments[1])):
            raise ValueError("Cole um link público de música, álbum ou playlist de open.spotify.com.")
        return f"https://open.spotify.com/{segments[0]}/{segments[1]}"
    if is_spotify(value):
        raise ValueError("Selecione Spotify para buscar esta música no YouTube.")
    return value


def batch_urls(text: str, source: str) -> list[tuple[str, str]]:
    links = text.split()
    if not 1 <= len(links) <= 50:
        raise ValueError("Cole de 1 a 50 links, um por linha.")
    result = []
    for link in links:
        origin = ("Spotify" if is_spotify(link) else "YouTube") if len(links) > 1 else source
        result.append((validate_url(link, origin), origin))
    return result


def selector(quality: str, fmt: str) -> str:
    height = QUALITY_HEIGHT.get(quality)
    h = f"[height<={height}]" if height else ""
    if fmt == "MP3":
        return "bestaudio/best"
    if fmt == "MP4":
        return f"bv*{h}[ext=mp4][vcodec^=avc1]+ba[ext=m4a]/bv*{h}[ext=mp4]+ba[ext=m4a]/b{h}[ext=mp4]/b{h}"
    if fmt == "WebM":
        return f"bv*{h}[ext=webm]+ba[ext=webm]/bv*{h}+ba/b{h}"
    return f"bv*{h}+ba/b{h}"


@dataclass
class Download:
    url: str
    source: str
    destination: str
    quality: str = "Melhor disponível"
    fmt: str = "Automático"
    title: str = ""
    creator: str = ""
    artwork: str = ""
    state: str = "Na fila"
    detail: str = ""
    files: list[str] = field(default_factory=list)
    id: str = field(default_factory=lambda: uuid.uuid4().hex)

    def key(self) -> tuple[str, str, str, str, str]:
        p = urlparse(self.url)
        identity = self.url
        if p.hostname in ("www.youtube.com", "youtube.com", "m.youtube.com", "music.youtube.com"):
            identity = parse_qs(p.query).get("v", [self.url])[0]
        elif p.hostname == "youtu.be":
            identity = p.path.strip("/")
        return (identity, self.source, self.fmt,
                "audio" if self.fmt == "MP3" else self.quality, str(Path(self.destination).resolve()))

    def command(self) -> list[str]:
        if self.source == "Spotify":
            return tool_command("spotdl") + [
                "download", self.url, "--audio", "youtube", "youtube-music",
                "--format", "mp3", "--bitrate", "0", "--ffmpeg", tool_path("ffmpeg"),
                "--output", "{artists} - {title} [{track-id}].{output-ext}",
                "--threads", "1", "--overwrite", "skip", "--simple-tui", "--headless",
                "--max-retries", "2", "--log-level", "INFO", "--lyrics"]
        args = ["--ignore-config", "--newline", "--no-quiet", "--progress", "--no-playlist",
                "--no-overwrites", "--no-simulate", "--print", "before_dl:CAESER_TITLE:%(title)j",
                "--print", "after_move:CAESER_FILE:%(filepath)j",
                "--ffmpeg-location", str(Path(tool_path("ffmpeg")).parent),
                "--paths", self.destination, "-o", "%(title)s.%(ext)s",
                "--progress-template", "download:download:%(progress._percent_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._speed_str)s|%(progress._eta)s",
                "-f", selector(self.quality, self.fmt)]
        deno = Path(tool_path("deno"))
        if deno.is_file():
            args += ["--js-runtimes", f"deno:{deno}"]
        if self.fmt == "MP4":
            args += ["--merge-output-format", "mp4"]
        elif self.fmt == "WebM":
            args += ["--merge-output-format", "webm"]
        elif self.fmt == "MP3":
            args += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        return tool_command("yt-dlp") + args + ["--", self.url]


class Library:
    def __init__(self, path: Path | None = None):
        self.path = path or data_dir() / "library.json"
        self.items: list[Download] = []
        self.paused = False
        self.destination = str(Path.home() / "Downloads")
        self.load()

    def load(self) -> None:
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            self.items = [Download(**row) for row in raw.get("items", [])]
            self.destination = raw.get("destination", self.destination)
            self.paused = bool(raw.get("paused", False))
            for item in self.items:
                if item.state == "Baixando":
                    item.state, item.detail = "Interrompido", "Interrompido ao fechar. Tente novamente."
                    self.paused = True
        except (FileNotFoundError, OSError, ValueError, TypeError):
            self.items = []

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        pending = [i for i in self.items if i.state in ("Na fila", "Baixando")]
        past = [i for i in self.items if i not in pending][-100:]
        self.items = past + pending
        payload = {"items": [asdict(i) for i in self.items], "destination": self.destination, "paused": self.paused}
        fd, temp = tempfile.mkstemp(prefix="library-", suffix=".tmp", dir=self.path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as output:
                json.dump(payload, output, ensure_ascii=False, indent=2)
            os.replace(temp, self.path)
        finally:
            if os.path.exists(temp):
                os.unlink(temp)

    def add(self, downloads: list[Download]) -> int:
        keys = {i.key() for i in self.items if i.state in ("Na fila", "Baixando") or
                i.state == "Concluído" and i.files and all(Path(p).is_file() for p in i.files)}
        added = 0
        for item in downloads:
            if item.key() not in keys:
                self.items.append(item)
                keys.add(item.key())
                added += 1
        if sum(i.state == "Na fila" for i in self.items) > 100:
            self.items = self.items[:-added] if added else self.items
            raise ValueError("A fila já tem 100 itens. Espere alguns terminarem.")
        if added:
            self.paused = False
            self.save()
        return added
