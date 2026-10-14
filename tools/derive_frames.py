"""Code-derived stand-in animation frames for sets that have no generated art.

These are NOT generated art. They reuse a unit's own reviewed frames so the
identity is exact, and add motion with image transforms:

- walk / retreat from idle: the legs below the hip line scissor (front and back
  halves shear in opposite directions), the body bobs on contact frames and
  leans forward (walk) or back (retreat).
- retreat from an existing walk set: the walk cycle reversed with a backward lean.
- attack from idle: ready / wind-up (lean back, crouch) / strike (lunge forward,
  stretch, a tier-coloured flash at the weapon side) / recover.
- tier recolor: an existing lower-tier set with its cyan energy shifted to the
  Lv3 orange.

Output frames are 512x512 RGBA with the idle's foot line, so they drop into the
same resolvers. A record of every derived set (sources and method) is written to
art_sources/derived-2026-10-14/derived_record.json; replace a derived set by
slicing real art through slice_sheets.py, which overwrites the same paths
(after its usual content-hash backup).

    python -B tools/derive_frames.py --preview   # contact sheets only, under builds/
    python -B tools/derive_frames.py --apply     # write frames and wire resources
"""
import argparse
import colorsys
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from art_safety import PROJECT_ROOT, checked_path, prepare_output, write_text
from wire_frames import wired_text

ASSETS = PROJECT_ROOT / "assets"
TARGET = 512
IDLE = ["breathe1", "breathe2", "breathe3", "breathe4"]
TIER_PREFIX = {1: "", 2: "_lv2", 3: "_lv3"}
TIER_PROP = {1: "", 2: "lv2_", 3: "lv3_"}
ENERGY = {1: (90, 225, 255), 2: (90, 225, 255), 3: (255, 140, 50)}
RECORD = "art_sources/derived-2026-10-14/derived_record.json"

# (unit, tier, state, method, frame names, extra). Frame names follow the
# existing convention for each unit so a later real import lands on them.
ATTACK_NAMES = ["ready", "windup", "strike", "recover"]
WALK_NAMES = ["walk1", "walk2", "walk3", "walk4"]
RETREAT_NAMES = ["retreat1", "retreat2", "retreat3", "retreat4"]
PLAN = (
    [("cryotek", t, "attack", "attack_from_idle", ATTACK_NAMES, {"flash": (150, 235, 255)}) for t in (1, 2, 3)]
    + [("cryotek", t, "walk", "walk_from_idle", WALK_NAMES, {}) for t in (1, 2, 3)]
    + [("cryotek", t, "retreat", "walk_from_idle", RETREAT_NAMES, {"backward": True}) for t in (1, 2, 3)]
    # Phaseblade's blade and ArcRelay's staff hang through the leg region, so
    # the leg scissor tore/doubled them: those two get bob, lean and sway only.
    + [(u, t, "walk", "walk_from_idle", WALK_NAMES, {"scissor": False}) for u in ("arcrelay", "phaseblade") for t in (1, 2, 3)]
    + [(u, t, "retreat", "walk_from_idle", RETREAT_NAMES, {"backward": True, "scissor": False})
       for u in ("arcrelay", "phaseblade") for t in (1, 2, 3)]
    + [("nullbreaker", t, "retreat", "retreat_from_walk", RETREAT_NAMES, {}) for t in (1, 2, 3)]
    + [("nullbreaker", 3, "attack", "tier_recolor", ["ready", "fire", "recoil", "settle"], {"from_tier": 2})]
)


def file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def stand_in_outputs():
    """Runtime paths still holding this tool's stand-ins (bytes unchanged since
    it wrote them). Used by the art audit to report placeholders."""
    record_path = PROJECT_ROOT / RECORD
    if not record_path.exists():
        return set()
    live = set()
    for item in json.loads(record_path.read_text(encoding="utf-8"))["sets"]:
        for out, digest in zip(item["outputs"], item.get("sha256", [])):
            path = PROJECT_ROOT / out
            if path.exists() and file_hash(path) == digest:
                live.add(out)
    return live


def load(path):
    with Image.open(checked_path(path, must_exist=True)) as image:
        return image.convert("RGBA")


def bbox(image):
    return image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()


def frame_paths(unit, tier, state, names):
    return [ASSETS / f"{unit}{TIER_PREFIX[tier]}_{state}_{name}.png" for name in names]


def transform_about_feet(image, *, lean_deg=0.0, sx=1.0, sy=1.0, dx=0.0, dy=0.0):
    """Lean/scale/shift the whole figure about its foot point, keeping 512px."""
    x0, y0, x1, y1 = bbox(image)
    fx, fy = (x0 + x1) / 2, y1
    a = math.radians(lean_deg)
    # Output->input affine for PIL: p_in = M^-1 (p_out - foot - d) + foot.
    cos, sin = math.cos(a), math.sin(a)
    inv = np.linalg.inv(np.array([[cos * sx, -sin * sy], [sin * sx, cos * sy]]))
    ox, oy = fx + dx, fy + dy
    coeffs = (inv[0, 0], inv[0, 1], fx - inv[0, 0] * ox - inv[0, 1] * oy,
              inv[1, 0], inv[1, 1], fy - inv[1, 0] * ox - inv[1, 1] * oy)
    return image.transform(image.size, Image.Transform.AFFINE, coeffs, Image.Resampling.BICUBIC)


def scissor_legs(image, amount):
    """Shear the legs below the hip in opposite directions for the front and
    back halves; amount is the horizontal foot offset in pixels."""
    x0, y0, x1, y1 = bbox(image)
    hip = int(y0 + (y1 - y0) * 0.70)
    cx = (x0 + x1) / 2
    src = np.array(image)
    out = src.copy()
    out[hip:] = 0
    for y in range(hip, image.height):
        t = (y - hip) / max(1, y1 - hip)
        shift = int(round(amount * t))
        row = src[y]
        front, back = row.copy(), row.copy()
        front[: int(cx)] = 0
        back[int(cx):] = 0
        out[y] = np.maximum(out[y], np.roll(front, shift, axis=0))
        out[y] = np.maximum(out[y], np.roll(back, -shift, axis=0))
    return Image.fromarray(out)


def walk_from_idle(unit, tier, names, extra):
    idle = [load(ASSETS / f"{unit}{TIER_PREFIX[tier]}_idle_{n}.png") for n in IDLE]
    h = bbox(idle[0])[3] - bbox(idle[0])[1]
    stride = h * 0.075
    backward = extra.get("backward", False)
    lean = -3.0 if backward else 4.0
    # contact / passing (raised) / contact (other leg) / passing
    poses = [(stride, 0.0), (0.0, -h * 0.025), (-stride, 0.0), (0.0, -h * 0.025)]
    if backward:
        poses = poses[::-1]
    frames = []
    use_scissor = extra.get("scissor", True)
    for i, (scissor, lift) in enumerate(poses):
        if use_scissor:
            base = scissor_legs(idle[i], scissor) if scissor else idle[i]
            squash = 0.985 if scissor else 1.0
            frames.append(transform_about_feet(base, lean_deg=lean, sx=1 / squash, sy=squash, dy=lift))
        else:
            # Whole-figure step: stronger bob, a rocking lean and a small sway
            # stand in for leg motion without cutting through the weapon.
            rock = 2.5 if scissor > 0 else (-2.5 if scissor < 0 else 0.0)
            squash = 0.97 if scissor else 1.0
            frames.append(transform_about_feet(idle[i], lean_deg=lean + rock, sx=1 / squash, sy=squash,
                                               dx=(scissor * 0.15), dy=lift * 1.6))
    return frames, [f"assets/{unit}{TIER_PREFIX[tier]}_idle_{n}.png" for n in IDLE]


def retreat_from_walk(unit, tier, names, extra):
    sources = sorted(ASSETS.glob(f"{unit}{TIER_PREFIX[tier]}_walk_walk*.png"))
    if len(sources) != 4:
        raise ValueError(f"{unit} Lv{tier} needs four walk frames to derive a retreat")
    walk = [load(p) for p in sources][::-1]
    return ([transform_about_feet(f, lean_deg=-4.0) for f in walk],
            [str(p.relative_to(PROJECT_ROOT)).replace("\\", "/") for p in sources])


def muzzle(image):
    """Rightmost opaque column (the weapon tip, since units face right) and the
    median height of the art in that column."""
    alpha = np.array(image.getchannel("A")) > 8
    cols = np.where(alpha.any(axis=0))[0]
    tip = int(cols.max())
    ys = np.where(alpha[:, max(0, tip - 12): tip + 1].any(axis=1))[0]
    return tip, int(np.median(ys))


def flash(image, color, side_x, y):
    layer = Image.new("RGBA", image.size)
    draw = ImageDraw.Draw(layer)
    for r, alpha in ((36, 120), (24, 200), (13, 255)):
        draw.ellipse((side_x - r * 1.6, y - r, side_x + r * 1.6, y + r), fill=color + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(4))
    # A white-hot core keeps the flash readable at phone scale.
    core = Image.new("RGBA", image.size)
    ImageDraw.Draw(core).ellipse((side_x - 9, y - 6, side_x + 9, y + 6), fill=(255, 255, 255, 255))
    layer = Image.alpha_composite(layer, core.filter(ImageFilter.GaussianBlur(2)))
    return Image.alpha_composite(image, layer)


def attack_from_idle(unit, tier, names, extra):
    idle = load(ASSETS / f"{unit}{TIER_PREFIX[tier]}_idle_breathe1.png")
    x0, y0, x1, y1 = bbox(idle)
    h = y1 - y0
    ready = idle
    windup = transform_about_feet(idle, lean_deg=-5.0, sx=1.02, sy=0.97, dx=-h * 0.02)
    strike = transform_about_feet(idle, lean_deg=8.0, sx=0.97, sy=1.04, dx=h * 0.06)
    overflow = bbox(strike)[2] - (TARGET - 8)
    if overflow > 0:
        strike = transform_about_feet(idle, lean_deg=8.0, sx=0.97, sy=1.04, dx=h * 0.06 - overflow)
    tip_x, tip_y = muzzle(strike)
    color = extra.get("flash") if tier < 3 else ENERGY[3]
    # Keep the whole glow (radius ~42 px with blur) inside the 512 frame.
    strike = flash(strike, color or ENERGY[tier], min(TARGET - 60, tip_x + 8), tip_y)
    recover = transform_about_feet(idle, lean_deg=2.5, dx=h * 0.015)
    return [ready, windup, strike, recover], [f"assets/{unit}{TIER_PREFIX[tier]}_idle_breathe1.png"]


def recolor_to_orange(image):
    """Shift saturated cyan energy (hue ~170-215 deg) to the Lv3 orange."""
    arr = np.array(image).astype(np.float32) / 255.0
    rgb = arr[..., :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    out = arr.copy()
    ys, xs = np.where((sat > 0.35) & (mx > 0.35) & (arr[..., 3] > 0.03))
    for y, x in zip(ys, xs):
        hh, ss, vv = colorsys.rgb_to_hsv(*rgb[y, x])
        if 0.47 <= hh <= 0.60:
            out[y, x, :3] = colorsys.hsv_to_rgb(0.065, min(1.0, ss * 1.05), vv)
    return Image.fromarray((out * 255).round().astype(np.uint8))


def color_stats(image):
    arr = np.array(image).astype(np.float32)
    mask = arr[..., 3] > 128
    px = arr[mask][:, :3]
    return px.mean(axis=0), px.std(axis=0) + 1e-3


def tier_recolor(unit, tier, names, extra):
    """Lower-tier attack -> this tier: cyan energy becomes the Lv3 orange.
    (A whole-figure colour transfer from the idle pair turned the armour
    bronze, unlike the dark Lv3 idle, so only the energy is recoloured.)"""
    from_tier = extra["from_tier"]
    sources = [ASSETS / f"{unit}{TIER_PREFIX[from_tier]}_attack_{n}.png" for n in names]
    return ([recolor_to_orange(load(p)) for p in sources],
            [str(p.relative_to(PROJECT_ROOT)).replace("\\", "/") for p in sources])


METHODS = {"walk_from_idle": walk_from_idle, "retreat_from_walk": retreat_from_walk,
           "attack_from_idle": attack_from_idle, "tier_recolor": tier_recolor}


def contact(frames, title):
    sheet = Image.new("RGB", (TARGET * 4 // 2, TARGET // 2 + 30), "#252b37")
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 6), title, fill="white")
    for i, frame in enumerate(frames):
        small = frame.resize((TARGET // 2, TARGET // 2), Image.Resampling.LANCZOS)
        sheet.paste(small, (i * TARGET // 2, 28), small)
    return sheet


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--only", default="", help="unit_lvN_state, e.g. nullbreaker_lv3_attack")
    args = parser.parse_args()
    # A frame may be regenerated only while its bytes still match the hash this
    # tool recorded when it wrote it. Once real art is imported over a
    # stand-in (tools/import_incoming.py, slice_sheets.py) the hash differs and
    # the whole set is skipped, so a rerun can never overwrite imported art.
    record_path = checked_path(RECORD)
    previous = json.loads(record_path.read_text(encoding="utf-8")) if record_path.exists() else {"sets": []}
    own_hashes = {o: h for item in previous["sets"] for o, h in zip(item["outputs"], item.get("sha256", []))}
    record, rewrites = {"version": 1, "note": "Code-derived stand-ins, not generated art.", "sets": []}, {}
    preview_dir = checked_path("builds/art-preview/derived-20261014")
    for unit, tier, state, method, names, extra in PLAN:
        if args.only and args.only != f"{unit}_lv{tier}_{state}":
            continue
        frames, sources = METHODS[method](unit, tier, names, extra)
        outputs = frame_paths(unit, tier, state, names)
        prop = f"{TIER_PROP[tier]}{state}_frames"
        contact(frames, f"{unit} Lv{tier} {state} ({method})").save(
            prepare_output(preview_dir / f"{unit}_lv{tier}_{state}.png"))
        rel = [str(p.relative_to(PROJECT_ROOT)).replace("\\", "/") for p in outputs]
        if args.apply:
            replaced = [r for r, path in zip(rel, outputs)
                        if path.exists() and own_hashes.get(r) != file_hash(path)]
            if replaced:
                print(f"skip {unit} Lv{tier} {state}: {len(replaced)} frame(s) are not this tool's output (real art?)")
                continue
            for frame, path in zip(frames, outputs):
                frame.save(prepare_output(path))
        record["sets"].append({"unit": unit, "tier": tier, "property": prop, "method": method,
                               "sources": sources, "outputs": rel,
                               "sha256": [file_hash(path) for path in outputs] if args.apply else []})
        if args.apply:
            resource = PROJECT_ROOT / "resources" / f"{unit}.tres"
            rewrites.setdefault(resource, {})[prop] = ["res://" + p.relative_to(PROJECT_ROOT).as_posix() for p in outputs]
    if args.apply:
        for resource, sets in rewrites.items():
            write_text(resource, wired_text(resource.read_text(encoding="utf-8-sig"), sets))
        # --only regenerates one set; keep every other set's entry.
        done = {(item["unit"], item["tier"], item["property"]) for item in record["sets"]}
        record["sets"] = [item for item in previous["sets"]
                          if (item["unit"], item["tier"], item["property"]) not in done] + record["sets"]
        write_text(record_path, json.dumps(record, indent=2) + "\n")
    print(f"{'applied' if args.apply else 'previewed'} {len(record['sets'])} derived sets; contact sheets in {preview_dir}")


if __name__ == "__main__":
    main()
