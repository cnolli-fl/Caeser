"""Release discovery and AppImage replacement for Caeser Linux."""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


RELEASES_PAGE = "https://github.com/cnolli-fl/Caeser/releases"
RELEASES_API = "https://api.github.com/repos/cnolli-fl/Caeser/releases"
VERSION_PATTERN = r"[0-9]+\.[0-9]+\.[0-9]+"


@dataclass(frozen=True)
class LinuxRelease:
    version: str
    download_url: str
    sha256: str
    size: int

    @property
    def page_url(self) -> str:
        return f"{RELEASES_PAGE}/tag/linux-v{self.version}"


def version_parts(version: str) -> tuple[int, ...]:
    return tuple(map(int, version.split(".")))


def select_update(releases: list, current: str, arch: str) -> LinuxRelease | None:
    candidates = []
    for release in releases:
        tag = re.fullmatch(rf"linux-v({VERSION_PATTERN})", release.get("tag_name", ""))
        if release.get("draft") or not tag:
            continue
        version = tag[1]
        if version_parts(version) <= version_parts(current):
            continue
        name = f"Caeser-{version}-Linux-{arch}.AppImage"
        url = f"{RELEASES_PAGE}/download/{tag[0]}/{name}"
        for asset in release.get("assets", []):
            if asset.get("name") != name or asset.get("state") != "uploaded" or asset.get("browser_download_url") != url:
                continue
            digest = re.fullmatch(r"sha256:([a-f0-9]{64})", asset.get("digest") or "")
            size = asset.get("size")
            if digest and type(size) is int and size > 0:
                candidates.append(LinuxRelease(version, url, digest[1], size))
    return max(candidates, key=lambda release: version_parts(release.version), default=None)


def check_for_update(current: str, arch: str) -> LinuxRelease | None:
    request = urllib.request.Request(f"{RELEASES_API}?per_page=100", headers={
        "User-Agent": f"Caeser-Linux/{current}",
        "Accept": "application/vnd.github+json",
    })
    with urllib.request.urlopen(request, timeout=12) as response:
        raw = response.read(8_000_001)
    if len(raw) > 8_000_000:
        raise ValueError("A lista de versões do GitHub veio grande demais.")
    releases = json.loads(raw)
    if not isinstance(releases, list):
        raise ValueError("O GitHub não retornou a lista de versões.")
    return select_update(releases, current, arch)


def appimage_path() -> Path | None:
    running = os.environ.get("APPIMAGE")
    if running:
        path = Path(running).resolve()
        if path.is_file():
            with path.open("rb") as file:
                if is_appimage(file.read(11)):
                    return path
    return None


def is_appimage(header: bytes) -> bool:
    return header.startswith(b"\x7fELF") and header[8:11] == b"AI\x02"


def install_update(release: LinuxRelease, target: Path, progress: Callable[[int], None],
                   cancelled: Callable[[], bool]) -> bool:
    original = target.stat()
    digest = hashlib.sha256()
    downloaded = 0
    last_percent = -1
    path = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".caeser-update-", delete=False) as output:
            path = Path(output.name)
            request = urllib.request.Request(release.download_url, headers={"User-Agent": "Caeser-Linux"})
            with urllib.request.urlopen(request, timeout=20) as response:
                header = response.read(11)
                if not is_appimage(header):
                    raise ValueError("O GitHub retornou um arquivo que não é um AppImage.")
                chunk = header
                while chunk:
                    if cancelled():
                        return False
                    downloaded += len(chunk)
                    if downloaded > release.size:
                        raise ValueError("O tamanho do arquivo difere do informado no GitHub.")
                    digest.update(chunk)
                    output.write(chunk)
                    percent = min(99, 100 * downloaded // release.size)
                    if percent != last_percent:
                        progress(percent)
                        last_percent = percent
                    chunk = response.read(1_048_576)
            if downloaded != release.size or digest.hexdigest() != release.sha256:
                raise ValueError("O arquivo não passou na verificação de integridade. Tente baixar novamente.")
            os.fchmod(output.fileno(), (stat.S_IMODE(original.st_mode) & 0o777) | stat.S_IXUSR)
            output.flush()
            os.fsync(output.fileno())
        if cancelled():
            return False
        if not os.path.samestat(target.stat(), original):
            raise ValueError("O AppImage foi alterado durante a atualização. Abra o arquivo atual e tente de novo.")
        os.replace(path, target)
    finally:
        if path is not None:
            path.unlink(missing_ok=True)
    progress(100)
    return True
