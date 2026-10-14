"""Cryotek, vector. White/teal armoured cryo trooper with frost tanks.
Lv1 rounded helmet with wraparound visor, two frost tanks, twin cryo cannon.
Lv2 Cryo Lock: ice crystal growths on shoulders and tanks, frost compressor.
Lv3 Thermal Collapse: glacial titan with crystal pauldrons, frost aura,
heavy cryo-lance."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "cryotek"
STYLE = "spray"
BONES = bones(torso_h=150)
MUZZLE = {1: (132, -2), 2: (136, -2), 3: (176, 0)}
GRIP = (34, 8)
STRIDE = 0.85
WHITE = (232, 238, 244, 255)
TEAL = (26, 78, 96, 255)
GLASS = (150, 222, 250, 255)
ICE = (200, 242, 255, 255)
FROST = (150, 230, 255, 255)


def shard(bone, x, y, h, lean, z, color=ICE):
    import math
    w = h * 0.36
    return P(bone, ((x - w, y), (x + math.sin(math.radians(lean)) * h, y - h), (x + w, y)), color, z, tint=1.05)


def parts_for(tier):
    a = accent(tier)
    bulk = {1: 1.1, 2: 1.14, 3: 1.24}[tier]
    p = standard_limbs(WHITE, TEAL, TEAL, bulk=bulk)
    p += [C("pack", 30, -76, 30, 26, 24, GLASS, -32, gloss=0.9), E("pack", 30, -80, 22, 10, WHITE, -31),
          C("pack", 0, -64, 0, 38, 26, GLASS, -30, gloss=0.9), E("pack", 0, -68, 24, 11, WHITE, -29),
          P("pack", ((-26, 6), (26, 6), (26, 18), (-26, 18)), TEAL, -28)]
    if tier >= 2:
        p += [shard("pack", 16, -88, 34 * (1.6 if tier == 3 else 1), -12, -27), shard("pack", -8, -76, 24, 14, -27)]
    p += [
        E("torso", 0, -4, 44, 28, TEAL, 0),
        P("torso", ((-48 * bulk, -20), (50 * bulk, -20), (58 * bulk, -94), (40, -132), (-40, -132), (-56 * bulk, -94)), WHITE, 1,
          tint=1.04, lines=(((-30, -60), (36, -64)),)),
        P("torso", ((-12, -26), (14, -26), (18, -110), (-14, -110)), TEAL, 2),
        E("torso", 30, -92, 9, 9, a, 3, glow=True),
    ]
    if tier >= 2:
        p += [shard("torso", -34, -126, 30 * (1.7 if tier == 3 else 1), -16, 5), shard("torso", -12, -130, 22 * (1.5 if tier == 3 else 1), 10, 5),
              G("torso", ((-44, -60), (-12, -62), (-12, -57), (-44, -55)), a, 4)]
    if tier == 3:   # frost aura ring at the feet
        p.insert(0, E("hip", 0, 150, 120, 18, FROST[:3] + (90,), -60, glow=True))
    p += [
        S("head", ((-58, 16), (-62, -36), (-34, -74), (8, -84), (50, -62), (64, -18), (58, 22), (14, 40), (-38, 34)),
          WHITE, 40, lines=(((-44, -50), (30, -60)),)),
        S("head", ((0, -26), (64, -16), (64, 26), (12, 32), (-4, 8)), (120, 214, 242, 255), 41, gloss=0.9),
        E("head", -30, 6, 15, 15, TEAL, 42),
        E("head", -30, 6, 6, 6, a, 43, glow=True),
    ]
    if tier < 3:
        p += [P("weapon", ((-20, -20), (62, -24), (68, 22), (-20, 26)), TEAL, 30),
              P("weapon", ((-16, -20), (60, -24), (58, -8), (-16, -6)), WHITE, 31),
              C("weapon", 60, -11, 126, -11, 10, GLASS, 29, gloss=0.9), C("weapon", 60, 12, 126, 12, 10, GLASS, 29, gloss=0.9),
              P("weapon", ((96, -24), (106, -24), (106, 26), (96, 26)), TEAL, 32),
              E("weapon", 128, -11, 5, 5, a, 33, glow=True), E("weapon", 128, 12, 5, 5, a, 33, glow=True)]
        if tier == 2:
            p += [P("weapon", ((-24, 24), (30, 24), (30, 42), (-24, 42)), TEAL, 33), G("weapon", ((-18, 30), (24, 30), (24, 36), (-18, 36)), a, 34)]
    else:
        p += [P("weapon", ((-20, -24), (66, -26), (72, 24), (-20, 28)), TEAL, 30),
              P("weapon", ((56, -16), (150, -6), (150, 8), (56, 20)), GLASS, 29, gloss=0.9),
              P("weapon", ((150, -6), (178, 1), (150, 8)), ICE, 29),
              G("weapon", ((60, -3), (146, -1), (146, 4), (60, 6)), ORANGE, 31),
              shard("weapon", 20, -24, 30, 10, 32)]
    return p


if __name__ == "__main__":
    build("cryotek")
