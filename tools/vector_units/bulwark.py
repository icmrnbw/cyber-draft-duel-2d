"""Bulwark, vector. Steel shield anchor with a hammer.
Lv1 domed helmet, tower shield, hammer. Lv2 Aegis Ram: spiked ram-head tower
shield, piston-driven hammer. Lv3 Fortress Pulse: shield unfolds side wings
into an energy barrier, shoulder bastion towers, glowing core."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "bulwark"
HEIGHT = 485
GAIT = {"stride": 0.7, "bounce": 3, "stomp": 8, "sway": 2.5, "lean": 2, "knee": 40, "swing": 4}
STYLE = "ram"
BONES = bones(torso_h=170, shoulder=(34, -122), back_shoulder=(-4, -126))
MUZZLE = {1: (0, 0)}
HOLD = {"uarm_f": 24, "farm_f": -20, "uarm_b": -40, "farm_b": -40, "weapon_tilt": -105}
STRIDE = 0.75
STEEL = (178, 188, 202, 255)
STEEL_D = (96, 104, 120, 255)
DARK = (54, 60, 74, 255)


def parts_for(tier):
    a = accent(tier)
    big = {1: 1.25, 2: 1.3, 3: 1.38}[tier]
    p = standard_limbs(STEEL, DARK, STEEL_D, bulk=big, z_arm_b=36, z_arm_f=30)
    p += [
        E("torso", 0, -4, 44, 28, DARK, 0),
        P("torso", ((-60 * big, -20), (60 * big, -20), (66 * big, -110), (40, -150), (-40, -150), (-64 * big, -110)), STEEL, 1,
          tint=1.05, lines=(((-40, -70), (46, -76)), ((0, -146), (0, -26)))),
        P("torso", ((10, -148), (40, -150), (66 * big, -110), (60 * big, -20), (12, -20)), STEEL, 2, tint=0.84),
        E("torso", 20, -96, 12, 12, DARK, 3),
        E("torso", 20, -96, 7, 7, a, 4, glow=True),
    ]
    if tier == 3:   # bastion towers on the shoulders
        for x in (-50, 40):
            p += [P("torso", ((x - 12, -150), (x + 12, -150), (x + 10, -196), (x - 10, -196)), STEEL_D, -5),
                  P("torso", ((x - 16, -196), (x + 16, -196), (x + 12, -208), (x - 12, -208)), STEEL, -4),
                  E("torso", x, -180, 4, 6, ORANGE, -3, glow=True)]
    p += [
        S("head", ((-56, 18), (-60, -34), (-34, -74), (8, -84), (48, -64), (62, -20), (58, 20), (16, 40), (-36, 36)),
          STEEL, 40, lines=(((-40, -50), (34, -60)),)),
        E("head", -28, 0, 22, 22, STEEL_D, 41),
        P("head", ((4, -20), (62, -16), (60, 4), (6, 4)), DARK, 42),
        G("head", ((10, -12), (58, -9), (58, -3), (10, -4)), a, 43),
    ]
    # Tower shield on the back (leading) arm.
    w, h = 64, 150
    shield = ((-10, -h * 0.55), (w * 0.7, -h * 0.5), (w, -h * 0.2), (w, h * 0.35), (w * 0.4, h * 0.55), (-10, h * 0.45))
    p += [P("shield", shield, STEEL, 44, tint=1.08, lines=(((5, -60), (5, 60)),)),
          P("shield", ((20, -40), (40, -40), (40, 40), (20, 40)), STEEL_D, 45),
          G("shield", ((26, -30), (34, -30), (34, 30), (26, 30)), a, 46)]
    if tier >= 2:   # ram head spikes
        p += [P("shield", ((w, -40), (w + 30, -30), (w, -20)), STEEL_D, 45),
              P("shield", ((w, 10), (w + 30, 20), (w, 30)), STEEL_D, 45)]
    if tier == 3:   # energy barrier wings
        p += [P("shield", ((w * 0.7, -h * 0.5), (w + 20, -h * 0.9), (w + 30, -h * 0.4), (w, -h * 0.2)), (255, 170, 90, 120), 47, glow=True),
              P("shield", ((w * 0.4, h * 0.55), (w + 20, h * 0.95), (w + 30, h * 0.45), (w, h * 0.35)), (255, 170, 90, 120), 47, glow=True)]
    # Hammer in the front hand, behind the shield.
    p += [C("weapon", -20, -4, 70, -4, 6, DARK, 41),
          P("weapon", ((60, -30), (100, -30), (104, 24), (60, 24)), DARK, 42, tint=1.15),
          G("weapon", ((66, -4), (98, -4), (98, 2), (66, 2)), a, 43)]
    if tier >= 2:
        p += [C("weapon", 30, -14, 60, -14, 5, STEEL_D, 42)]
    if tier >= 2:   # ram-head tower shield and a piston-driven hammer
        p += [P("shield", ((w, -60), (w + 46, -40), (w + 54, 0), (w + 46, 40), (w, 60)), STEEL_D, 46, tint=1.05,
                lines=(((w + 10, -30), (w + 40, 0)), ((w + 10, 30), (w + 40, 0)))),
              E("shield", w + 30, 0, 9, 9, a, 47, glow=True),
              P("weapon", ((54, -40), (110, -40), (116, 34), (54, 34)), DARK, 43, tint=1.15),
              C("weapon", 20, -26, 60, -26, 8, STEEL_D, 44), C("weapon", 20, 18, 60, 18, 8, STEEL_D, 44),
              G("weapon", ((24, -28), (56, -28), (56, -24), (24, -24)), a, 45)]
    if tier == 3:   # heavier helm crest
        p += [P("head", ((-40, -70), (-10, -110), (30, -104), (10, -66)), STEEL_D, 44)]
    if tier >= 2:   # shoulder bastion on the lead shoulder
        p += [P("torso", ((-60, -150), (-20, -156), (-24, -210), (-56, -206)), STEEL_D, -6),
              P("torso", ((-66, -206), (-14, -212), (-18, -224), (-62, -220)), STEEL, -5)]
    return p


if __name__ == "__main__":
    build("bulwark")
