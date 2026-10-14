"""Trooper, vector. Lv1 rifleman; Lv2 Burst Protocol (drum mag, triple shroud,
belt-fed ammo pack, antenna); Lv3 Suppressive Volley (heavy suit, belt-fed LMG
with bipod, hover drone, tri-lens helmet)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import CYAN, ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "trooper"
STYLE = "burst"
BONES = bones()
MUZZLE = {1: (128, -6), 2: (140, -6), 3: (156, -4)}
GRIP = (34, 6)   # back hand on the foregrip
SILVER = (200, 208, 220, 255)
STEEL = (120, 128, 144, 255)
DARK = (58, 62, 74, 255)
GUN = (52, 56, 66, 255)
VISOR = (28, 36, 54, 255)


def parts_for(tier):
    a = accent(tier)
    heavy = 1.12 if tier == 3 else 1.0
    p = standard_limbs(SILVER, DARK, DARK, bulk=heavy)
    # Backpack (ammo pack from Lv2).
    p += [P("pack", ((-24, -46), (26, -50), (30, 30), (-26, 34)), STEEL, -30, tint=0.9)]
    if tier >= 2:
        p += [P("pack", ((-30, -40), (-4, -42), (-4, 24), (-30, 26)), GUN, -29),
              C("pack", -14, -50, -14, -110, 3, DARK, -31),
              E("pack", -14, -112, 5, 5, a, -30, glow=True)]
    # Torso.
    p += [
        E("torso", 0, -4, 40, 26, DARK, 0),
        P("torso", ((-44 * heavy, -20), (46 * heavy, -20), (52 * heavy, -96), (34, -132), (-34, -132), (-50 * heavy, -96)),
          SILVER, 1, tint=1.04, lines=(((-30, -60), (34, -64)), ((0, -128), (0, -24)))),
        P("torso", ((10, -128), (34, -132), (52 * heavy, -96), (46 * heavy, -20), (12, -20)), SILVER, 2, tint=0.84),
        P("torso", ((-46, -26), (48, -26), (48, -12), (-46, -12)), GUN, 3),
        G("torso", ((-30, -94), (-10, -96), (-10, -90), (-30, -88)), a, 4),
    ]
    # Helmet.
    p += [
        S("head", ((-58, 10), (-62, -36), (-36, -70), (6, -78), (46, -60), (62, -24), (58, 18), (20, 34), (-36, 30)),
          SILVER, 20, lines=(((-40, -50), (30, -56)),)),
        P("head", ((-6, -22), (64, -18), (64, 16), (4, 20)), VISOR, 22, gloss=0.6),
        E("head", -34, 6, 14, 15, STEEL, 23),
    ]
    if tier < 3:
        p.append(G("head", ((8, -6), (60, -4), (60, 2), (8, 2)), a, 24))
    else:
        p += [E("head", x, -2, 7, 7, ORANGE, 24, glow=True) for x in (18, 36, 54)]
        p.append(P("head", ((-50, -60), (-20, -82), (20, -84), (-30, -56)), STEEL, 21, tint=1.1))
    # Weapon.
    if tier == 1:
        p += [P("weapon", ((-44, -10), (-8, -14), (-8, 10), (-40, 16)), GUN, 30),
              P("weapon", ((-10, -16), (70, -18), (72, 6), (-10, 10)), GUN, 31, tint=1.1, lines=(((10, -4), (60, -6)),)),
              C("weapon", 70, -6, 126, -6, 5, DARK, 30),
              P("weapon", ((20, 6), (34, 6), (30, 34), (18, 34)), DARK, 29),
              G("weapon", ((20, -12), (56, -13), (56, -9), (20, -8)), a, 32)]
    elif tier == 2:
        p += [P("weapon", ((-44, -10), (-8, -14), (-8, 10), (-40, 16)), GUN, 30),
              P("weapon", ((-10, -18), (84, -20), (86, 8), (-10, 12)), GUN, 31, tint=1.1, lines=(((10, -4), (70, -6)),)),
              *[C("weapon", 84, y, 138, y, 4, DARK, 30) for y in (-12, -5, 2)],
              P("weapon", ((80, -16), (96, -16), (96, 6), (80, 6)), STEEL, 32),
              E("weapon", 20, 22, 20, 18, STEEL, 29),
              G("weapon", ((20, -14), (66, -15), (66, -11), (20, -10)), a, 33),
              C("pack", 22, 0, 60, 46, 4, (190, 160, 70, 255), -5)]
    else:
        p += [P("weapon", ((-48, -12), (-8, -16), (-8, 12), (-44, 18)), GUN, 30),
              P("weapon", ((-10, -22), (96, -22), (100, 12), (-10, 16)), GUN, 31, tint=1.1, lines=(((10, -4), (84, -6)),)),
              C("weapon", 96, -4, 154, -4, 7, DARK, 30),
              P("weapon", ((140, -12), (152, -12), (152, 4), (140, 4)), STEEL, 32),
              C("weapon", 120, 6, 104, 44, 3, DARK, 29), C("weapon", 120, 6, 136, 44, 3, DARK, 29),
              P("weapon", ((14, 14), (44, 14), (44, 40), (14, 40)), STEEL, 29),
              G("weapon", ((20, -18), (84, -18), (84, -13), (20, -13)), ORANGE, 33),
              C("pack", 22, 0, 60, 46, 4, (190, 160, 70, 255), -5),
              # Hover drone over the back shoulder.
              S("pack", ((-30, -132), (10, -140), (30, -124), (8, -110), (-26, -112)), STEEL, -2),
              E("pack", 0, -124, 8, 8, ORANGE, -1, glow=True),
              G("pack", ((-26, -104), (26, -104), (20, -98), (-20, -98)), ORANGE, -1)]
    return p


if __name__ == "__main__":
    build("trooper")
