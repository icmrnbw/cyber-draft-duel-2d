"""Demolitionist, vector. Gas-mask grenadier with a launcher.
Lv1 hazmat suit, single canister, grenade launcher. Lv2 Firestorm: twin
napalm tanks, underslung igniter, heat-shield apron. Lv3 Scorched Ground:
walking furnace with exhaust stacks venting flame, four-barrel rotary
launcher, molten cracks."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "demolitionist"
HEIGHT = 450
GAIT = {"stride": 0.8, "bounce": 5, "stomp": 4, "sway": 3, "lean": 4, "knee": 50}
STYLE = "lob"
BONES = bones(torso_h=146)
MUZZLE = {1: (118, -8), 2: (124, -8), 3: (132, -8)}
GRIP = (38, 6)
STRIDE = 0.8
OLIVE = (122, 140, 62, 255)
OLIVE_D = (70, 82, 36, 255)
MASK = (64, 66, 60, 255)
TANK = (150, 160, 90, 255)
GUN = (60, 58, 52, 255)
FIRE = (255, 120, 40, 255)


def parts_for(tier):
    a = accent(tier)
    bulk = {1: 1.12, 2: 1.18, 3: 1.28}[tier]
    p = standard_limbs(OLIVE, OLIVE_D, MASK, bulk=bulk)
    # Tanks on the back.
    if tier == 1:
        p += [C("pack", 4, -60, 4, 30, 24, TANK, -30, bevel=0.8), E("pack", 4, -64, 20, 10, MASK, -29)]
    else:
        for x, z in ((-16, -31), (22, -30)):
            p += [C("pack", x, -64, x, 30, 21, (200, 90, 50, 255) if tier == 2 else (90, 60, 50, 255), z, bevel=0.8),
                  E("pack", x, -68, 18, 9, MASK, z + 1)]
    if tier == 3:   # exhaust stacks venting flame
        for x in (-20, 6):
            p += [C("pack", x, -70, x, -130, 8, GUN, -28), G("pack", ((x - 10, -132), (x, -168), (x + 10, -132)), FIRE, -27),
                  G("pack", ((x - 5, -132), (x, -150), (x + 5, -132)), (255, 220, 120, 255), -26)]
    p += [
        E("torso", 0, -4, 42, 28, OLIVE_D, 0),
        S("torso", ((-48 * bulk, -18), (48 * bulk, -18), (54 * bulk, -94), (34, -132), (-34, -132), (-52 * bulk, -94)),
          OLIVE, 1, tint=1.04, lines=(((-34, -60), (40, -64)), ((-38, -90), (44, -94)))),
        C("torso", -40, -110, 40, -30, 6, (160, 120, 50, 255), 3),
        *[E("torso", -30 + i * 15, -100 + i * 15, 5, 7, (210, 170, 70, 255), 4) for i in range(5)],
    ]
    if tier >= 2:   # heat-shield apron
        p.append(P("torso", ((-30, -30), (40, -30), (46, 40), (-26, 44)), (110, 112, 104, 255), 5, tint=1.05,
                   lines=(((-24, 0), (42, -2)),)))
    if tier == 3:
        p += [G("torso", pts, ORANGE, 6) for pts in (((-30, -80), (-10, -100), (-6, -96), (-26, -76)),
                                                     ((20, -60), (34, -90), (38, -86), (24, -56)))]
    # Gas-mask helmet: hood dome, round lenses, filter canister.
    p += [
        S("head", ((-58, 20), (-64, -30), (-40, -74), (8, -84), (50, -64), (64, -20), (58, 24), (14, 42), (-40, 38)),
          OLIVE, 40, lines=(((-44, -44), (34, -58)),)),
        S("head", ((0, -30), (56, -24), (62, 18), (36, 40), (4, 34)), MASK, 41, gloss=0.4),
        E("head", 34, -8, 13, 13, (30, 40, 30, 255), 42, gloss=0.9),
        E("head", 34, -8, 7, 7, a if tier > 1 else (140, 200, 120, 255), 43, glow=True),
        C("head", 46, 24, 70, 34, 12, (90, 92, 84, 255), 42),
    ]
    # Launcher: drum, short barrel; rotary at Lv3.
    p += [
        P("weapon", ((-40, -6), (-8, -10), (-8, 10), (-38, 16)), GUN, 30),
        E("weapon", 20, 4, 26, 22, (96, 90, 70, 255), 31, lines=(((20, -18), (20, 26)),)),
    ]
    if tier < 3:
        p += [C("weapon", 30, -8, 112, -8, 13, GUN, 30, bevel=0.8), E("weapon", 112, -8, 10, 10, (30, 30, 30, 255), 32)]
    else:
        for y in (-18, -6, 6):
            p += [C("weapon", 30, y, 124, y, 6, GUN, 30)]
        p += [P("weapon", ((60, -26), (74, -26), (74, 14), (60, 14)), MASK, 31), G("weapon", ((80, -10), (118, -10), (118, -6), (80, -6)), ORANGE, 32)]
    if tier >= 2:   # underslung igniter
        p += [C("weapon", 40, 20, 92, 20, 6, (110, 100, 80, 255), 29), E("weapon", 94, 20, 5, 5, ORANGE if tier == 3 else FIRE, 30, glow=True)]
    if tier >= 2:   # bandolier pouches and a welding-shield visor plate
        p += [P("head", ((30, -40), (70, -36), (68, -24), (30, -26)), MASK, 44, tint=1.1),
              *[P("torso", ((x, -30), (x + 18, -30), (x + 18, -6), (x, -6)), OLIVE_D, 7) for x in (-40, -18)]]
    if tier == 3:   # furnace grille on the chest and shoulder plates
        p += [P("torso", ((-14, -120), (34, -120), (34, -80), (-14, -80)), MASK, 8),
              *[G("torso", ((-10, y), (30, y), (30, y + 4), (-10, y + 4)), ORANGE, 9) for y in (-114, -104, -94)],
              P("uarm_f", ((-26, -16), (24, -20), (30, 14), (-22, 16)), OLIVE, 38, tint=1.1)]
    return p


if __name__ == "__main__":
    build("marksman") if False else build("demolitionist")
