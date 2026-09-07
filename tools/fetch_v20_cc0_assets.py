import hashlib
import json
import os
import pathlib
import urllib.request

ROOT = pathlib.Path("assets/v20")
MATS = ROOT / "materials"
LIGHT = ROOT / "lighting"
ROOT.mkdir(parents=True, exist_ok=True)
MATS.mkdir(parents=True, exist_ok=True)
LIGHT.mkdir(parents=True, exist_ok=True)

UA = "BogazKaptani-Remaster/20.0 (+https://github.com/Kabatepe03/bogaz-kaptani)"
BASE = "https://api.polyhaven.com/files/"


def get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def download(url: str, target: pathlib.Path, md5: str | None = None):
    target.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=180) as response, open(target, "wb") as stream:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            stream.write(chunk)
    if md5:
        digest = hashlib.md5(target.read_bytes()).hexdigest()
        if digest.lower() != md5.lower():
            raise RuntimeError(f"MD5 mismatch for {target}: {digest} != {md5}")
    print(f"downloaded {target} ({target.stat().st_size / 1024 / 1024:.1f} MB)")


def flatten(node, prefix=""):
    found = []
    if isinstance(node, dict):
        if isinstance(node.get("url"), str):
            found.append((prefix.lower(), node))
        for key, value in node.items():
            if key in {"url", "size", "md5", "include"}:
                continue
            child_prefix = f"{prefix}/{key}" if prefix else str(key)
            found.extend(flatten(value, child_prefix))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            found.extend(flatten(value, f"{prefix}/{index}"))
    return found


def pick(records, resolution: str, tokens: tuple[str, ...], extensions: tuple[str, ...]):
    candidates = []
    for path, record in records:
        url = record.get("url", "")
        lower_url = url.lower()
        if resolution and resolution not in path and resolution not in lower_url:
            continue
        if not any(token in path or token in lower_url for token in tokens):
            continue
        if extensions and not any(lower_url.split("?")[0].endswith(ext) for ext in extensions):
            continue
        size = int(record.get("size") or 0)
        candidates.append((size, path, record))
    if not candidates:
        raise RuntimeError(f"No matching Poly Haven file for res={resolution}, tokens={tokens}, ext={extensions}")
    # Prefer the largest matching file at the requested resolution; it is usually the full-quality map.
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][2]


def fetch_texture(asset_id: str, prefix: str):
    tree = get_json(BASE + asset_id)
    records = flatten(tree)
    maps = {
        "diff": (("diff", "albedo", "basecolor"), (".jpg", ".png")),
        "normal": (("nor_gl", "normal_gl", "normal"), (".jpg", ".png")),
        "rough": (("rough",), (".jpg", ".png")),
    }
    for suffix, (tokens, exts) in maps.items():
        record = pick(records, "2k", tokens, exts)
        ext = pathlib.Path(record["url"].split("?")[0]).suffix or ".jpg"
        download(record["url"], MATS / f"{prefix}_{suffix}{ext}", record.get("md5"))


def fetch_hdri(asset_id: str):
    tree = get_json(BASE + asset_id)
    records = flatten(tree)
    record = pick(records, "2k", ("hdr",), (".hdr",))
    download(record["url"], LIGHT / "harbour_day_2k.hdr", record.get("md5"))


def main():
    # Photo-scanned CC0 surface maps. 2K is enough for the mobile target while still giving a
    # major jump over flat-color procedural materials.
    fetch_texture("asphalt_01", "asphalt")
    fetch_texture("concrete", "concrete")
    fetch_texture("metal_plate", "ramp_metal")

    # Used for image-based ambient/reflection lighting only. The panorama itself is not shown,
    # so Çanakkale's generated skyline remains the visible background.
    fetch_hdri("simons_town_harbour")

    attribution = """Boğaz Kaptanı v20 Remaster - external asset notes\n\nPoly Haven assets are CC0 / public-domain-equivalent.\nLive API and downloads: https://polyhaven.com/ and https://api.polyhaven.com/\nAssets used in this build:\n- asphalt_01 (PBR texture)\n- concrete (PBR texture)\n- metal_plate (PBR texture)\n- simons_town_harbour (HDRI, lighting/reflections only)\n\nOpenStreetMap-derived world data retains its own attribution in-game.\n"""
    (ROOT / "ATTRIBUTION.txt").write_text(attribution, encoding="utf-8")


if __name__ == "__main__":
    main()
