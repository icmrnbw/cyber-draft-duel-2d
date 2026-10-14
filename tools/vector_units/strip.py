"""Contact strip: python -B tools/vector_units/strip.py <unit> -> builds/vector-proto/<unit>/strip.png"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
unit = sys.argv[1]
root = Path(__file__).resolve().parents[2] / "builds" / "vector-proto" / unit
rows = [(t, s) for t in (1, 2, 3) for s in ("idle", "walk", "attack", "retreat")]
cell = 150
o = Image.new("RGB", (8 * cell + 70, len(rows) * cell), "#1b2130")
d = ImageDraw.Draw(o)
for r, (t, s) in enumerate(rows):
    d.text((4, r * cell + 4), f"Lv{t}\n{s}", fill="white")
    for i in range(8):
        im = Image.open(root / f"lv{t}_{s}_{i + 1}.png").convert("RGBA")
        pad = Image.new("RGBA", (896, 896)); off = (896 - im.width) // 2; pad.paste(im, (off, off))
        im = pad.resize((cell, cell), Image.Resampling.LANCZOS)
        o.paste(im, (70 + i * cell, r * cell), im)
o.save(root / "strip.png")
