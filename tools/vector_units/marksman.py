"""Marksman, vector. Hooded long-range sniper.
Lv1 hood, cloak, long rifle. Lv2 Charged Round: capacitor rings on the barrel,
rangefinder drone at the shoulder, circuitry in the cloak. Lv3 Target Lock:
floating ring of targeting lenses around the head, scope-eye, long tattered
coat with sigils, coil-charged barrel."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CYAN, ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "marksman"
STYLE = "snipe"
BONES = bones(torso_h=150)
MUZZLE = {1: (176, -6), 2: (184, -6), 3: (196, -6)}
GRIP = (40, 4)
STRIDE = 0.9
VIOLET = (120, 72, 190, 255)
VIOLET_D = (66, 38, 110, 255)
ARMOR = (96, 200, 230, 255)
DARK = (38, 46, 70, 255)
GUN = (48, 52, 64, 255)


def parts_for(tier):
    a = accent(tier)
    p = standard_limbs(ARMOR, DARK, DARK, bulk=0.95)
    coat = 1.0 if tier < 3 else 1.35
    # Cloak behind the body, longer and tattered at Lv3.
    cloak = [(-30, -170), (10, -176), (-6, -60), (-30, 40 * coat), (-46, 20 * coat), (-62, 52 * coat), (-74, 10 * coat), (-60, -100)]
    p.insert(0, P("torso", cloak, VIOLET, -40, tint=0.85, bevel=0.4, gloss=0.2))
    if tier >= 2:
        p += [G("torso", ((-50, -60), (-46, -60), (-52, 0), (-56, 0)), a, -39),
              G("torso", ((-38, -110), (-34, -110), (-40, -40), (-44, -40)), a, -39)]
    if tier == 3:
        p += [G("torso", ((-66, 20), (-58, 10), (-54, 22), (-62, 30)), ORANGE, -38)]
    p += [
        E("torso", 0, -4, 36, 24, DARK, 0),
        P("torso", ((-40, -20), (42, -20), (46, -96), (30, -130), (-30, -130), (-44, -96)), ARMOR, 1, tint=1.04,
          lines=(((-26, -60), (30, -64)),)),
        P("torso", ((10, -128), (30, -130), (46, -96), (42, -20), (12, -20)), ARMOR, 2, tint=0.84),
        P("torso", ((-42, -26), (44, -26), (44, -12), (-42, -12)), DARK, 3),
        C("torso", -30, -60, 36, -20, 4, (90, 70, 40, 255), 4),
    ]
    # Hooded head with a sealed face plate and a lens eye.
    p += [
        S("head", ((-60, 26), (-66, -30), (-40, -78), (10, -88), (52, -62), (64, -16), (56, 30), (10, 44), (-40, 40)),
          VIOLET, 40, lines=(((-40, -56), (30, -68)),)),
        S("head", ((-6, -30), (48, -26), (56, 8), (44, 34), (4, 30)), (60, 150, 190, 255), 41, gloss=0.8),
        E("head", 38, -2, 8, 8, a, 42, glow=True),
    ]
    if tier == 3:   # scope-eye and a floating lens ring
        p += [C("head", 40, -2, 70, -2, 7, GUN, 43), E("head", 72, -2, 9, 9, ORANGE, 44, glow=True)]
        for k, (x, y) in enumerate(((-70, -60), (-30, -112), (30, -116), (78, -64))):
            p += [E("head", x, y, 11, 11, GUN, 45), E("head", x, y, 6, 6, ORANGE, 46, glow=True)]
    if tier >= 2:   # rangefinder drone at the back shoulder
        p += [S("pack", ((-10, -110), (30, -116), (42, -100), (20, -90), (-6, -92)), GUN, 30),
              E("pack", 32, -104, 6, 6, a, 31, glow=True)]
    # Rifle: long barrel, scope, stock.
    barrel = {1: 170, 2: 178, 3: 190}[tier]
    p += [
        P("weapon", ((-52, -8), (-12, -12), (-10, 10), (-48, 18)), GUN, 30),
        P("weapon", ((-12, -14), (70, -14), (72, 8), (-12, 10)), GUN, 31, tint=1.1),
        C("weapon", 70, -6, barrel, -6, 4, (36, 40, 50, 255), 30),
        C("weapon", 0, -26, 50, -26, 7, (36, 40, 50, 255), 32),
        E("weapon", 50, -26, 7, 7, a, 33, glow=True),
        P("weapon", ((20, 8), (32, 8), (28, 30), (18, 30)), GUN, 29),
    ]
    if tier >= 2:
        p += [E("weapon", x, -6, 7, 9, (100, 110, 130, 255), 31) for x in (100, 122, 144)]
        p += [E("weapon", x, -6, 3, 5, a, 32, glow=True) for x in (100, 122, 144)]
    if tier == 3:
        p += [G("weapon", ((80, -9), (barrel - 6, -8), (barrel - 6, -4), (80, -3)), ORANGE, 33)]
    return p


if __name__ == "__main__":
    build("marksman")
