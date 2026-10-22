"""Collect version-pinned upstream sources/notices without executing downloaded code."""
import concurrent.futures
import hashlib
import json
import pathlib
import re
import shutil
import sys
import tarfile
import time
import tomllib
import urllib.request

tools = pathlib.Path(sys.argv[1]).resolve()
tools.mkdir(parents=True, exist_ok=True)
cache = pathlib.Path(sys.argv[2]).resolve()
cache.mkdir(parents=True, exist_ok=True)
sources = tools / "Sources"
licenses = tools / "Licenses"
sources.mkdir(exist_ok=True)
licenses.mkdir(exist_ok=True)


def fetch(url, path, digest=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        for attempt in range(4):
            try:
                request = urllib.request.Request(url, headers={"User-Agent": "Caeser-source-notices/1.1.1"})
                with urllib.request.urlopen(request, timeout=90) as response, path.open("wb") as output:
                    shutil.copyfileobj(response, output)
                break
            except Exception:
                path.unlink(missing_ok=True)
                if attempt == 3:
                    raise
                time.sleep(2 ** attempt)
    with path.open("rb") as verified:
        actual = hashlib.file_digest(verified, "sha256").hexdigest()
    if digest and actual != digest:
        raise RuntimeError(f"Source checksum mismatch: {path.name}")
    return actual


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def python_source(package):
    name, version = package["name"], package["version"]
    safe = re.sub(r"[^a-zA-Z0-9_.-]", "_", name)
    metadata = cache / "python" / f"{safe}-{version}.json"
    fetch(f"https://pypi.org/pypi/{name}/{version}/json", metadata)
    release = json.loads(metadata.read_text(encoding="utf-8"))
    source = next((item for item in release["urls"] if item["packagetype"] == "sdist"), None)
    if source is None:
        raise RuntimeError(f"No upstream source distribution for {name} {version}")
    target = sources / "Python-packages" / pathlib.PurePosixPath(source["filename"]).name
    digest = fetch(source["url"], target, source["digests"]["sha256"])
    return {"name": name, "version": version, "url": source["url"], "sha256": digest, "file": target.name}


def rust_notice(package):
    name, version = package["name"], package["version"]
    archive = cache / "rust" / f"{name}-{version}.crate"
    url = f"https://static.crates.io/crates/{name}/{name}-{version}.crate"
    digest = fetch(url, archive, package["checksum"])
    target = licenses / "Deno-dependencies" / f"{name}-{version}"
    target.mkdir(parents=True, exist_ok=True)
    notices = []
    expression = ""
    with tarfile.open(archive, "r:gz") as contents:
        for item in contents:
            leaf = pathlib.PurePosixPath(item.name).name
            legal = re.match(r"^(licen[cs]e|copying|notice|copyright)", leaf, re.IGNORECASE)
            manifest = item.name == f"{name}-{version}/Cargo.toml"
            if not item.isfile() or item.size > 4_000_000 or not (legal or manifest):
                continue
            data = contents.extractfile(item).read()
            if manifest:
                expression = tomllib.loads(data.decode("utf-8")).get("package", {}).get("license", "")
            filename = re.sub(r"[^a-zA-Z0-9_.-]", "_", item.name)
            (target / filename).write_bytes(data)
            notices.append(filename)
    if not expression or re.search(r"GPL|MPL|CDDL|EPL", expression, re.IGNORECASE):
        copy = sources / "Deno-dependencies" / archive.name
        copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(archive, copy)
    return {"name": name, "version": version, "license": expression, "url": url, "sha256": digest, "notices": notices}


if sys.argv[3] == "python":
    inventory = json.loads((licenses / "Python-packages" / "packages.json").read_text(encoding="utf-8"))
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        result = list(pool.map(python_source, inventory))
    save_json(sources / "Python-packages" / "sources.json", result)
    print(f"Verified source distributions for {len(result)} Python packages.")
elif sys.argv[3] == "deno":
    lock = sources / "Deno-Cargo.lock"
    fetch("https://raw.githubusercontent.com/denoland/deno/v2.9.8/Cargo.lock", lock)
    packages = tomllib.loads(lock.read_text(encoding="utf-8"))["package"]
    registry = [p for p in packages if p.get("source", "").startswith("registry+")]
    if any(p.get("source", "").startswith("git+") for p in packages):
        raise RuntimeError("Review new Git dependencies before updating Deno.")
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        result = list(pool.map(rust_notice, registry))
    save_json(licenses / "Deno-dependencies" / "packages.json", result)
    # The Rust crate excludes V8's LICENSE files. Fetch the native engine notices
    # from the exact submodule commit used by rusty_v8 150.4.0 in Deno's lockfile.
    revision = "ac1e23989121713ca642f6650b34deff7b686896"
    tree_file = cache / "v8-tree.json"
    fetch(f"https://api.github.com/repos/denoland/v8/git/trees/{revision}?recursive=1", tree_file)
    tree = json.loads(tree_file.read_text(encoding="utf-8"))
    if tree.get("truncated"):
        raise RuntimeError("V8 source inventory is incomplete.")
    paths = [p["path"] for p in tree["tree"] if p["type"] == "blob" and
             re.match(r"^(licen[cs]e|copying|notice|copyright)", pathlib.PurePosixPath(p["path"]).name, re.IGNORECASE)]

    def native_notice(path):
        target = licenses / "V8" / re.sub(r"[^a-zA-Z0-9_.-]", "_", path)
        url = f"https://raw.githubusercontent.com/denoland/v8/{revision}/{path}"
        return {"path": path, "url": url, "sha256": fetch(url, target)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        native = list(pool.map(native_notice, paths))
    if not any(p["path"] == "LICENSE" for p in native):
        raise RuntimeError("V8 license missing.")
    save_json(licenses / "V8" / "sources.json", native)
    print(f"Collected notices for {len(result)} locked Rust packages and {len(native)} V8 files.")
else:
    raise SystemExit("Choose python or deno.")
