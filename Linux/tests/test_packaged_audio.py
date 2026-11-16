"""End-to-end check of yt-dlp and FFmpeg inside the finished AppImage."""

from __future__ import annotations

import http.server
import math
import os
import socketserver
import struct
import subprocess
import sys
import tempfile
import threading
import wave
from pathlib import Path


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main(package: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="caeser-audio-smoke-") as temporary:
        root = Path(temporary)
        sample = root / "sample.wav"
        with wave.open(str(sample), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(22050)
            samples = (int(4500 * math.sin(2 * math.pi * 440 * n / 22050)) for n in range(22050))
            audio.writeframes(b"".join(struct.pack("<h", sample) for sample in samples))

        handler = lambda *args, **kwargs: http.server.SimpleHTTPRequestHandler(
            *args, directory=str(root), **kwargs
        )
        with ReusableTCPServer(("127.0.0.1", 0), handler) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            output = root / "output"
            output.mkdir()
            command = [str(package), "--tool", "yt-dlp", "--ignore-config", "--no-playlist",
                       "--extract-audio", "--audio-format", "mp3", "--audio-quality", "0",
                       "--paths", str(output), "-o", "%(title)s.%(ext)s",
                       f"http://127.0.0.1:{server.server_address[1]}/sample.wav"]
            environment = os.environ.copy()
            environment["APPIMAGE_EXTRACT_AND_RUN"] = "1"
            result = subprocess.run(command, capture_output=True, text=True, timeout=120,
                                    env=environment, check=False)
            server.shutdown()
        converted = output / "sample.mp3"
        if result.returncode or not converted.is_file() or converted.stat().st_size < 1000:
            raise RuntimeError(f"Conversão MP3 falhou:\n{result.stdout}\n{result.stderr}")
        print(f"MP3 de teste criado: {converted.stat().st_size} bytes")


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve())
