"""Developer-only, offline integration test of an extracted macOS app.

Serves only an original generated tone over loopback. No third-party media,
cookies or external tools are used by the app's download/conversion processes.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import os
import subprocess
import sys
import tempfile
import threading

app = Path(sys.argv[1]).resolve(strict=True)
tools = app / "Contents/Resources/Tools"

with tempfile.TemporaryDirectory(prefix="caeser-audio-ação-") as directory:
    root = Path(directory)
    home, output = root / "usuario", root / "Downloads com acentos ação"
    home.mkdir()
    output.mkdir()
    environment = {
        "HOME": str(home), "TMPDIR": str(root),
        "PATH": str(tools) + ":/usr/bin:/bin:/usr/sbin:/sbin",
        "DENO_NO_UPDATE_CHECK": "1", "NO_COLOR": "1", "TERM": "dumb",
        "PYTHONUNBUFFERED": "1",
    }

    def run(name, *arguments):
        result = subprocess.run([str(tools / name), *map(str, arguments)],
                                env=environment, cwd=output, capture_output=True,
                                text=True, timeout=90)
        if result.returncode:
            raise RuntimeError(f"{name}: {result.stdout}\n{result.stderr}")
        return result.stdout

    run("ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i",
        "sine=frequency=523:duration=1", "-c:a", "aac", root / "original.m4a")

    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *arguments):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=root))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        url = f"http://127.0.0.1:{server.server_port}/original.m4a"
        run("yt-dlp", "--ignore-config", "--newline", "--no-playlist",
            "--ffmpeg-location", tools, "--js-runtimes", f"deno:{tools / 'deno'}",
            "--paths", output, "-o", "original.%(ext)s", "-f", "bestaudio/best",
            "-x", "--audio-format", "mp3", "--audio-quality", "0", "--", url)
        mp3 = output / "original.mp3"
        assert mp3.is_file() and mp3.stat().st_size > 1000
        result = json.loads(run("ffprobe", "-v", "error", "-show_streams",
                                "-show_format", "-of", "json", mp3))
        assert result["streams"][0]["codec_name"] == "mp3"
        assert 0.8 < float(result["format"]["duration"]) < 1.5
        print(json.dumps({"succeeded": True, "download": "loopback original tone",
                          "mp3Bytes": mp3.stat().st_size, "externalDependencies": False,
                          "unicodeAndSpaces": True}, ensure_ascii=False))
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
