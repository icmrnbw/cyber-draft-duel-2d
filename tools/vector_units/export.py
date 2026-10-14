"""Copy rendered vector frames into assets/vector/ and wire every unit resource.

    python -B tools/vector_units/export.py            # check only (sizes, clipping)
    python -B tools/vector_units/export.py --apply    # copy + rewrite resources/*.tres

Wires idle/walk/retreat/attack (8 frames each) for Lv1 and the lv2_/lv3_
overrides, and points each unit's `sprite` (draft/HUD portrait) at its Lv1
idle frame. Old painted frames stay on disk; they are simply no longer
referenced. A record with every output hash goes to
art_sources/vector-2026-10-14/record.json.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from art_safety import checked_path, prepare_output, write_text  # noqa: E402
from wire_frames import wired_text  # noqa: E402
from PIL import Image  # noqa: E402

UNITS = ["enforcer", "trooper", "marksman", "demolitionist", "field_medic",
         "bulwark", "phaseblade", "cryotek", "arcrelay", "nullbreaker"]
STATES = ("idle", "walk", "attack", "retreat")
RECORD = "art_sources/vector-2026-10-14/record.json"


def frames_for(unit, tier, state):
    return [ROOT / "builds" / "vector-proto" / unit / f"lv{tier}_{state}_{i}.png" for i in range(1, 9)]


def check(path):
    with Image.open(path) as im:
        w, h = im.size
        if w < 512 or h < 512 or w % 2 or h % 2 or w != h:
            return f"bad size {im.size}"
        box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        if not box:
            return "empty"
        if box[0] <= 0 or box[1] <= 0 or box[2] >= w or box[3] >= h:
            return f"touches edge {box}"
    return ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    problems, record = [], {"version": 1, "note": "Vector rig renders (tools/vector_units).", "units": {}}
    for unit in UNITS:
        sets = {}
        for tier in (1, 2, 3):
            for state in STATES:
                prop = ("" if tier == 1 else f"lv{tier}_") + f"{state}_frames"
                srcs = frames_for(unit, tier, state)
                for src in srcs:
                    issue = "missing" if not src.exists() else check(src)
                    if issue:
                        problems.append(f"{src.relative_to(ROOT)}: {issue}")
                dests = [ROOT / "assets" / "vector" / f"{unit}_lv{tier}_{state}_{i}.png" for i in range(1, 9)]
                sets[prop] = (srcs, dests)
        record["units"][unit] = sets
    if problems:
        print("\n".join(problems))
        print(f"{len(problems)} problem(s); nothing applied")
        return 1
    if not args.apply:
        print("check passed: 10 units x 12 sets x 8 frames")
        return 0
    out_record = {"version": 1, "note": record["note"], "sets": []}
    for unit, sets in record["units"].items():
        frame_sets = {}
        for prop, (srcs, dests) in sets.items():
            for src, dest in zip(srcs, dests):
                prepare_output(dest).write_bytes(src.read_bytes())
            frame_sets[prop] = ["res://" + d.relative_to(ROOT).as_posix() for d in dests]
            out_record["sets"].append({"unit": unit, "property": prop,
                                       "outputs": [d.relative_to(ROOT).as_posix() for d in dests],
                                       "sha256": [hashlib.sha256(d.read_bytes()).hexdigest() for d in dests]})
        resource = checked_path(f"resources/{unit}.tres", must_exist=True)
        text = wired_text(resource.read_text(encoding="utf-8-sig"), frame_sets)
        portrait = frame_sets["idle_frames"][0]
        text, n = re.subn(r'(\[ext_resource type="Texture2D" path=")[^"]+(" id="2_sprite"\])', rf"\g<1>{portrait}\g<2>", text)
        if n != 1:
            raise ValueError(f"{unit}: expected one 2_sprite resource, found {n}")
        write_text(resource, text)
    write_text(checked_path(RECORD), json.dumps(out_record, indent=1) + "\n")
    print("applied: assets/vector/ + resources wired")
    return 0


if __name__ == "__main__":
    sys.exit(main())
