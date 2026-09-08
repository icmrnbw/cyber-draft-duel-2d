"""Regenerates each unit's .tres to add attack_frames/walk_frames/retreat_frames
ext_resource arrays, preserving the existing stat block. Run once after
slice_sheets.py. Not meant to be a permanent pipeline -- a one-off wiring step.
"""
import re
from pathlib import Path

RES_DIR = Path(r"D:\vapecoder\cyber-draft-duel-2d\resources")
ASSETS = "res://assets"

FRAME_SETS = {
    # enforcer's attack_frames were already wired in a previous pass -- only
    # walk/retreat need adding here, handled separately (see main()).
    "enforcer": {
        "walk": ["walk1", "walk2", "walk3", "walk4"],
        "retreat": ["retreat1", "retreat2", "retreat3", "retreat4"],
    },
    "trooper": {
        "attack": ["ready", "fire", "recoil", "settle"],
        "walk": ["walk1", "walk2", "walk3", "walk4"],
        "retreat": ["retreat1", "retreat2", "retreat3", "retreat4"],
    },
    "marksman": {
        "attack": ["ready", "fire", "recoil", "settle"],
        "walk": ["walk1", "walk2", "walk3", "walk4"],
        "retreat": ["retreat1", "retreat2", "retreat3", "retreat4"],
    },
    "demolitionist": {
        "attack": ["ready", "fire", "recoil", "settle"],
        "walk": ["walk1", "walk2", "walk3", "walk4"],
        "retreat": ["retreat1", "retreat2", "retreat3", "retreat4"],
    },
    "field_medic": {
        "attack": ["ready", "reach", "peak", "pullback"],
        "walk": ["walk1", "walk2", "walk3", "walk4"],
        "retreat": ["retreat1", "retreat2", "retreat3", "retreat4"],
    },
}


def process(unit: str) -> None:
    path = RES_DIR / f"{unit}.tres"
    text = path.read_text(encoding="utf-8")

    # Split into [gd_resource]/[ext_resource]* header block and [resource] body.
    m = re.search(r"\n\[resource\]\n", text)
    header, body = text[: m.start()], text[m.end() :]

    sets = FRAME_SETS[unit]
    ext_lines = []
    array_lines = []
    id_counter = 10  # existing ids are 1_unitdef, 2_sprite -- start new ones well clear
    for state, names in sets.items():
        ids = []
        for n in names:
            id_counter += 1
            var_id = f"{id_counter}_{state}_{n}"
            ext_lines.append(
                f'[ext_resource type="Texture2D" path="{ASSETS}/{unit}_{state}_{n}.png" id="{var_id}"]'
            )
            ids.append(f'ExtResource("{var_id}")')
        array_lines.append(f"{state}_frames = Array[Texture2D]([{', '.join(ids)}])")

    # Bump load_steps in the [gd_resource] line to match new ext_resource count.
    existing_ext = len(re.findall(r"\[ext_resource", header))
    new_ext_total = existing_ext + len(ext_lines)
    header = re.sub(
        r"load_steps=\d+",
        f"load_steps={new_ext_total + 1}",
        header,
    )

    header = header.rstrip("\n") + "\n" + "\n".join(ext_lines) + "\n"
    body = body.rstrip("\n") + "\n" + "\n".join(array_lines) + "\n"

    new_text = header + "\n[resource]\n" + body
    path.write_text(new_text, encoding="utf-8")
    print(f"wrote {path}")


def main() -> None:
    for unit in FRAME_SETS:
        process(unit)


if __name__ == "__main__":
    main()
