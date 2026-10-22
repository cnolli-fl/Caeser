"""Collect installed distribution notices; no credentials or user's Python config."""
import importlib.metadata
import json
import pathlib
import re
import shutil
import sys

destination = pathlib.Path(sys.argv[1]).resolve()
destination.mkdir(parents=True, exist_ok=True)
packages = []
for distribution in importlib.metadata.distributions():
    name = distribution.metadata.get("Name", "unknown")
    safe = re.sub(r"[^a-zA-Z0-9_.-]", "_", name)
    target = destination / safe
    target.mkdir(exist_ok=True)
    metadata = distribution.read_text("METADATA")
    if metadata:
        (target / "METADATA.txt").write_text(metadata, encoding="utf-8")
    notices = []
    for entry in distribution.files or []:
        filename = str(entry).replace("\\", "/")
        if any(token in pathlib.PurePosixPath(filename).name.lower() for token in ("license", "copying", "notice", "authors")):
            source = pathlib.Path(distribution.locate_file(entry))
            if source.is_file():
                relative = re.sub(r"[^a-zA-Z0-9_.-]", "_", filename)
                shutil.copyfile(source, target / relative)
                notices.append(relative)
    packages.append({"name": name, "version": distribution.version, "notices": notices})
(destination / "packages.json").write_text(json.dumps(packages, indent=2), encoding="utf-8")
