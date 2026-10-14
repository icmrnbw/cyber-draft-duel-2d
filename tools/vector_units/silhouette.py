"""Silhouette change between tiers: 1 - IoU of the Lv1 and LvN idle masks
(frames aligned on their shared centre/foot contract). Prints a table.
    python -B tools/vector_units/silhouette.py"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "builds" / "vector-proto"
UNITS = ["enforcer", "trooper", "marksman", "demolitionist", "field_medic",
         "bulwark", "phaseblade", "cryotek", "arcrelay", "nullbreaker"]


GROWTH = {1: 1.0, 2: 1.07, 3: 1.14}
FOOT = 481


def mask(path, size=1024, unscale=1.0):
    im = Image.open(path).convert("RGBA")
    if unscale != 1.0:   # undo tier growth about the foot point
        c = im.width / 2
        foot = FOOT + (im.height - 512) / 2
        w = int(round(im.width / unscale)) // 2 * 2
        im = im.resize((w, w), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (im.width if w > 0 else 1, im.height))
        shifted = Image.new("RGBA", (max(w, 1), max(w, 1)))
        dy = int(round(foot - foot / unscale - (c - c / unscale)))
        shifted.paste(im, (0, dy))
        im = shifted
    pad = Image.new("RGBA", (size, size))
    o = (size - im.width) // 2
    pad.paste(im, (o, o))
    return np.asarray(pad.getchannel("A")) > 40


for unit in UNITS:
    m1 = mask(ROOT / unit / "lv1_idle_1.png")
    row = []
    for t in (2, 3):
        mt = mask(ROOT / unit / f"lv{t}_idle_1.png")
        mn = mask(ROOT / unit / f"lv{t}_idle_1.png", unscale=GROWTH[t])
        row.append((1 - (m1 & mt).sum() / max(1, (m1 | mt).sum()), 1 - (m1 & mn).sum() / max(1, (m1 | mn).sum())))
    print(f"{unit:14s} Lv2 {row[0][0]*100:5.1f}% (gear only {row[0][1]*100:5.1f}%)  "
          f"Lv3 {row[1][0]*100:5.1f}% (gear only {row[1][1]*100:5.1f}%)")
