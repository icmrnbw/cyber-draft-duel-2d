"""Vector rig renderer for consistent unit sprites (2026-10-14).

A character is a list of parts attached to a 2D skeleton. Each part is a
closed shape in its bone's local space (polygon, smooth closed curve, ellipse
or capsule). Poses only change bone angles/offsets, so every frame and tier
reuses identical shapes: nothing drifts between frames, and there are no
generator artifacts.

Shading is soft and glossy rather than flat: a gradient toward the light,
ambient darkening near each part's silhouette, a blurred specular highlight,
optional panel lines, then a dark outline tinted from the part colour.
Emissive parts glow with bloom. Rendering is supersampled (SS x) and reduced
with LANCZOS for antialiasing. Units face screen-right. Output frames are
512x512 RGBA with the feet on FOOT_Y, the same contract as the painted frames.
"""
import math
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TARGET = 512
SS = 4
FOOT_Y = 481
LIGHT = (-0.55, -0.83)   # light comes from upper-left


def shade(color, k):
    """k < 1 darkens, k > 1 lightens (toward white)."""
    r, g, b = color[:3]
    if k <= 1:
        return (int(r * k), int(g * k), int(b * k), 255)
    t = min(1.0, k - 1)
    return (int(r + (255 - r) * t), int(g + (255 - g) * t), int(b + (255 - b) * t), 255)


@dataclass
class Bone:
    name: str
    parent: str | None
    offset: tuple          # joint position in parent space (px, at 512 scale)
    angle: float = 0.0     # degrees, local rotation


@dataclass
class Part:
    bone: str
    kind: str              # "poly", "smooth", "ellipse", "capsule"
    pts: tuple             # poly/smooth: points; ellipse: (cx, cy, rx, ry); capsule: (x0, y0, x1, y1, r)
    color: tuple
    z: int = 0
    glow: bool = False     # emissive: flat bright colour plus bloom
    outline: bool = True
    gloss: float = 0.55    # specular highlight strength 0..1
    depth: float = 1.0     # shading contrast multiplier
    bevel: float = 0.8     # crisp lit-edge / shadow-edge bands (hard-surface look)
    tint: float = 1.0      # facet brightness: >1 faces the light, <1 turned away
    rounding: int = -1     # corner rounding passes (-1: poly 1, smooth 4)
    lines: tuple = ()      # panel lines: tuples of points in local space
    tags: set = field(default_factory=set)


class Rig:
    def __init__(self, bones, parts):
        self.bones = {b.name: b for b in bones}
        self.order = [b.name for b in bones]
        self.parts = parts

    def world(self, pose):
        """Bone name -> (x, y, angle_rad). pose: {bone: angle_deg or (angle_deg, dx, dy)}"""
        out = {}
        for name in self.order:
            bone = self.bones[name]
            spec = pose.get(name, bone.angle)
            ang, dx, dy = (spec, 0.0, 0.0) if not isinstance(spec, tuple) else spec
            ox, oy = bone.offset[0] + dx, bone.offset[1] + dy
            if bone.parent is None:
                out[name] = (ox, oy, math.radians(ang))
            else:
                px, py, pa = out[bone.parent]
                c, s = math.cos(pa), math.sin(pa)
                out[name] = (px + ox * c - oy * s, py + ox * s + oy * c, pa + math.radians(ang))
        return out


_ORIGIN = [0.0]
# Whole-figure scale about the frame's foot point (256, FOOT_Y); units are
# authored at a convenient size and scaled to match the painted roster.
UNIT_SCALE = [1.0]


def _xf(world, bone, x, y):
    bx, by, a = world[bone]
    c, s = math.cos(a), math.sin(a)
    o = _ORIGIN[0]
    k = UNIT_SCALE[0]
    wx, wy = bx + x * c - y * s, by + x * s + y * c
    wx, wy = 256 + (wx - 256) * k, FOOT_Y + (wy - FOOT_Y) * k
    return ((wx + o) * SS, (wy + o) * SS)


def _chaikin(pts, rounds=4):
    for _ in range(rounds):
        out = []
        for i in range(len(pts)):
            (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
            out += [(0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1), (0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1)]
        pts = out
    return pts


def _local_outline(part):
    if part.kind in ("poly", "smooth"):
        rounds = part.rounding if part.rounding >= 0 else (1 if part.kind == "poly" else 4)
        return _chaikin(list(part.pts), rounds) if rounds else list(part.pts)
    if part.kind == "ellipse":
        cx, cy, rx, ry = part.pts
        return [(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in [i * 2 * math.pi / 48 for i in range(48)]]
    if part.kind == "capsule":
        x0, y0, x1, y1, r = part.pts
        ang = math.atan2(y1 - y0, x1 - x0)
        pts = [(x1 + r * math.cos(ang - math.pi / 2 + i * math.pi / 16), y1 + r * math.sin(ang - math.pi / 2 + i * math.pi / 16)) for i in range(17)]
        pts += [(x0 + r * math.cos(ang + math.pi / 2 + i * math.pi / 16), y0 + r * math.sin(ang + math.pi / 2 + i * math.pi / 16)) for i in range(17)]
        return pts
    raise ValueError(part.kind)


def _blend(dst, src_rgba, mask):
    """Alpha-composite src (h,w,4 float 0..1) over dst using an extra 0..1 mask."""
    a = src_rgba[..., 3:4] * mask[..., None]
    dst[..., :3] = src_rgba[..., :3] * a + dst[..., :3] * (1 - a)
    dst[..., 3:4] = a + dst[..., 3:4] * (1 - a)


def render(rig, pose, *, extra=(), canvas_px=TARGET, scale=1.0):
    """Render one frame. extra: parts for this frame only (e.g. VFX).
    canvas_px > 512 grows the canvas symmetrically around the 512 frame
    (same scale, same centre), the contract the game uses for oversized
    action frames, so wind-ups and effects are never clipped."""
    _ORIGIN[0] = (canvas_px - TARGET) / 2
    UNIT_SCALE[0] = scale
    size = canvas_px * SS
    canvas = np.zeros((size, size, 4), np.float32)
    glow = np.zeros((size, size, 4), np.float32)
    world = rig.world(pose)
    lx, ly = LIGHT
    pad = 6 * SS
    for part in sorted(list(rig.parts) + list(extra), key=lambda p: p.z):
        pts = [_xf(world, part.bone, x, y) for x, y in _local_outline(part)]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        x0, y0 = int(max(0, min(xs) - pad)), int(max(0, min(ys) - pad))
        x1, y1 = int(min(size, max(xs) + pad + 1)), int(min(size, max(ys) + pad + 1))
        if x1 - x0 < 2 or y1 - y0 < 2:
            continue
        w, h = x1 - x0, y1 - y0
        local = [(x - x0, y - y0) for x, y in pts]
        mask_img = Image.new("L", (w, h))
        ImageDraw.Draw(mask_img).polygon(local, fill=255)
        mask = np.asarray(mask_img, np.float32) / 255.0
        region = canvas[y0:y1, x0:x1]
        base = np.array(shade(part.color, part.tint)[:3] if not part.glow else part.color[:3], np.float32) / 255.0
        if part.glow:
            src = np.empty((h, w, 4), np.float32)
            src[..., :3] = base
            src[..., 3] = part.color[3] / 255.0 if len(part.color) > 3 else 1.0
            _blend(region, src, mask)
            _blend(glow[y0:y1, x0:x1], src, mask)
            continue
        # Light gradient across the part's own extent.
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        proj = -(xx * lx + yy * ly)
        inside = mask > 0.5
        lo, hi = (proj[inside].min(), proj[inside].max()) if inside.any() else (0.0, 1.0)
        grad = (proj - lo) / max(1.0, hi - lo)          # 1 = lit side
        tone = 0.62 + 0.50 * grad
        # Ambient darkening toward the silhouette (soft roundness).
        depth = np.asarray(mask_img.filter(ImageFilter.GaussianBlur(max(2, min(w, h) * 0.12))), np.float32) / 255.0
        tone = tone * (0.72 + 0.28 * np.clip(depth * 1.6, 0, 1))
        tone = 1.0 + (tone - 1.0) * part.depth
        rgb = np.where(tone[..., None] <= 1, base * tone[..., None],
                       base + (1 - base) * np.clip(tone[..., None] - 1, 0, 1))
        src = np.concatenate([rgb, np.ones((h, w, 1), np.float32)], axis=2)
        _blend(region, src, mask)
        # Bevel: a crisp bright band on edges facing the light and a dark band
        # on edges facing away, like machined armour plates.
        if part.bevel > 0:
            k = max(2, int(min(w, h) * 0.035))
            shifted_away = np.zeros_like(mask)
            dx, dy = int(round(-lx * k)), int(round(-ly * k))
            shifted_away[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)] =                 mask[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)]
            lit_band = np.clip(mask - shifted_away, 0, 1)
            shifted_to = np.zeros_like(mask)
            shifted_to[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)] =                 mask[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)]
            dark_band = np.clip(mask - shifted_to, 0, 1)
            hi_c = np.empty((h, w, 4), np.float32)
            hi_c[..., :3] = base + (1 - base) * 0.55
            hi_c[..., 3] = 1.0
            _blend(region, hi_c, lit_band * part.bevel * 0.85)
            lo_c = np.empty((h, w, 4), np.float32)
            lo_c[..., :3] = base * 0.45
            lo_c[..., 3] = 1.0
            _blend(region, lo_c, dark_band * part.bevel * 0.7)
        # Specular: blurred ellipse toward the light, clipped to the part.
        if part.gloss > 0 and inside.any():
            cy_, cx_ = np.argwhere(inside).mean(axis=0)
            sw, sh = w * 0.26, h * 0.16
            sx, sy = cx_ + lx * w * 0.2, cy_ + ly * h * 0.24
            spec_img = Image.new("L", (w, h))
            ImageDraw.Draw(spec_img).ellipse((sx - sw, sy - sh, sx + sw, sy + sh), fill=255)
            spec = np.asarray(spec_img.filter(ImageFilter.GaussianBlur(max(2, min(w, h) * 0.07))), np.float32) / 255.0
            white = np.ones((h, w, 4), np.float32)
            _blend(region, white, spec * mask * part.gloss * 0.75)
        dark = np.array(shade(part.color, 0.32)[:3], np.float32) / 255.0
        if part.lines:
            line_img = Image.new("L", (w, h))
            d = ImageDraw.Draw(line_img)
            for line in part.lines:
                lp = [_xf(world, part.bone, x, y) for x, y in line]
                d.line([(x - x0, y - y0) for x, y in lp], fill=255, width=int(1.6 * SS), joint="curve")
            lm = np.asarray(line_img, np.float32) / 255.0 * mask
            src = np.empty((h, w, 4), np.float32)
            src[..., :3] = dark
            src[..., 3] = 0.8
            _blend(region, src, lm)
        if part.outline:
            grown = np.asarray(mask_img.filter(ImageFilter.MaxFilter(int(2.5 * SS) | 1)), np.float32) / 255.0
            edge = np.clip(grown - mask, 0, 1)
            src = np.empty((h, w, 4), np.float32)
            src[..., :3] = np.array((20, 22, 32), np.float32) / 255.0 * 0.5 + dark * 0.5
            src[..., 3] = 1.0
            _blend(region, src, edge)
    img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGBA")
    out = img.resize((canvas_px, canvas_px), Image.Resampling.LANCZOS)
    g = Image.fromarray((np.clip(glow, 0, 1) * 255).astype(np.uint8), "RGBA").resize((canvas_px, canvas_px), Image.Resampling.BILINEAR)
    bloom = g.filter(ImageFilter.GaussianBlur(7))
    bloom.putalpha(bloom.getchannel("A").point(lambda a: int(a * 0.8)))
    out = Image.alpha_composite(bloom, out)
    halo = g.filter(ImageFilter.GaussianBlur(2))
    halo.putalpha(halo.getchannel("A").point(lambda a: int(a * 0.6)))
    return Image.alpha_composite(out, halo)


def ground(frame, foot_px=None):
    """Shift a frame so its feet sit on FOOT_Y (in 512-frame coordinates,
    offset for larger canvases). foot_px: the feet's current row if known
    (effects below the feet would otherwise fool the bbox)."""
    off = (frame.height - TARGET) // 2
    if foot_px is None:
        box = frame.getchannel("A").point(lambda a: 255 if a > 120 else 0).getbbox()
        if not box:
            return frame
        foot_px = box[3]
    out = Image.new("RGBA", frame.size)
    out.paste(frame, (0, FOOT_Y + off - int(round(foot_px))))
    return out


def foot_row(rig, pose, foot_bones, sole=30, canvas_px=TARGET):
    """Lowest sole row of the given foot bones for a pose, in canvas pixels."""
    world = rig.world(pose)
    off = (canvas_px - TARGET) / 2
    return max(world[b][1] + sole for b in foot_bones) + off


# ---------------------------------------------------------------- animation
def _norm(v):
    return (float(v), 0.0, 0.0) if not isinstance(v, tuple) else tuple(float(x) for x in v)


def ease(t):
    return t * t * (3 - 2 * t)


def lerp_pose(a, b, t):
    out = {}
    for k in set(a) | set(b):
        va, vb = _norm(a.get(k, b.get(k, 0.0))), _norm(b.get(k, a.get(k, 0.0)))
        out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
    return out


def keyframes(keys, n, loop=True):
    """keys: [(t, pose)] with t in [0, 1). Returns n eased poses; loops wrap
    from the last key back to the first."""
    keys = sorted(keys, key=lambda k: k[0])
    if loop:
        keys = keys + [(1.0, keys[0][1])]
    out = []
    for i in range(n):
        t = i / n if loop else i / max(1, n - 1)
        for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                out.append(lerp_pose(p0, p1, ease((t - t0) / max(1e-6, t1 - t0))))
                break
        else:
            out.append(dict(keys[-1][1]))
    return out


def lag(poses, bones, frames=1):
    """Secondary motion: listed bones take their values from `frames` earlier
    (follow-through on pads, capes, heads)."""
    n = len(poses)
    return [{**p, **{b: poses[(i - frames) % n].get(b, p.get(b, 0.0)) for b in bones}} for i, p in enumerate(poses)]
