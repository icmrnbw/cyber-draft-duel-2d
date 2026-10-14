"""Field Medic, vector. Teal armoured support with a healing drone.
Lv1 helmet with visor stripe, chest cross, injector pistol, one drone.
Lv2 Aegis Dose: second drone, hex-shield bracer, winged med-pack.
Lv3 Trauma Reset: halo of three drones, energy wing-fins, long injector staff."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "field_medic"
STYLE = "heal"
BONES = bones(torso_h=150)
MUZZLE = {1: (76, -8), 2: (80, -8), 3: (120, -8)}
GRIP = (20, 6)
TEAL = (52, 170, 196, 255)
TEAL_D = (24, 82, 100, 255)
WHITE = (230, 240, 244, 255)
GUN = (60, 70, 84, 255)
HEAL = (110, 255, 190, 255)


def drone(bone, x, y, color, z):
    return [S(bone, ((x - 20, y), (x - 8, y - 14), (x + 12, y - 14), (x + 22, y), (x + 8, y + 12), (x - 10, y + 12)), TEAL, z),
            E(bone, x + 2, y, 7, 7, color, z + 1, glow=True),
            G(bone, ((x - 18, y + 14), (x + 18, y + 14), (x + 12, y + 18), (x - 12, y + 18)), color, z + 1)]


def parts_for(tier):
    a = accent(tier)
    p = standard_limbs(TEAL, TEAL_D, TEAL_D, bulk=1.0)
    if tier >= 2:   # winged med-pack
        p += [S("pack", ((-20, -60), (24, -64), (28, 20), (-22, 22)), WHITE, -30),
              P("pack", ((-6, -40), (6, -40), (6, -4), (-6, -4)), (220, 60, 70, 255), -29),
              P("pack", ((-14, -28), (14, -28), (14, -16), (-14, -16)), (220, 60, 70, 255), -29)]
        for k in (0, 1):
            p.append(S("pack", ((-10, -40 + k * 30), (-70, -80 + k * 30), (-60, -50 + k * 30), (-12, -26 + k * 30)),
                       WHITE if tier == 2 else (255, 200, 140, 200), -32, gloss=0.3))
    if tier == 3:   # energy wing-fins
        for k in range(3):
            p.append(G("pack", ((0, -60 + 26 * k), (-90 - 10 * k, -120 + 30 * k), (-70 - 10 * k, -96 + 30 * k)), ORANGE[:3] + (190,), -33))
    p += [
        E("torso", 0, -4, 36, 24, TEAL_D, 0),
        S("torso", ((-42, -20), (44, -20), (48, -96), (30, -130), (-30, -130), (-46, -96)), TEAL, 1,
          lines=(((-28, -60), (32, -64)),)),
        P("torso", ((-4, -110), (8, -110), (8, -70), (-4, -70)), WHITE, 2),
        P("torso", ((-20, -96), (24, -96), (24, -84), (-20, -84)), WHITE, 2),
        G("torso", ((-30, -40), (36, -42), (36, -36), (-30, -34)), a, 3),
    ]
    p += [
        S("head", ((-58, 16), (-62, -34), (-34, -74), (10, -82), (50, -60), (62, -16), (56, 22), (12, 40), (-38, 34)),
          TEAL, 40, lines=(((-40, -50), (30, -60)),)),
        P("head", ((0, -24), (62, -18), (60, 4), (2, 0)), WHITE, 41, tint=1.1),
        E("head", -30, 4, 14, 14, TEAL_D, 42),
        G("head", ((8, -14), (58, -10), (58, -6), (8, -8)), a, 43),
    ]
    # Drones over the shoulders.
    p += drone("pack", 146, -150, HEAL, 50)
    if tier >= 2:
        p += drone("pack", -4, -166, HEAL, 51)
    if tier == 3:
        p += drone("pack", 176, -70, ORANGE, 52)
    # Hex-shield bracer on the back forearm.
    if tier >= 2:
        hexa = tuple((26 * __import__("math").cos(__import__("math").radians(60 * k + 30)), 20 + 26 * __import__("math").sin(__import__("math").radians(60 * k + 30))) for k in range(6))
        p.append(P("farm_b", hexa, (120, 230, 255, 140) if tier == 2 else (255, 180, 120, 140), -9, glow=True))
    # Injector pistol (Lv1-2) or long injector staff (Lv3).
    if tier < 3:
        p += [P("weapon", ((-20, -10), (40, -14), (44, 4), (-20, 8)), WHITE, 31, tint=1.05),
              C("weapon", 40, -6, 74, -6, 5, GUN, 30), C("weapon", 0, -20, 30, -20, 7, HEAL[:3] + (255,), 32, gloss=0.8),
              P("weapon", ((-6, 6), (8, 6), (4, 28), (-8, 28)), GUN, 29)]
    else:
        p += [C("weapon", -60, -6, 118, -6, 6, WHITE, 31, bevel=0.9),
              C("weapon", 20, -6, 70, -6, 10, HEAL[:3] + (255,), 32, gloss=0.8),
              E("weapon", 118, -6, 10, 10, ORANGE, 33, glow=True)]
    return p


if __name__ == "__main__":
    build("field_medic")
