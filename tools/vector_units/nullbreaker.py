"""Nullbreaker, vector. Crimson-and-black long-coated gunner with a gas-mask
helmet and a long railgun with coil rings.
Lv2 Piercing Charge: extended null barrel with stabiliser fins, shoulder
capacitor. Lv3 Expose Core: exposed core harness on the chest, twin rails,
hood with a single void eye."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "nullbreaker"
HEIGHT = 455
GAIT = {"stride": 1.2, "bounce": 4, "lean": -2, "sway": 1.5, "knee": 58}
STYLE = "rail"
BONES = bones(torso_h=150)
MUZZLE = {1: (190, -4), 2: (210, -4), 3: (214, -4)}
GRIP = (44, 6)
STRIDE = 0.85
CRIMSON = (176, 40, 52, 255)
BLACK = (40, 40, 48, 255)
METAL = (110, 112, 124, 255)


def parts_for(tier):
    a = accent(tier)
    p = standard_limbs(METAL, BLACK, BLACK, bulk=1.0)
    p.insert(0, P("torso", ((-34, -130), (24, -136), (30, 60), (6, 74), (-40, 70), (-70, 40), (-54, -60)), CRIMSON, -40,
                  tint=0.9, bevel=0.5, lines=(((-30, -40), (-34, 60)),)))
    p += [
        E("torso", 0, -4, 36, 24, BLACK, 0),
        P("torso", ((-42, -20), (44, -20), (48, -98), (30, -132), (-30, -132), (-46, -98)), BLACK, 1, tint=1.1,
          lines=(((-28, -60), (32, -64)),)),
        P("torso", ((-40, -130), (40, -132), (36, -110), (-36, -108)), CRIMSON, 2),
    ]
    if tier >= 2:   # shoulder capacitor
        p += [C("pack", 30, -60, 30, -20, 14, METAL, 20), E("pack", 30, -40, 6, 10, a, 21, glow=True)]
    if tier == 3:   # exposed core harness
        p += [P("torso", ((-20, -110), (30, -110), (30, -60), (-20, -60)), METAL, 3),
              E("torso", 6, -86, 16, 16, BLACK, 4), E("torso", 6, -86, 10, 10, ORANGE, 5, glow=True)]
    p += [
        S("head", ((-56, 18), (-60, -36), (-34, -76), (8, -84), (48, -64), (62, -20), (56, 22), (12, 40), (-36, 36)),
          CRIMSON if tier < 3 else BLACK, 40, lines=(((-40, -50), (30, -58)),)),
        S("head", ((0, -24), (56, -18), (60, 20), (34, 42), (4, 34)), BLACK, 41, gloss=0.5),
        C("head", 40, 26, 64, 36, 10, METAL, 42),
    ]
    if tier < 3:
        p += [E("head", 26, -6, 9, 9, a, 43, glow=True), E("head", 46, -4, 7, 7, a, 43, glow=True)]
    else:
        p += [E("head", 36, -6, 13, 13, (20, 10, 20, 255), 43), E("head", 36, -6, 7, 7, ORANGE, 44, glow=True)]
    length = {1: 186, 2: 206, 3: 210}[tier]
    rails = (-6,) if tier < 3 else (-12, 2)
    p += [P("weapon", ((-50, -12), (-8, -16), (-6, 14), (-46, 20)), BLACK, 30),
          P("weapon", ((-8, -20), (80, -20), (84, 14), (-8, 16)), METAL, 31, tint=1.05, lines=(((10, -4), (70, -6)),))]
    for y in rails:
        p += [C("weapon", 80, y, length, y, 5, BLACK, 30), G("weapon", ((86, y - 2), (length - 6, y - 2), (length - 6, y + 2), (86, y + 2)), a, 32)]
    p += [E("weapon", x, -6 if tier < 3 else -5, 8, 14, METAL, 33) for x in (104, 130, 156)]
    p += [E("weapon", x, -6, 3, 8, a, 34, glow=True) for x in (104, 130, 156)]
    if tier >= 2:   # stabiliser fins
        p += [P("weapon", ((170, -10), (186, -30), (192, -10)), METAL, 33), P("weapon", ((170, 0), (186, 20), (192, 0)), METAL, 33)]
    if tier >= 2:   # twin back capacitors and a heavy shoulder plate
        p += [C("pack", -10, -90, -10, 10, 16, METAL, -32), C("pack", 26, -96, 26, 4, 16, METAL, -33),
              G("pack", ((-14, -80), (-6, -80), (-6, 0), (-14, 0)), a, -31), G("pack", ((22, -86), (30, -86), (30, -6), (22, -6)), a, -31),
              P("uarm_f", ((-28, -16), (26, -22), (34, 14), (-24, 18)), CRIMSON, 38, tint=1.05)]
    if tier == 3:   # spiked cowl, long split cape, core spikes
        p += [P("head", ((-60, -20), (-90, -90), (-40, -60), (-20, -100), (0, -70)), BLACK, 39),
              P("torso", ((-30, -100), (-120, 120), (-70, 90), (-60, 140), (-20, 60)), CRIMSON, -46, tint=0.8),
              P("uarm_f", ((-10, -20), (6, -60), (20, -18)), METAL, 39), P("uarm_b", ((-10, -20), (6, -60), (20, -18)), METAL, -10)]
    if tier >= 2:   # capacitor towers above the shoulders
        s_ = 1.0 if tier == 2 else 1.3
        p += [C("pack", -10, -90, -10, -180 * s_, 12, METAL, -34), C("pack", 26, -96, 26, -190 * s_, 12, METAL, -35),
              E("pack", -10, -184 * s_, 9, 9, a, -33, glow=True), E("pack", 26, -194 * s_, 9, 9, a, -33, glow=True)]
    return p


if __name__ == "__main__":
    build("nullbreaker")
