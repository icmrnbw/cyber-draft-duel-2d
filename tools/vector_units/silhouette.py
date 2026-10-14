"""Silhouette change between tiers: 1 - IoU of the Lv1 and LvN idle masks
(frames aligned on their shared centre/foot contract). Prints a table.
    python -B tools/vector_units/silhouette.py"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "builds" / "vector-proto"
UNITS = ["enforcer", "trooper", "marksman", "demolitionist", "field_medic",
         "bulwark", "phaseblade", "cryotek", "arcrelay", "nullbreaker"]


def mask(path, size=1024):
    im = Image.open(path).convert("RGBA")
    pad = Image.new("RGBA", (size, size))
    o = (size - im.width) // 2
    pad.paste(im, (o, o))
    return np.asarray(pad.getchannel("A")) > 40


for unit in UNITS:
    m1 = mask(ROOT / unit / "lv1_idle_1.png")
    row = []
    for t in (2, 3):
        mt = mask(ROOT / unit / f"lv{t}_idle_1.png")
        row.append(1 - (m1 & mt).sum() / max(1, (m1 | mt).sum()))
    print(f"{unit:14s} Lv2 {row[0]*100:5.1f}%  Lv3 {row[1]*100:5.1f}%")
