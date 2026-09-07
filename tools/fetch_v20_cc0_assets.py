import hashlib
import json
import pathlib
import urllib.request

ROOT = pathlib.Path("assets/v20")
MATS = ROOT / "materials"
TERRAIN = ROOT / "terrain"
LIGHT = ROOT / "lighting"
ROOT.mkdir(parents=True, exist_ok=True)
MATS.mkdir(parents=True, exist_ok=True)
TERRAIN.mkdir(parents=True, exist_ok=True)
LIGHT.mkdir(parents=True, exist_ok=True)

UA = "BogazKaptani-DigitalTwin/23.0 (+https://github.com/Kabatepe03/bogaz-kaptani)"
BASE = "https://api.polyhaven.com/files/"


def get_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)


def download(url: str, target: pathlib.Path, md5: str | None = None):
    target.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=420) as response, open(target, "wb") as stream:
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
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][2]


def fetch_texture(asset_id: str, prefix: str, resolution="4k", target_dir=MATS, maps=("diff", "normal", "rough")):
    tree = get_json(BASE + asset_id)
    records = flatten(tree)
    definitions = {
        "diff": (("diff", "albedo", "basecolor"), (".jpg", ".png")),
        "normal": (("nor_gl", "normal_gl", "normal"), (".jpg", ".png")),
        "rough": (("rough",), (".jpg", ".png")),
    }
    for suffix in maps:
        tokens, exts = definitions[suffix]
        record = pick(records, resolution, tokens, exts)
        ext = pathlib.Path(record["url"].split("?")[0]).suffix or ".jpg"
        download(record["url"], target_dir / f"{prefix}_{suffix}{ext}", record.get("md5"))


def fetch_hdri(asset_id: str):
    tree = get_json(BASE + asset_id)
    records = flatten(tree)
    record = pick(records, "4k", ("hdr",), (".hdr",))
    # Keep the legacy filename because the game uses this HDRI only for reflections/IBL.
    download(record["url"], LIGHT / "harbour_day_2k.hdr", record.get("md5"))


def main():
    # Close-up terminal and Kordon surfaces: 4K because the camera can get within metres.
    fetch_texture("asphalt_01", "asphalt", "4k")
    fetch_texture("concrete", "concrete", "4k")
    fetch_texture("metal_plate", "ramp_metal", "4k")

    # Landscape layers are world-projected across kilometres. 2K gives substantially more detail
    # than the previous 1K pack while remaining sane for Android texture memory.
    fetch_texture("withered_grass", "dry_grass", "2k", TERRAIN, ("diff", "rough"))
    fetch_texture("dirt", "dirt", "2k", TERRAIN, ("diff", "rough"))
    fetch_texture("rocky_terrain", "rock", "2k", TERRAIN, ("diff", "rough"))

    # Reflection/ambient source only; the foreign panorama itself is never rendered as the sky.
    fetch_hdri("simons_town_harbour")

    attribution = """Boğaz Kaptanı v23 Digital Twin - external asset notes\n\nPoly Haven assets are CC0 / public-domain-equivalent.\nhttps://polyhaven.com/\nAssets used:\n- asphalt_01 4K PBR\n- concrete 4K PBR\n- metal_plate 4K PBR\n- withered_grass 2K terrain\n- dirt 2K terrain\n- rocky_terrain 2K terrain\n- simons_town_harbour 4K HDRI (lighting/reflections only; never visible as Çanakkale)\n\nOpenStreetMap-derived world data retains its own attribution in-game.\n"""
    (ROOT / "ATTRIBUTION.txt").write_text(attribution, encoding="utf-8")


if __name__ == "__main__":
    main()
