"""Slices 2x2 Meshy spritesheets into 4 individual frame PNGs, normalized to
1024x1024 with the character bbox padded and centered -- see the "why" in
match_controller.gd's comments: mismatched texture resolution between units
silently breaks relative on-screen scale, so every sliced frame must come out
the same canvas size as the rest of the roster's art regardless of source
sheet layout.
"""
import sys
from pathlib import Path
from PIL import Image

STAGING = Path(r"D:\vapecoder\cyber-draft-duel\art_staging")
ASSETS = Path(r"D:\vapecoder\cyber-draft-duel-2d\assets")

TARGET = 512
PAD_FRAC = 0.06
INSET = 14
BG_THRESHOLD = 230

PANEL_NAMES = {
    "idle": (0, 0),
    "b": (1, 0),
    "c": (0, 1),
    "d": (1, 1),
}


def slice_sheet(sheet_path: Path, out_prefix: str, frame_names: list[str]) -> None:
    img = Image.open(sheet_path).convert("RGBA")
    w, h = img.size
    half_w, half_h = w // 2, h // 2
    grid = [
        (0 + INSET, 0 + INSET, half_w - INSET, half_h - INSET),
        (half_w + INSET, 0 + INSET, w - INSET, half_h - INSET),
        (0 + INSET, half_h + INSET, half_w - INSET, h - INSET),
        (half_w + INSET, half_h + INSET, w - INSET, h - INSET),
    ]
    for box, name in zip(grid, frame_names):
        frame = img.crop(box).convert("RGBA")
        px = frame.load()
        fw, fh = frame.size
        for y in range(fh):
            for x in range(fw):
                r, g, b, a = px[x, y]
                if r > BG_THRESHOLD and g > BG_THRESHOLD and b > BG_THRESHOLD:
                    px[x, y] = (r, g, b, 0)

        bbox = frame.getbbox()
        if bbox is None:
            print(f"  WARNING: {name} frame is fully transparent, skipping")
            continue
        bx0, by0, bx1, by1 = bbox
        bw, bh = bx1 - bx0, by1 - by0
        pad = int(max(bw, bh) * PAD_FRAC)
        bx0 = max(0, bx0 - pad)
        by0 = max(0, by0 - pad)
        bx1 = min(fw, bx1 + pad)
        by1 = min(fh, by1 + pad)
        char = frame.crop((bx0, by0, bx1, by1))
        cw, ch = char.size
        side = max(cw, ch)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(char, ((side - cw) // 2, (side - ch) // 2), char)
        final = square.resize((TARGET, TARGET), Image.LANCZOS)

        out = ASSETS / f"{out_prefix}_{name}.png"
        final.save(out)
        print(f"  saved {out.name}")


IDLE_FRAME_NAMES = ["breathe1", "breathe2", "breathe3", "breathe4"]

UNITS = {
    "enforcer": {
        "attack": ("enforcer_final_attack", ["idle", "windup", "strike", "recover"]),
        "walk": ("enforcer_walk_sideview", ["walk1", "walk2", "walk3", "walk4"]),
        "retreat": ("enforcer_final_retreat", ["retreat1", "retreat2", "retreat3", "retreat4"]),
        "idle": ("enforcer_idle_breathe", IDLE_FRAME_NAMES),
    },
    "trooper": {
        "attack": ("trooper_final_attack", ["ready", "fire", "recoil", "settle"]),
        "walk": ("trooper_final_walk", ["walk1", "walk2", "walk3", "walk4"]),
        "retreat": ("trooper_final_retreat", ["retreat1", "retreat2", "retreat3", "retreat4"]),
        "idle": ("trooper_idle_breathe", IDLE_FRAME_NAMES),
    },
    "marksman": {
        "attack": ("marksman_final_attack", ["ready", "fire", "recoil", "settle"]),
        "walk": ("marksman_final_walk", ["walk1", "walk2", "walk3", "walk4"]),
        "retreat": ("marksman_final_retreat", ["retreat1", "retreat2", "retreat3", "retreat4"]),
        "idle": ("marksman_idle_breathe", IDLE_FRAME_NAMES),
    },
    "demolitionist": {
        "attack": ("demolitionist_final_attack", ["ready", "fire", "recoil", "settle"]),
        "walk": ("demolitionist_final_walk", ["walk1", "walk2", "walk3", "walk4"]),
        "retreat": ("demolitionist_final_retreat", ["retreat1", "retreat2", "retreat3", "retreat4"]),
        "idle": ("demolitionist_idle_breathe", IDLE_FRAME_NAMES),
    },
    "field_medic": {
        "attack": ("field_medic_final_attack", ["ready", "reach", "peak", "pullback"]),
        "walk": ("field_medic_final_walk", ["walk1", "walk2", "walk3", "walk4"]),
        "retreat": ("field_medic_final_retreat_v2", ["retreat1", "retreat2", "retreat3", "retreat4"]),
        "idle": ("field_medic_idle_breathe", IDLE_FRAME_NAMES),
    },
}

# Lv2/Lv3 idle-breathe sheets (2026-09-06) -- follow the same "unit_lvN_state"
# output-prefix convention as the lv2/lv3 attack/walk/retreat sheets, which
# were sliced via one-off slice_sheet() calls rather than a UNITS entry
# (there's no clean way to express "3 tiers" in this unit->state->sheet
# shape without restructuring every existing entry). Kept as a lookup here
# instead of a scattered one-off script so a future re-slice is a single
# `python slice_sheets.py --idle-tiers` away.
IDLE_TIERS = {
    f"{unit}_lv{tier}": (f"{unit}_lv{tier}_idle_breathe", IDLE_FRAME_NAMES)
    for unit in UNITS
    for tier in (2, 3)
}


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--idle-tiers":
        for out_prefix, (sheet_name, frame_names) in IDLE_TIERS.items():
            sheet_path = STAGING / sheet_name / "ref_0.png"
            if not sheet_path.exists():
                print(f"MISSING: {sheet_path}")
                continue
            print(f"{out_prefix}  <- {sheet_name}")
            slice_sheet(sheet_path, f"{out_prefix}_idle", frame_names)
        return

    only = sys.argv[1] if len(sys.argv) > 1 else None
    for unit, states in UNITS.items():
        if only and unit != only:
            continue
        for state, (sheet_name, frame_names) in states.items():
            sheet_path = STAGING / sheet_name / "ref_0.png"
            if not sheet_path.exists():
                print(f"MISSING: {sheet_path}")
                continue
            print(f"{unit} / {state}  <- {sheet_name}")
            slice_sheet(sheet_path, f"{unit}_{state}", frame_names)


if __name__ == "__main__":
    main()
