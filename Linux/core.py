"""Platform-neutral download planning and persistent library for Caeser Linux."""

from __future__ import annotations

import json
import math
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


def timestamp(seconds: int) -> str:
    minutes, remainder = divmod(seconds, 60)
    hours, minutes_in_hour = divmod(minutes, 60)
    return f"{hours}:{minutes_in_hour:02}:{remainder:02}" if hours else f"{minutes}:{remainder:02}"


@dataclass(frozen=True)
class Clip:
    start: int
    end: int

    def __post_init__(self):
        if type(self.start) is not int or type(self.end) is not int or not 0 <= self.start < self.end:
            raise ValueError("O fim precisa ser depois do início.")

    @property
    def title(self) -> str:
        return f"{timestamp(self.start)} – {timestamp(self.end)}"


def parse_clip(start: str, end: str, duration: float | None = None) -> Clip:
    def seconds(value: str) -> int:
        parts = value.strip().split(":")
        if (len(parts) not in (2, 3) or not re.fullmatch(r"[0-9]{1,5}(:[0-9]{1,2}){1,2}", value.strip())
                or any(int(part) >= 60 for part in parts[1:])):
            raise ValueError("Use mm:ss ou h:mm:ss, como 1:20.")
        result = 0
        for part in parts:
            result = result * 60 + int(part)
        return result

    clip = Clip(seconds(start), seconds(end))
    if duration is not None and math.isfinite(duration) and duration > 0:
        if clip.start >= duration or clip.end > math.ceil(duration):
            raise ValueError("Escolha um trecho dentro da duração disponível.")
    return clip


def clip_source(links: list[tuple[str, str]]) -> None:
    if len(links) != 1:
        raise ValueError("Para cortar, deixe apenas um link no campo.")
    url, source = links[0]
    if source == "Spotify" and not urlparse(url).path.startswith("/track/"):
        raise ValueError("Para cortar no Spotify, cole o link de uma faixa.")
    if source == "YouTube" and urlparse(url).hostname in ("www.youtube.com", "youtube.com", "m.youtube.com", "music.youtube.com"):
        if urlparse(url).path == "/playlist":
            raise ValueError("Para cortar no YouTube, cole o link de um vídeo.")


def spotify_match_command(url: str, metadata: Path) -> list[str]:
    return tool_command("spotdl") + [
        "save", url, "--save-file", str(metadata), "--preload", "--audio", "youtube", "youtube-music",
        "--ffmpeg", tool_path("ffmpeg"), "--threads", "1", "--headless", "--simple-tui", "--max-retries", "1",
        "--log-level", "ERROR", "--lyrics"]


def spotify_match(metadata: Path) -> str:
    if metadata.stat().st_size > 128_000:
        raise ValueError("A faixa não pôde ser identificada.")
    rows = json.loads(metadata.read_text(encoding="utf-8"))
    match = next((row.get("download_url") for row in rows
                  if isinstance(row, dict) and isinstance(row.get("download_url"), str)), None)
    if match:
        url = urlparse(match)
        if url.scheme == "https" and url.netloc.lower() in (
            "www.youtube.com", "youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"
        ):
            return match
    raise ValueError("Não encontrei uma versão da faixa no YouTube.")


def selector(quality: str, fmt: str, clip: Clip | None = None) -> str:
    height = QUALITY_HEIGHT.get(quality)
    h = f"[height<={height}]" if height else ""
    if fmt == "MP3":
        return "bestaudio/best"
    if fmt == "MP4":
        if clip:
            return f"bv{h}[ext=mp4]+ba[ext=m4a]/b{h}[ext=mp4]"
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
    clip: Clip | None = None

    def key(self) -> tuple[str, str, str, str, str, Clip | None]:
        p = urlparse(self.url)
        identity = self.url
        if p.hostname in ("www.youtube.com", "youtube.com", "m.youtube.com", "music.youtube.com"):
            identity = parse_qs(p.query).get("v", [self.url])[0]
        elif p.hostname == "youtu.be":
            identity = p.path.strip("/")
        return (identity, self.source, self.fmt,
                "audio" if self.fmt == "MP3" else self.quality, str(Path(self.destination).resolve()), self.clip)

    def command(self, matched_url: str | None = None) -> list[str]:
        if self.source == "Spotify" and self.clip is None:
            return tool_command("spotdl") + [
                "download", self.url, "--audio", "youtube", "youtube-music",
                "--format", "mp3", "--bitrate", "0", "--ffmpeg", tool_path("ffmpeg"),
                "--output", "{artists} - {title} [{track-id}].{output-ext}",
                "--threads", "1", "--overwrite", "skip", "--simple-tui", "--headless",
                "--max-retries", "2", "--log-level", "INFO", "--lyrics"]
        if self.source == "Spotify" and matched_url is None:
            raise ValueError("A faixa precisa ser localizada no YouTube antes de cortar.")
        template = "%(title)s.%(ext)s"
        if self.clip:
            template = f"%(title)s [{self.clip.start}-{self.clip.end}s].%(ext)s"
        args = ["--ignore-config", "--newline", "--no-quiet", "--progress", "--no-playlist",
                "--no-overwrites", "--no-simulate", "--print", "before_dl:CAESER_TITLE:%(title)j",
                "--print", "after_move:CAESER_FILE:%(filepath)j",
                "--ffmpeg-location", str(Path(tool_path("ffmpeg")).parent),
                "--paths", self.destination, "-o", template,
                "--progress-template", "download:download:%(progress._percent_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._speed_str)s|%(progress._eta)s",
                "-f", selector(self.quality, self.fmt, self.clip)]
        deno = Path(tool_path("deno"))
        if deno.is_file():
            args += ["--js-runtimes", f"deno:{deno}"]
        if self.fmt == "MP4":
            args += ["--merge-output-format", "mp4"]
        elif self.fmt == "WebM":
            args += ["--merge-output-format", "webm"]
        elif self.fmt == "MP3":
            args += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        if self.clip:
            args += ["--match-filters", f"!is_live & duration >? {self.clip.end - 1}",
                     "--download-sections", f"*{self.clip.start}-{self.clip.end}", "--force-keyframes-at-cuts"]
            if self.fmt == "MP3":
                # Encode at the seek point so Opus/WebM doesn't include packets from before the cut.
                args += ["--downloader-args", "ffmpeg_o:-vn -c:a libmp3lame -q:a 0 -f mp3", "--add-metadata"]
            else:
                args += ["--downloader-args", "ffmpeg_o:-c:v libx264 -preset veryfast -crf 18 -c:a aac"]
        return tool_command("yt-dlp") + args + ["--", matched_url or self.url]


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
            self.items = [Download(**{**row, "clip": Clip(**row["clip"]) if row.get("clip") else None})
                          for row in raw.get("items", [])]
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
