import json
import pathlib
import shutil
import urllib.request
import zipfile

ROOT = pathlib.Path("assets/v23/vegetation")
ROOT.mkdir(parents=True, exist_ok=True)
BASE = "https://api.polyhaven.com/files/"
UA = "BogazKaptani-DigitalTwin/23.0 (+https://github.com/Kabatepe03/bogaz-kaptani)"

ASSETS = {
    "pine_tree_01": "1k",
    "tree_small_02": "1k",
    "island_tree_03": "1k",
}


def get_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=90) as response:
        return json.load(response)


def walk(node, path=""):
    if isinstance(node, dict):
        if isinstance(node.get("url"), str):
            yield path.lower(), node
        for key, value in node.items():
            if key in {"url", "size", "md5"}:
                continue
            next_path = f"{path}/{key}" if path else str(key)
            yield from walk(value, next_path)
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from walk(value, f"{path}/{index}")


def download(url: str, target: pathlib.Path):
    target.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=360) as response, target.open("wb") as stream:
        shutil.copyfileobj(response, stream, length=1024 * 1024)
    print(f"downloaded {target}: {target.stat().st_size / 1024 / 1024:.1f} MB")


def choose(records, asset_id: str, resolution: str):
    gltf_records = []
    for path, record in records:
        url = record.get("url", "")
        lower = url.lower().split("?")[0]
        if resolution not in path and resolution not in lower:
            continue
        if "gltf" not in path and "gltf" not in lower:
            continue
        if lower.endswith(".zip"):
            gltf_records.append((0, path, record))
        elif lower.endswith(".gltf") or lower.endswith(".glb"):
            gltf_records.append((1, path, record))
    if not gltf_records:
        raise RuntimeError(f"No {resolution} glTF package found for {asset_id}")
    # Prefer a packaged ZIP because it preserves all dependent textures/bin files. Otherwise use
    # the main glTF record and recursively download its include tree.
    gltf_records.sort(key=lambda item: item[0])
    return gltf_records[0][2]


def download_includes(include_node, target_dir: pathlib.Path, prefix=""):
    if include_node is None:
        return
    if isinstance(include_node, dict):
        if isinstance(include_node.get("url"), str):
            url = include_node["url"]
            name = pathlib.Path(url.split("?")[0]).name
            rel = pathlib.Path(prefix) if pathlib.Path(prefix).suffix else pathlib.Path(prefix) / name
            download(url, target_dir / rel)
            return
        for key, value in include_node.items():
            if key in {"size", "md5"}:
                continue
            child_prefix = f"{prefix}/{key}" if prefix else str(key)
            download_includes(value, target_dir, child_prefix)
    elif isinstance(include_node, list):
        for value in include_node:
            download_includes(value, target_dir, prefix)


def fetch_asset(asset_id: str, resolution: str):
    tree = get_json(BASE + asset_id)
    records = list(walk(tree))
    record = choose(records, asset_id, resolution)
    out_dir = ROOT / asset_id
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)
    url = record["url"]
    filename = pathlib.Path(url.split("?")[0]).name
    target = out_dir / filename
    download(url, target)
    if target.suffix.lower() == ".zip":
        with zipfile.ZipFile(target) as zf:
            zf.extractall(out_dir)
        target.unlink()
    else:
        download_includes(record.get("include"), out_dir)

    candidates = sorted(out_dir.rglob("*.gltf")) + sorted(out_dir.rglob("*.glb"))
    if not candidates:
        raise RuntimeError(f"Downloaded {asset_id} but no glTF/GLB was found")
    model = candidates[0]
    return model.relative_to(pathlib.Path("."))


def main():
    manifest = {}
    failures = {}
    for asset_id, resolution in ASSETS.items():
        try:
            model_path = fetch_asset(asset_id, resolution)
            manifest[asset_id] = model_path.as_posix()
            print(asset_id, "->", model_path)
        except Exception as exc:
            # The game has procedural foliage fallbacks, so an upstream CDN/API outage must not
            # destroy the whole Android build. We still record the error prominently in the manifest.
            failures[asset_id] = str(exc)
            print(f"WARNING: {asset_id}: {exc}")
    payload = {"models": manifest, "failures": failures, "license": "Poly Haven CC0"}
    (ROOT / "MANIFEST.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (ROOT / "ATTRIBUTION.txt").write_text(
        "Boğaz Kaptanı v23 vegetation\nPoly Haven CC0 assets: pine_tree_01, tree_small_02, island_tree_03.\nhttps://polyhaven.com/\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
