"""Idempotent .tres animation wiring. Defaults to validation; --apply writes.

Identical duplicate declarations are collapsed. Conflicting duplicate IDs or
properties are rejected before any write. Existing source/frame files are kept.
"""
import argparse
import re
from pathlib import Path
from PIL import Image
from art_safety import PROJECT_ROOT, checked_path, write_text

RES_DIR = PROJECT_ROOT / "resources"
ASSETS = "res://assets"
FRAME_SETS = {
    unit: {
        "attack": (["idle", "windup", "strike", "recover"] if unit == "enforcer" else
                   ["ready", "reach", "peak", "pullback"] if unit == "field_medic" else
                   ["ready", "fire", "recoil", "settle"]),
        "walk": ["walk1", "walk2", "walk3", "walk4"],
        "retreat": ["retreat1", "retreat2", "retreat3", "retreat4"],
    } for unit in ("enforcer", "trooper", "marksman", "demolitionist", "field_medic")
}
PROP = re.compile(r"^(lv[23]_)?(idle|attack|walk|retreat)_frames$")
EXT = re.compile(r'^\[ext_resource\s+(.+)\]$')
ATTR = re.compile(r'(\w+)="([^"]*)"')
ASSIGN = re.compile(r"^(\w+)\s*=\s*(.*)$")


def wired_text(text, frame_sets):
    """Return validated rewritten text without changing any files."""
    parts = re.split(r"(?m)^\[resource\]\s*$", text)
    if len(parts) != 2:
        raise ValueError("Expected exactly one [resource] section")
    header, body = parts
    ext_ids, path_ids, header_lines = {}, {}, []
    for line in header.splitlines():
        match = EXT.fullmatch(line.strip())
        if not match:
            header_lines.append(line)
            continue
        attrs = dict(ATTR.findall(match.group(1)))
        if not all(key in attrs for key in ("type", "path", "id")):
            raise ValueError(f"Malformed ext_resource: {line}")
        ext_id = attrs["id"]
        if ext_id in ext_ids:
            if ext_ids[ext_id] != attrs:
                raise ValueError(f"Conflicting duplicate ext_resource ID: {ext_id}")
            continue
        ext_ids[ext_id] = attrs
        path_ids.setdefault((attrs["type"], attrs["path"]), ext_id)
        header_lines.append(line)
    body_lines, properties = [], {}
    for line in body.splitlines():
        match = ASSIGN.fullmatch(line)
        if not match:
            body_lines.append(line)
            continue
        key, value = match.groups()
        if key in properties:
            if properties[key] != value:
                raise ValueError(f"Conflicting duplicate property: {key}")
            continue
        properties[key] = value
        body_lines.append(line)
    for prop, paths in frame_sets.items():
        if not PROP.fullmatch(prop) or len(paths) != 4 or len(set(paths)) != 4:
            raise ValueError(f"Invalid four-frame animation property: {prop}")
        ids = []
        for index, path in enumerate(paths, 1):
            if not path.startswith("res://assets/") or '"' in path or "\n" in path:
                raise ValueError(f"Invalid frame resource path: {path}")
            key = ("Texture2D", path)
            ext_id = path_ids.get(key)
            if ext_id is None:
                base = f"frame_{prop}_{index}"
                ext_id, suffix = base, 1
                while ext_id in ext_ids:
                    ext_id = f"{base}_{suffix}"
                    suffix += 1
                ext_ids[ext_id] = {"type": "Texture2D", "path": path, "id": ext_id}
                path_ids[key] = ext_id
                header_lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{ext_id}"]')
            ids.append(f'ExtResource("{ext_id}")')
        value = f"Array[Texture2D]([{', '.join(ids)}])"
        replacement = f"{prop} = {value}"
        if prop in properties:
            if properties[prop].count("[") != properties[prop].count("]"):
                raise ValueError(f"Multiline property replacement is unsupported: {prop}")
            body_lines = [replacement if (m := ASSIGN.fullmatch(line)) and m[1] == prop else line
                          for line in body_lines]
        else:
            body_lines.append(replacement)
    header = "\n".join(header_lines).rstrip()
    count = len(ext_ids) + len(re.findall(r"(?m)^\[sub_resource\b", header)) + 1
    if not re.search(r"\bload_steps=\d+", header):
        raise ValueError("Resource header is missing load_steps")
    header = re.sub(r"\bload_steps=\d+", f"load_steps={count}", header, count=1)
    result = header + "\n\n[resource]\n" + "\n".join(body_lines).strip("\n") + "\n"
    missing = set(re.findall(r'ExtResource\("([^"]+)"\)', result)) - set(ext_ids)
    if missing:
        raise ValueError(f"Unresolved external resource IDs: {sorted(missing)}")
    return result


def validate_frame(path):
    path = checked_path(path, must_exist=True)
    with Image.open(path) as frame:
        if frame.size != (512, 512) or "A" not in frame.getbands():
            raise ValueError(f"Runtime frame must be 512x512 with alpha: {path}")
        if frame.getchannel("A").getbbox() is None:
            raise ValueError(f"Runtime frame is empty: {path}")


def plan_manifest_wiring(manifest, *, allow_pending_outputs=False):
    from slice_sheets import entry_outputs
    grouped = {}
    for entry in manifest["entries"]:
        if "resource" not in entry or "property" not in entry:
            raise ValueError("--wire requires resource and property on every entry")
        resource = checked_path(entry["resource"], must_exist=True)
        if resource.parent != RES_DIR or resource.suffix != ".tres":
            raise ValueError("Unit resources must be .tres files directly under resources/")
        outputs = entry_outputs(entry)
        if not allow_pending_outputs:
            for path in outputs:
                validate_frame(path)
        prop = entry["property"]
        if prop in grouped.setdefault(resource, {}):
            raise ValueError(f"Manifest sets the same property twice: {resource} / {prop}")
        grouped[resource][prop] = ["res://" + p.relative_to(PROJECT_ROOT).as_posix() for p in outputs]
    return {path: wired_text(path.read_text(encoding="utf-8-sig"), sets)
            for path, sets in grouped.items()}


def process(unit: str, *, apply=True):
    """Preserve the legacy API, but validate and rewrite without duplicate IDs."""
    if unit not in FRAME_SETS:
        raise ValueError(f"Unknown legacy unit: {unit}")
    sets = {}
    for state, names in FRAME_SETS[unit].items():
        paths = [checked_path(f"assets/{unit}_{state}_{name}.png", must_exist=True) for name in names]
        for frame in paths:
            validate_frame(frame)
        sets[f"{state}_frames"] = ["res://" + p.relative_to(PROJECT_ROOT).as_posix() for p in paths]
    path = checked_path(RES_DIR / f"{unit}.tres", must_exist=True)
    result = wired_text(path.read_text(encoding="utf-8-sig"), sets)
    if apply:
        write_text(path, result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.manifest:
        from slice_sheets import load_manifest
        changes = plan_manifest_wiring(load_manifest(args.manifest))
    else:
        changes = {checked_path(RES_DIR / f"{unit}.tres"): process(unit, apply=False) for unit in FRAME_SETS}
    for path, text in changes.items():
        if args.apply:
            write_text(path, text)
        print(f"{'wrote' if args.apply else 'validated'} {path}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        raise SystemExit(f"Wiring rejected: {error}") from error
