"""Phaseblade, vector. Slim hooded duelist with a curved energy blade.
Lv1 purple hood and cape, silver mask with a cyan slit, one blade.
Lv2 Phase Lunge: afterimage shards trailing from the cape, phase-split blade.
Lv3 Rift Mark: cape dissolves into void tendrils, orbiting blade fragments,
cracked mask leaking orange light."""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "phaseblade"
HEIGHT = 425
GAIT = {"stride": 1.25, "bounce": 10, "lean": 10, "swing": 16, "knee": 70}
STYLE = "slash"
BONES = bones(torso_h=150)
MUZZLE = {1: (0, 0)}
HOLD = {"uarm_f": 20, "farm_f": -20, "uarm_b": -30, "farm_b": -70}
STRIDE = 1.15
PURPLE = (120, 70, 180, 255)
PURPLE_D = (58, 32, 92, 255)
SILVER = (196, 204, 220, 255)
DARK = (44, 40, 66, 255)


def blade(tier):
    a = accent(tier)
    curve = [(0, 0)] + [(16 + 15 * k, -6 - 4 * math.sin(k / 8 * math.pi) * 6 - k * 1.5) for k in range(1, 10)]
    edge = [(x, y) for x, y in curve] + [(x, y + 10 - k * 0.8) for k, (x, y) in reversed(list(enumerate(curve)))]
    out = [C("weapon", -10, 0, 14, 0, 6, DARK, 33), G("weapon", edge, a, 34)]
    if tier >= 2:
        out.append(G("weapon", [(x, y - 14) for x, y in curve] + [(x, y - 8) for x, y in reversed(curve)], a[:3] + (150,), 35))
    return out


def parts_for(tier):
    a = accent(tier)
    p = standard_limbs(SILVER, PURPLE_D, DARK, bulk=0.88)
    # Cape (void tendrils at Lv3).
    if tier < 3:
        p.insert(0, P("torso", ((-20, -150), (12, -156), (-10, -40), (-40, 30), (-56, 0), (-76, 36), (-80, -20), (-50, -110)),
                      PURPLE, -40, tint=0.85, bevel=0.4))
    else:
        for k in range(5):
            p.insert(0, S("torso", ((-10 - k * 6, -140 + k * 10), (-30 - k * 8, -60 + k * 6), (-70 - k * 12, 20 + k * 10),
                                    (-56 - k * 10, 30 + k * 10), (-20 - k * 6, -60 + k * 10)), (60, 30, 90, 220), -40 - k, gloss=0.2))
        p.append(G("torso", ((-60, 20), (-50, 10), (-46, 24), (-56, 34)), ORANGE, -30))
    if tier >= 2:   # afterimage shards
        for k in range(3):
            x = -70 - k * 22
            p.append(G("torso", ((x, -100 + k * 30), (x - 16, -88 + k * 30), (x - 4, -76 + k * 30)), a[:3] + (140,), -45))
    p += [
        E("torso", 0, -4, 30, 22, PURPLE_D, 0),
        S("torso", ((-34, -20), (36, -20), (40, -96), (24, -130), (-24, -130), (-38, -96)), SILVER, 1,
          lines=(((-22, -60), (26, -64)),)),
        G("torso", ((-20, -100), (-14, -100), (-4, -40), (-10, -40)), a, 2),
        P("torso", ((-36, -26), (38, -26), (38, -14), (-36, -14)), PURPLE_D, 3),
    ]
    # Hood and mask.
    p += [
        S("head", ((-64, 30), (-70, -26), (-44, -80), (6, -92), (48, -66), (60, -20), (54, 30), (10, 44), (-40, 44)),
          PURPLE, 40, lines=(((-50, -50), (20, -70)),)),
        S("head", ((-2, -30), (50, -24), (54, 12), (40, 34), (2, 30)), SILVER, 41, gloss=0.8),
        G("head", ((10, -6), (50, -4), (50, 2), (10, 0)), a, 42),
    ]
    if tier == 3:
        p += [G("head", ((20, -24), (28, -10), (24, -10), (34, 6), (18, -8)), ORANGE, 43),
              *[G("torso", ((x, y), (x + 20, y - 6), (x + 6, y + 6)), ORANGE, 44) for x, y in ((60, -200), (-70, -180), (90, -120))]]
    p += blade(tier)
    if tier >= 2:   # second blade in the back hand and blade-fin shoulders
        curve = [(16 + 13 * q, -6 - q * 2.2) for q in range(9)]
        p += [G("shield", [(x, y) for x, y in curve] + [(x, y + 9) for x, y in reversed(curve)], a, -9),
              C("shield", -8, 0, 10, 0, 5, DARK, -10),
              P("uarm_f", ((-12, -14), (40, -40), (20, 4)), SILVER, 38, tint=1.1),
              P("uarm_b", ((-12, -14), (40, -40), (20, 4)), SILVER, -10, tint=0.9)]
    return p


if __name__ == "__main__":
    build("phaseblade")
