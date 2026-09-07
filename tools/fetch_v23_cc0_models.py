import json
import pathlib
import shutil
import urllib.request
import zipfile

ROOT = pathlib.Path("assets/v23/vegetation")
ROOT.mkdir(parents=True, exist_ok=True)
BASE = "https://api.polyhaven.com/files/"
UA = "BogazKaptani-UltraRealism/30.0 (+https://github.com/Kabatepe03/bogaz-kaptani)"

# V23's pine_tree_01 geometry package exceeded ~900 MB before Godot import. V30 keeps two real
# Poly Haven CC0 tree species for the close layer and uses the merged kilometre-scale forest as LOD.
# This makes the APK/install practical without returning to cone/tree placeholders.
ASSETS = {
    "tree_small_02": "2k",
    "island_tree_03": "2k",
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
        # Prefer self-contained GLB/GTLF before archives when Poly Haven exposes both.
        if lower.endswith(".glb"):
            gltf_records.append((0, path, record))
        elif lower.endswith(".gltf"):
            gltf_records.append((1, path, record))
        elif lower.endswith(".zip"):
            gltf_records.append((2, path, record))
    if not gltf_records:
        raise RuntimeError(f"No {resolution} glTF package found for {asset_id}")
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

    candidates = sorted(out_dir.rglob("*.glb")) + sorted(out_dir.rglob("*.gltf"))
    if not candidates:
        raise RuntimeError(f"Downloaded {asset_id} but no glTF/GLB was found")
    model = candidates[0]
    return model.relative_to(pathlib.Path("."))


def main():
    # Remove the old giant pine directory if a cached workspace ever contains it.
    old_pine = ROOT / "pine_tree_01"
    if old_pine.exists():
        shutil.rmtree(old_pine)

    manifest = {}
    failures = {}
    for asset_id, resolution in ASSETS.items():
        try:
            model_path = fetch_asset(asset_id, resolution)
            manifest[asset_id] = model_path.as_posix()
            print(asset_id, "->", model_path)
        except Exception as exc:
            failures[asset_id] = str(exc)
            print(f"WARNING: {asset_id}: {exc}")
    payload = {"models": manifest, "failures": failures, "license": "Poly Haven CC0", "near_resolution": "2k", "version": "v30"}
    (ROOT / "MANIFEST.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (ROOT / "ATTRIBUTION.txt").write_text(
        "Boğaz Kaptanı V30 near vegetation\nPoly Haven CC0 assets: tree_small_02, island_tree_03.\nClose vegetation uses 2K packages; distant forest is merged game LOD geometry.\nhttps://polyhaven.com/\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
