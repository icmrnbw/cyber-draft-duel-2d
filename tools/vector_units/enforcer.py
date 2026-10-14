"""Enforcer, vector, side-on (faces screen-right like the rest of the roster).

Lv1  riot trooper: domed helmet with a visor slit, plated chest, two tonfas.
Lv2  Heavy Strikes: shock-gauntlets fused over the tonfas, layered riot plating,
     T-visor (art_sources/2026-10-14/concepts/enforcer_lv2_concept.png).
Lv3  Berserk: horned juggernaut, glowing reactor chest, torn half-cape,
     orange plasma batons, forward hunch.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "enforcer"
HEIGHT = 490
GAIT = {"stride": 0.8, "bounce": 4, "stomp": 6, "sway": 2.5, "lean": 3, "knee": 44, "swing": 8}
STYLE = "slash"
BONES = bones(torso_h=196, shoulder=(40, -132), back_shoulder=(-18, -136))
MUZZLE = {1: (0, 0)}
HOLD = {"uarm_f": 14, "farm_f": -46, "uarm_b": 26, "farm_b": -40}
RETREAT_HOLD = {"uarm_f": -20, "farm_f": -100, "uarm_b": -10, "farm_b": -90}
STRIDE = 0.85
RED = (206, 58, 66, 255)
RED_D = (126, 34, 46, 255)
RED_DD = (78, 22, 32, 255)
METAL = (152, 158, 172, 255)
METAL_D = (92, 96, 110, 255)
CLOTH = (64, 20, 28, 255)


def tonfa(bone, tier, z):
    """Baton in the hand: grip across the fist, shaft along the forearm."""
    a = accent(tier)
    reach = 1.15 if tier == 3 else 1.0
    out = [C(bone, -6, -2, 8, -2, 6, METAL_D, z),
           C(bone, -30 * reach, 6, 70 * reach, 6, 9, METAL, z + 1, bevel=0.9),
           C(bone, -20 * reach, 4, 60 * reach, 4, 3, a, z + 2, glow=True)]
    if tier == 3:
        out += [G(bone, ((56, -4), (70, -18), (66, -4), (82, -12), (70, 4)), ORANGE, z + 3)]
    return out


def gauntlet(side, tier, z):
    a = accent(tier)
    g = 1.25 if tier == 3 else 1.12
    bone = f"farm_{side}"
    return [
        P(bone, ((-24 * g, -6), (0, -12), (0, 52), (-22 * g, 50)), RED, z, tint=1.08, lines=(((-20, 18), (0, 16)),)),
        P(bone, ((0, -12), (24 * g, -6), (22 * g, 50), (0, 52)), RED, z, tint=0.84),
        P(bone, ((22, -2), (34, 6), (34, 46), (24, 52)), METAL, z + 1),
        E(bone, 30, 24, 9, 9, METAL_D, z + 2),
        E(bone, 30, 24, 5, 5, a, z + 3, glow=True),
        *[G(bone, ((-12 + x, 36), (-6 + x, 36), (-6 + x, 46), (-12 + x, 46)), a, z + 3) for x in (0, 9, 18)],
    ]


def parts_for(tier):
    a = accent(tier)
    big = {1: 1.3, 2: 1.4, 3: 1.5}[tier]
    p = standard_limbs(RED, RED_DD, RED_D, bulk=big, z_arm_b=-14, z_arm_f=36)
    if tier == 3:
        p.insert(0, P("torso", ((-40, -150), (-6, -156), (-30, -20), (-60, 6), (-74, -30), (-96, 0), (-84, -70)),
                      CLOTH, -40, tint=0.9, bevel=0.3, gloss=0.1))
    # Torso: barrel chest, segmented abdomen.
    p += [
        P("torso", ((-38, -4), (40, -4), (46, -70), (-46, -70)), RED_DD, 0, gloss=0.1),
        *[P("torso", ((-34, y), (34, y), (34, y + 16), (-34, y + 16)), RED_D, 1, tint=t)
          for y, t in ((-64, 1.05), (-44, 0.95), (-24, 0.85))],
        P("torso", ((-64 * big, -78), (-46 * big, -176), (34, -188), (74 * big, -146), (66 * big, -74)), RED, 2, tint=1.08,
          lines=(((-40, -130), (50, -136)),)),
        P("torso", ((24, -186), (74 * big, -146), (66 * big, -74), (28, -76)), RED, 3, tint=0.84),
        P("torso", ((-30, -190), (30, -194), (20, -170), (-24, -168)), RED_D, 3),
        P("torso", ((-58, -16), (58, -16), (60, 6), (-60, 6)), RED, 4),
    ]
    if tier >= 2:
        p += [G("torso", ((30, -140), (40, -140), (46, -100), (36, -100)), a, 5),
              G("torso", ((-34, -146), (-24, -148), (-20, -110), (-30, -108)), a, 5)]
    if tier == 3:
        p += [E("torso", 20, -112, 18, 18, RED_DD, 6), E("torso", 20, -112, 11, 11, ORANGE, 7, glow=True),
              G("torso", ((-20, -100), (0, -120), (4, -116), (-16, -96)), ORANGE, 7)]
    # Pauldrons (on the upper arms so they move with the shoulder).
    for side, z in (("b", -13), ("f", 37)):
        pad = {1: 1.0, 2: 1.15, 3: 1.28}[tier]
        p += [P(f"uarm_{side}", ((-34 * pad, -10), (-16, -40 * pad), (24 * pad, -40 * pad), (40 * pad, -12), (34 * pad, 18), (-30 * pad, 20)),
                RED, z + 3, tint=1.12 if side == "f" else 0.9, lines=(((-24, 4), (30, 2)),))]
        if tier >= 2:
            p.append(G(f"uarm_{side}", ((10, -30), (30, -28), (30, -22), (10, -24)), a, z + 4))
        if tier == 3:
            p.append(P(f"uarm_{side}", ((0, -36), (10, -70), (20, -36)), METAL, z + 4))
    # Helmet seen side-on: dome, cheek plate, visor toward screen-right.
    p += [
        S("head", ((-56, 14), (-60, -38), (-34, -76), (8, -84), (48, -64), (64, -26), (62, 18), (24, 40), (-30, 36)),
          RED, 50, lines=(((-44, -50), (40, -58)),)),
        P("head", ((0, -26), (66, -20), (64, 28), (34, 44), (6, 36)), RED_D, 51, tint=0.95),
        E("head", -30, 4, 15, 18, RED_D, 52),
        P("head", ((10, -16), (66, -12), (64, 4), (12, 2)), RED_DD, 52, gloss=0.2),
        G("head", ((16, -10), (64, -7), (63, -1), (16, -2)), a if tier > 1 else (110, 236, 255, 255), 53),
    ]
    if tier >= 2:
        p.append(G("head", ((40, -2), (48, -2), (46, 24), (40, 24)), a, 53))
    if tier == 3:
        p += [P("head", ((-30, -64), (-70, -112), (-58, -116), (-14, -74)), METAL, 19, tint=1.1),
              P("head", ((10, -78), (20, -124), (32, -120), (28, -76)), METAL, 19, tint=0.9)]
    # Weapons: tonfa in each hand; gauntlets from Lv2.
    p += tonfa("weapon", tier, 40) + tonfa("shield", tier, -10)
    if tier >= 2:
        p += gauntlet("f", tier, 38) + gauntlet("b", tier, -11)
    if tier >= 2:   # riot slab on the back and a raised collar
        p += [P("torso", ((-70, -170), (-40, -196), (-30, -60), (-66, -40)), RED_D, -35, tint=0.9),
              P("torso", ((-30, -200), (40, -206), (34, -180), (-26, -176)), RED, 6, tint=1.1)]
    if tier >= 2:   # shock pylons rising behind the shoulders (silhouette)
        s_ = 1.0 if tier == 2 else 1.3
        for x in (-50, 0):
            p += [P("pack", ((x - 14, -40), (x + 14, -40), (x + 10, -40 - 120 * s_), (x - 10, -40 - 120 * s_)), METAL_D, -36),
                  P("pack", ((x - 22, -40 - 60 * s_), (x + 22, -40 - 60 * s_), (x + 22, -28 - 60 * s_), (x - 22, -28 - 60 * s_)), METAL, -35),
                  E("pack", x, -44 - 120 * s_, 12, 12, METAL, -35), E("pack", x, -44 - 120 * s_, 6, 6, a, -34, glow=True),
                  G("pack", ((x - 3, -50), (x + 3, -50), (x + 3, -30 - 110 * s_), (x - 3, -30 - 110 * s_)), a, -35)]
    return p


if __name__ == "__main__":
    build("enforcer")
