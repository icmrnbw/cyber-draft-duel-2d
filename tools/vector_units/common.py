"""Shared side-view rig, animation styles and output pipeline for vector units.

A unit module provides:
    NAME, parts_for(tier) -> [Part], STYLE (attack style name),
    MUZZLE (x, y) in the "weapon" bone, optional HOLD (two-handed grip pose),
    optional attack_extra(tier, frame) for unit-specific VFX.
and calls common.build(module).

Skeleton (faces screen-right, 512 px frame, hip at ~(236, 318)):
    hip > torso > {pack, head, uarm_b > farm_b, uarm_f > farm_f > weapon,
                   shield (on farm_b)}
    hip > thigh_b > shin_b > foot_b ; hip > thigh_f > shin_f > foot_f
Leg/arm parts are authored pointing down (+y) from their joint.
"""
import math
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from vector_art import Bone, Part, Rig, ground, keyframes, lag, render  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
CYAN = (110, 236, 255, 255)
ORANGE = (255, 146, 54, 255)
WHITE = (255, 255, 255, 255)


def accent(tier):
    return ORANGE if tier == 3 else CYAN


BACK_UARM, BACK_FARM = 54, 54


def bones(hip=(236, 318), thigh=60, shin=56, torso_h=150, shoulder=(26, -112), back_shoulder=(4, -110),
          uarm=46, farm=44, pack=(-56, -80)):
    return [
        Bone("hip", None, hip),
        Bone("torso", "hip", (0, 0)),
        Bone("pack", "torso", pack),
        Bone("head", "torso", (6, -torso_h - 12)),
        Bone("uarm_b", "torso", back_shoulder), Bone("farm_b", "uarm_b", (0, BACK_UARM)),
        Bone("shield", "farm_b", (0, BACK_FARM)),
        Bone("thigh_b", "hip", (-14, 12)), Bone("shin_b", "thigh_b", (0, thigh)), Bone("foot_b", "shin_b", (0, shin)),
        Bone("thigh_f", "hip", (16, 12)), Bone("shin_f", "thigh_f", (0, thigh)), Bone("foot_f", "shin_f", (0, shin)),
        Bone("uarm_f", "torso", shoulder), Bone("farm_f", "uarm_f", (0, uarm)),
        Bone("weapon", "farm_f", (0, farm)),
    ]


def P(bone, pts, color, z, **kw):
    return Part(bone, "poly", tuple(pts), color, z, **kw)


def S(bone, pts, color, z, **kw):
    return Part(bone, "smooth", tuple(pts), color, z, **kw)


def E(bone, cx, cy, rx, ry, color, z, **kw):
    return Part(bone, "ellipse", (cx, cy, rx, ry), color, z, **kw)


def C(bone, x0, y0, x1, y1, r, color, z, **kw):
    return Part(bone, "capsule", (x0, y0, x1, y1, r), color, z, **kw)


def G(bone, pts, color, z):
    return Part(bone, "poly", tuple(pts), color, z, glow=True)


def standard_limbs(armor, under, boot, z_back=-20, z_front=10, z_arm_b=-12, z_arm_f=32, bulk=1.0):
    """Faceted legs and arms shared by humanoid units."""
    out = []
    for side, z in (("b", z_back), ("f", z_front)):
        out += [
            C(f"thigh_{side}", 0, 0, 0, 58, 22 * bulk, under, z, gloss=0.2, bevel=0.3),
            P(f"shin_{side}", ((-22 * bulk, -4), (6, -8), (10, 52), (-18 * bulk, 54)), armor, z + 1, tint=1.06),
            P(f"shin_{side}", ((6, -8), (22 * bulk, -2), (24 * bulk, 48), (10, 52)), armor, z + 1, tint=0.8),
            S(f"shin_{side}", ((-20, -20), (16, -24), (24, -6), (4, 10), (-20, 4)), armor, z + 2, tint=1.12),
            P(f"foot_{side}", ((-26, -6), (22, -8), (40, 16), (38, 24), (-30, 24), (-32, 8)), boot, z + 3),
        ]
    for side, z in (("b", z_arm_b), ("f", z_arm_f)):
        u, f = (BACK_UARM, BACK_FARM) if side == "b" else (46, 44)
        out += [
            E(f"uarm_{side}", 0, -2, 21 * bulk, 20 * bulk, armor, z + 2, tint=1.05),
            C(f"uarm_{side}", 0, 0, 0, u - 2, 15 * bulk, under, z, gloss=0.2),
            P(f"farm_{side}", ((-15 * bulk, -2), (15 * bulk, -4), (13 * bulk, f - 4), (-13 * bulk, f - 2)), armor, z + 1, tint=0.95),
            E(f"farm_{side}", 0, f, 13, 12, boot, z + 3),
        ]
    return out


# ----------------------------------------------------------------- poses
BASE = {"torso": 0.0, "hip": (0, 0, 0), "uarm_f": 4, "farm_f": -84, "uarm_b": -22, "farm_b": -66,
        "thigh_f": -10, "shin_f": 6, "thigh_b": 12, "shin_b": 8, "weapon": 0.0, "shield": 0.0}


def finish(poses, hold_level=True):
    out = []
    for p in poses:
        q = {k: v for k, v in p.items()}
        val = lambda k: q.get(k, 0.0)[0] if isinstance(q.get(k, 0.0), tuple) else q.get(k, 0.0)  # noqa: E731
        for side in "bf":
            q[f"foot_{side}"] = -(val(f"thigh_{side}") + val(f"shin_{side}"))
        if hold_level:
            q["weapon"] = -(val("torso") + val("uarm_f") + val("farm_f")) + val("weapon_tilt")
        # Shields stay upright whatever the arm does.
        q["shield"] = -(val("torso") + val("uarm_b") + val("farm_b")) + val("shield_tilt")
        q.pop("shield_tilt", None)
        q.pop("weapon_tilt", None)
        out.append(q)
    return out


def idle_poses(base):
    return keyframes([(0.0, {**base, "hip": (0, 0, 0)}),
                      (0.5, {**base, "hip": (0, 0, 4), "torso": base.get("torso", 0) + 1.2,
                             "head": (1.5, 0, 0), "pack": (0, 0, 1)})], 8)


def walk_poses(base, lean=5, stride=1.0, backward=False):
    k = stride
    keys = [
        (0.0, {**base, "torso": lean, "hip": (0, 0, 0), "thigh_f": -26 * k, "shin_f": 12, "thigh_b": 24 * k, "shin_b": 18,
               "uarm_b": base["uarm_b"] - 10}),
        (0.25, {**base, "torso": lean, "hip": (0, 0, -8), "thigh_f": -4, "shin_f": 6, "thigh_b": -14 * k, "shin_b": 60}),
        (0.5, {**base, "torso": lean, "hip": (0, 0, 0), "thigh_f": 24 * k, "shin_f": 18, "thigh_b": -26 * k, "shin_b": 12,
               "uarm_b": base["uarm_b"] + 10}),
        (0.75, {**base, "torso": lean, "hip": (0, 0, -8), "thigh_f": -14 * k, "shin_f": 60, "thigh_b": -4, "shin_b": 6}),
    ]
    if backward:
        keys = [(t, p) for t, p in zip([0.0, 0.25, 0.5, 0.75], [k_[1] for k_ in keys[::-1]])]
    poses = keyframes(keys, 8)
    return lag(poses, ("head", "pack"), 1)


def attack_poses(style, base):
    """Eight-frame attack keyed by style. Frame 0 is ready, the hit/fire frame
    is where VFX go (see FIRE_FRAMES)."""
    b = dict(base)
    if style in ("shoot", "burst", "spray", "rail", "snipe", "chain", "heal", "lob"):
        aim_tilt = {"lob": -28, "chain": -10, "heal": -6}.get(style, 0)
        charge = style in ("rail", "snipe")
        keys = [
            (0.0, {**b, "hip": (0, 0, 2), "weapon_tilt": 0}),
            (1 / 7, {**b, "hip": (0, -4, 4), "torso": -3, "weapon_tilt": aim_tilt}),
            (2 / 7, {**b, "hip": (0, -6, 6 if charge else 4), "torso": -5, "weapon_tilt": aim_tilt}),
            (3 / 7, {**b, "hip": (0, -16, 2), "torso": -9, "weapon_tilt": aim_tilt - 8, "uarm_f": b["uarm_f"] + 8}),
            (4 / 7, {**b, "hip": (0, -10, 3), "torso": -6, "weapon_tilt": aim_tilt - 4}),
            (5 / 7, {**b, "hip": (0, -12, 2) if style == "burst" else (0, -6, 3), "torso": -7 if style == "burst" else -4,
                     "weapon_tilt": aim_tilt - (7 if style == "burst" else 2)}),
            (6 / 7, {**b, "hip": (0, -2, 2), "torso": -1, "weapon_tilt": 0}),
            (1.0, {**b, "hip": (0, 1, 1), "torso": 1, "weapon_tilt": 0}),
        ]
    elif style in ("slash", "ram"):
        keys = [
            (0.0, {**b, "hip": (0, 0, 2)}),
            (1 / 7, {**b, "hip": (0, -10, 10), "torso": -10, "uarm_f": -150, "farm_f": -30, "thigh_f": -20, "shin_f": 30}),
            (2 / 7, {**b, "hip": (0, -14, 12), "torso": -12, "uarm_f": -168, "farm_f": -36, "thigh_f": -24, "shin_f": 34}),
            (3 / 7, {**b, "hip": (0, 36, 2), "torso": 14, "uarm_f": -40, "farm_f": -20, "thigh_f": -40, "shin_f": 20,
                     "thigh_b": 34, "shin_b": 10}),
            (4 / 7, {**b, "hip": (0, 42, 8), "torso": 16, "uarm_f": -10, "farm_f": -10, "thigh_f": -42, "shin_f": 22,
                     "thigh_b": 36, "shin_b": 12}),
            (5 / 7, {**b, "hip": (0, 34, 6), "torso": 10, "uarm_f": -14, "farm_f": -14, "thigh_f": -30, "shin_f": 16}),
            (6 / 7, {**b, "hip": (0, 12, 3), "torso": 3}),
            (1.0, {**b, "hip": (0, -2, 0), "torso": -1}),
        ]
        if style == "ram":   # shield arm leads, weapon arm stays back
            for _, p in keys:
                p["uarm_b"], p["farm_b"] = -70 + p["torso"], -40
                p["uarm_f"], p["farm_f"] = base["uarm_f"] + 20, base["farm_f"]
    else:
        raise ValueError(style)
    return keyframes(keys, 8, loop=False)


# Effects whose colour is the element, not the tier accent.
VFX_COLOR = {"spray": (170, 238, 255, 255)}

FIRE_FRAMES = {"shoot": (3,), "burst": (3, 5), "spray": (3, 4, 5), "rail": (3, 4), "snipe": (3,),
               "chain": (3, 4), "heal": (3, 4, 5), "lob": (3,), "slash": (3, 4), "ram": (3, 4)}


def muzzle_vfx(style, tier, frame, muzzle):
    """Generic effects in the weapon bone at the muzzle point."""
    if frame not in FIRE_FRAMES[style]:
        if style in ("rail", "snipe") and frame in (1, 2):   # charge-up glow grows
            r = 6 + 6 * frame
            return [E("weapon", muzzle[0], muzzle[1], r, r, accent(tier)[:3] + (200,), 70, glow=True)]
        return []
    mx, my = muzzle
    a = VFX_COLOR.get(style, accent(tier)) if style in VFX_COLOR else accent(tier)
    soft = a[:3] + (150,)
    if style in ("shoot", "burst", "snipe", "rail"):
        length = {"shoot": 70, "burst": 60, "snipe": 110, "rail": 140}[style]
        width = {"shoot": 18, "burst": 14, "snipe": 14, "rail": 22}[style]
        fade = 1.0 if frame == FIRE_FRAMES[style][0] else 0.6
        return [P("weapon", ((mx, my - width), (mx + length * 0.55, my - width * 0.5), (mx + length, my),
                             (mx + length * 0.55, my + width * 0.5), (mx, my + width)), soft, 70, glow=True),
                E("weapon", mx + 6, my, width * fade, width * 0.75 * fade, WHITE, 71, glow=True)]
    if style == "spray":
        spread = 26 + 12 * (frame - 3)
        reach = 86 + 22 * (frame - 3)
        return [P("weapon", ((mx, my - 6), (mx + reach, my - spread), (mx + reach + 20, my), (mx + reach, my + spread), (mx, my + 6)),
                  soft, 70, glow=True),
                E("weapon", mx + reach * 0.6, my, 14, 10, WHITE[:3] + (180,), 71, glow=True)]
    if style == "chain":
        pts = []
        x, y = mx, my
        for k in range(7):
            x += 26
            y += (-18 if k % 2 == 0 else 18) * (1 if frame == 3 else -1)
            pts.append((x, y))
        bolt = [(mx, my - 4)] + [(px, py - 4) for px, py in pts] + [(px, py + 4) for px, py in reversed(pts)] + [(mx, my + 4)]
        return [P("weapon", bolt, a, 70, glow=True), E("weapon", mx, my, 16, 16, soft, 69, glow=True)]
    if style == "heal":
        r = 16 + 10 * (frame - 3)
        return [E("weapon", mx, my, r, r, (110, 255, 190, 170), 70, glow=True),
                E("weapon", mx, my, r * 0.45, r * 0.45, WHITE, 71, glow=True)]
    if style == "lob":
        return [E("weapon", mx + 10, my - 6, 30, 22, (220, 220, 220, 140), 69, glow=True),
                E("weapon", mx + 4, my, 16, 12, soft, 70, glow=True)]
    if style in ("slash", "ram"):
        sweep = [(70 + 130 * math.cos(math.radians(d)), -70 + 130 * math.sin(math.radians(d))) for d in range(-100, 41, 10)]
        inner = [(70 + 96 * math.cos(math.radians(d)), -70 + 96 * math.sin(math.radians(d))) for d in range(40, -101, -10)]
        if frame == FIRE_FRAMES[style][0]:
            return [P("torso", sweep + inner, soft, 40, glow=True)]
        star = [((150 if k % 2 == 0 else 60) * math.cos(math.radians(k * 22.5)) * 0.5 + 110,
                 (150 if k % 2 == 0 else 60) * math.sin(math.radians(k * 22.5)) * 0.35 - 40) for k in range(16)]
        return [P("torso", star, a, 40, glow=True)]
    return []


# ---------------------------------------------------------------- pipeline
def _job(args):
    module_name, tier, state, i, pose, scale = args
    mod = __import__(module_name)
    rig = Rig(mod.BONES, mod.parts_for(tier))
    extra = []
    if state == "attack":
        extra = muzzle_vfx(mod.STYLE, tier, i, mod.MUZZLE.get(tier, mod.MUZZLE[1]))
        if hasattr(mod, "attack_extra"):
            extra += mod.attack_extra(tier, i)
    # Render roomy, then crop to the smallest centred even square >= 512 that
    # holds everything (the oversized-frame contract the game uses).
    size = 768 if state == "idle" else 896
    img = ground(render(rig, pose, extra=extra, canvas_px=size, scale=scale))
    return (tier, state, i), img


def crop_centered(img, margin=6):
    box = img.getchannel("A").point(lambda a: 255 if a > 2 else 0).getbbox()
    c = img.width // 2
    half = 256
    if box:
        half = max(half, c - box[0] + margin, box[2] - c + margin, c - box[1] + margin, box[3] - c + margin)
    half = min(c, int(half + 1) // 2 * 2 if int(half) % 2 else int(half))
    return img.crop((c - half, c - half, c + half, c + half))


def solve_back_arm(rig_bones, pose, grip, uarm=BACK_UARM, farm=BACK_FARM):
    """Two-bone IK: set uarm_b/farm_b so the back hand reaches `grip`, a point
    in the weapon bone. Keeps the elbow below the line (natural bend)."""
    world = Rig(rig_bones, []).world(pose)
    wx, wy, wa = world["weapon"]
    gx = wx + grip[0] * math.cos(wa) - grip[1] * math.sin(wa)
    gy = wy + grip[0] * math.sin(wa) + grip[1] * math.cos(wa)
    sx, sy, ta = world["uarm_b"][0], world["uarm_b"][1], world["torso"][2]
    dx, dy = gx - sx, gy - sy
    d = min(math.hypot(dx, dy), uarm + farm - 1)
    # Angle of the shoulder->grip line measured from straight down (+y).
    line = math.atan2(-dx, dy)
    cos_a = (uarm * uarm + d * d - farm * farm) / (2 * uarm * d)
    a = math.acos(max(-1, min(1, cos_a)))
    elbow = math.acos(max(-1, min(1, (uarm * uarm + farm * farm - d * d) / (2 * uarm * farm))))
    q = dict(pose)
    q["uarm_b"] = math.degrees(line + a) - math.degrees(ta)
    q["farm_b"] = -(180 - math.degrees(elbow))
    return q


def animations(mod, tier):
    base = {**BASE, **getattr(mod, "HOLD", {})}
    sets = {"idle": idle_poses(base), "walk": walk_poses(base, stride=getattr(mod, "STRIDE", 1.0)),
            "retreat": walk_poses({**base, **getattr(mod, "RETREAT_HOLD", {})}, lean=-5, backward=True),
            "attack": attack_poses(mod.STYLE, base)}
    level = mod.STYLE not in ("slash", "ram")
    out = {k: finish(v, hold_level=level or k != "attack") for k, v in sets.items()}
    grip = getattr(mod, "GRIP", None)
    if grip:
        for k, poses in out.items():
            if k == "attack" and not level:
                continue
            out[k] = [solve_back_arm(mod.BONES, p, grip) for p in poses]
    return out


def auto_scale(mod, target_height=440):
    """Scale that makes the Lv1 idle figure about target_height px tall."""
    rig = Rig(mod.BONES, mod.parts_for(1))
    pose = animations(mod, 1)["idle"][0]
    img = render(rig, pose, canvas_px=768, scale=1.0)
    box = img.getchannel("A").point(lambda a: 255 if a > 120 else 0).getbbox()
    return target_height / max(1, box[3] - box[1])


def build(module_name, out_dir=None):
    from PIL import Image
    mod = __import__(module_name)
    out = Path(out_dir or ROOT / "builds" / "vector-proto" / mod.NAME)
    out.mkdir(parents=True, exist_ok=True)
    scale = getattr(mod, "SCALE", None) or auto_scale(mod)
    print(f"{mod.NAME}: unit scale {scale:.3f}")
    jobs = [(module_name, tier, state, i, pose, scale) for tier in (1, 2, 3)
            for state, poses in animations(mod, tier).items() for i, pose in enumerate(poses)]
    frames = {}
    with ProcessPoolExecutor(max_workers=4) as pool:
        for key, img in pool.map(_job, jobs):
            tier, state, i = key
            img = crop_centered(img)
            img.save(out / f"lv{tier}_{state}_{i + 1}.png")
            frames[key] = img
    cell = 220
    cells = []
    for step in range(16):
        canvas = Image.new("RGB", (4 * cell, 3 * cell), "#1b2130")
        for r, tier in enumerate((1, 2, 3)):
            for c, state in enumerate(("idle", "walk", "attack", "retreat")):
                src = frames[(tier, state, step % 8)]
                pad = Image.new("RGBA", (896, 896))
                o = (896 - src.width) // 2
                pad.paste(src, (o, o))
                img = pad.resize((cell, cell), Image.Resampling.LANCZOS)
                canvas.paste(img, (c * cell, r * cell), img)
        cells.append(canvas)
    cells[0].save(out / "anim.gif", save_all=True, append_images=cells[1:], duration=90, loop=0)
    print("wrote", out)
