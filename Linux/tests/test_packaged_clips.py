"""Open the packaged Qt app and validate both trim formats with a local fixture."""

from __future__ import annotations

import functools
import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
from pathlib import Path


def main(package: Path):
    with tempfile.TemporaryDirectory(prefix="caeser-clip-smoke-") as temp:
        root = Path(temp)
        output = root / "clips"
        output.mkdir()
        subprocess.run([
            "ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=red:size=160x90:rate=24:duration=9",
            "-f", "lavfi", "-i", "sine=frequency=440:duration=9", "-vf",
            "drawbox=c=blue:t=fill:enable='gte(t,2.5)'", "-c:v", "libx264", "-g", "120",
            "-c:a", "aac", "-movflags", "+faststart", str(root / "sample.mp4"),
        ], check=True, timeout=20)
        handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
            worker = threading.Thread(target=server.serve_forever, daemon=True)
            worker.start()
            try:
                env = dict(os.environ, XDG_DATA_HOME=str(root / "data"), APPIMAGE_EXTRACT_AND_RUN="1",
                           QT_QPA_PLATFORM="offscreen", CAESER_SMOKE_DESTINATION=str(output),
                           CAESER_SMOKE_VIDEO=f"http://127.0.0.1:{server.server_port}/sample.mp4")
                subprocess.run([str(package), "--smoke-clip-download"], env=env, check=True, timeout=90)
            finally:
                server.shutdown()
                worker.join()

        for name, expected_duration in (("Meu trecho 100%", 4), ("Meu final 100%", 6)):
            for extension in ("mp3", "mp4"):
                filename = output / f"{name}.{extension}"
                info = json.loads(subprocess.check_output([
                    "ffprobe", "-v", "error", "-show_entries", "stream=codec_name:format=duration",
                    "-of", "json", str(filename),
                ], timeout=10))
                duration = float(info["format"]["duration"])
                codecs = {stream["codec_name"] for stream in info["streams"]}
                expected_codecs = {"h264", "aac"} if extension == "mp4" else {"mp3"}
                if abs(duration - expected_duration) > 0.18 or codecs != expected_codecs:
                    raise RuntimeError(f"Trecho {extension} inválido: {duration}s · {codecs}")
                print(f"{filename.name}: {duration:.3f}s · {', '.join(sorted(codecs))}")

        first_pixel = subprocess.check_output([
            "ffmpeg", "-v", "error", "-i", str(output / "Meu trecho 100%.mp4"), "-frames:v", "1",
            "-vf", "scale=1:1", "-pix_fmt", "rgb24", "-f", "rawvideo", "-",
        ], timeout=10)
        if len(first_pixel) != 3 or first_pixel[2] <= first_pixel[0]:
            raise RuntimeError("O trecho começa antes do ponto de corte.")


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve())
