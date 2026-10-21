"""Extract notices already embedded in PyInstaller archives, without running them.

Developer-only helper. Requires PyInstaller (not part of the end-user install).
Run with: python CollectToolLicenses.py ToolsDirectory
"""
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tempfile
from PyInstaller.archive.readers import CArchiveReader

tools = Path(sys.argv[1]).resolve()
for name in ("spotdl", "yt-dlp"):
    archive = CArchiveReader(str(tools / name))
    output = tools / "Licenses" / name
    count = 0
    for item in archive.toc:
        path = PurePosixPath(item)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"Unsafe archive member: {item}")
        if any(word in path.name.lower() for word in ("license", "copying", "notice")):
            target = output.joinpath(*path.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extract(item))
            count += 1
    print(f"{name}: {count} embedded notices extracted")
    # Inspect embedded Python/extensions too: checking only the bootloader could
    # miss a hidden dependency on the build machine's Homebrew installation.
    inspected = 0
    with tempfile.TemporaryDirectory(prefix="caeser-native-audit-") as directory:
        for item in archive.toc:
            if not (item.endswith((".so", ".dylib")) or PurePosixPath(item).name == "Python"):
                continue
            data = archive.extract(item)
            if data[:4] not in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
                continue
            binary = Path(directory) / f"native-{inspected}"
            binary.write_bytes(data)
            result = subprocess.run(["/usr/bin/otool", "-L", str(binary)], check=True, capture_output=True, text=True)
            for line in result.stdout.splitlines():
                if not line.startswith("\t"):
                    continue
                dependency = line.strip().split(" (", 1)[0]
                if dependency.startswith("/") and not dependency.startswith(("/usr/lib/", "/System/Library/")):
                    raise RuntimeError(f"External dependency in {name}/{item}: {dependency}")
            inspected += 1
    print(f"{name}: {inspected} embedded native libraries audited")
