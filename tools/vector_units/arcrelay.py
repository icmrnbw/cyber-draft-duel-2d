"""ArcRelay, vector. Graphite-helmed caster in a copper-edged long coat with a
relay backpack and a two-prong staff.
Lv2 Arc Chain: backpack pylons extend arcing antennas.
Lv3 Signal Jam: relay nodes float and orbit, the staff fork becomes a
three-prong lightning crown, coat flares open."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import ORANGE, C, E, G, P, S, accent, bones, build, standard_limbs  # noqa: E402

NAME = "arcrelay"
HEIGHT = 445
GAIT = {"stride": 0.9, "bounce": 6, "lean": 4, "swing": 6, "knee": 54}
STYLE = "chain"
BONES = bones(torso_h=150)
MUZZLE = {1: (20, -130), 2: (20, -130), 3: (20, -140)}
HOLD = {"uarm_f": -20, "farm_f": -40}
GRAPHITE = (70, 76, 90, 255)
GRAPHITE_D = (40, 44, 56, 255)
COPPER = (196, 120, 70, 255)
COAT = (52, 54, 64, 255)


def parts_for(tier):
    a = accent(tier)
    p = standard_limbs(GRAPHITE, GRAPHITE_D, GRAPHITE_D, bulk=0.95)
    flare = 1.0 if tier < 3 else 1.4
    coat = ((-34, -120), (30, -124), (40 * flare, 40), (10, 70), (-30, 66), (-60 * flare, 50))
    p += [P("torso", coat, COAT, -2, tint=0.95, lines=((( -10, -40), (-14, 60)),)),
          P("torso", ((-60 * flare, 50), (-30, 66), (-28, 58), (-56 * flare, 42)), COPPER, -1)]
    # Relay backpack: triangle frame with glowing nodes.
    p += [P("pack", ((-30, 20), (24, 20), (0, -70)), GRAPHITE_D, -30, tint=1.0),
          *[E("pack", x, y, 8, 8, a, -29, glow=True) for x, y in ((-24, 16), (20, 16), (0, -62))]]
    if tier >= 2:
        p += [C("pack", -24, 16, -40, -110, 3, COPPER, -31), C("pack", 20, 16, 30, -120, 3, COPPER, -31),
              G("pack", ((-40, -110), (-28, -128), (-34, -112), (-20, -132), (-30, -108)), a, -30),
              G("pack", ((30, -120), (42, -138), (36, -122), (50, -142), (40, -118)), a, -30)]
    if tier == 3:   # orbiting relay nodes
        for x, y in ((-90, -120), (110, -170), (-60, -230)):
            p += [P("pack", ((x, y - 14), (x + 12, y + 8), (x - 12, y + 8)), GRAPHITE_D, 40), E("pack", x, y, 5, 5, ORANGE, 41, glow=True)]
    p += [
        E("torso", 0, -4, 34, 22, GRAPHITE_D, 0),
        P("torso", ((-40, -20), (42, -20), (46, -96), (30, -130), (-30, -130), (-44, -96)), GRAPHITE, 1, tint=1.04,
          lines=(((-26, -60), (30, -64)),)),
        P("torso", ((-6, -126), (6, -126), (6, -24), (-6, -24)), COPPER, 2),
        E("torso", 20, -92, 8, 8, a, 3, glow=True),
    ]
    p += [
        S("head", ((-56, 16), (-60, -34), (-34, -74), (8, -82), (48, -62), (62, -18), (56, 20), (12, 38), (-36, 34)),
          GRAPHITE, 40, lines=(((-40, -50), (30, -58)),)),
        P("head", ((4, -22), (62, -16), (60, 6), (6, 6)), (30, 34, 44, 255), 41, gloss=0.6),
        G("head", ((10, -12), (58, -8), (58, -2), (10, -4)), a, 42),
        E("head", -30, 4, 14, 14, GRAPHITE_D, 42), E("head", -30, 4, 6, 6, a, 43, glow=True),
    ]
    # Staff held upright: shaft, copper fork (two prongs; three at Lv3).
    p += [C("weapon", 20, 60, 20, -110, 5, GRAPHITE_D, 33, bevel=0.8),
          G("weapon", ((17, 40), (23, 40), (23, -100), (17, -100)), a, 34)]
    prongs = (-14, 14) if tier < 3 else (-18, 0, 18)
    p += [C("weapon", 20 + dx * 0.4, -108, 20 + dx, -138, 4, COPPER, 35) for dx in prongs]
    p += [C("weapon", 20 + min(prongs), -108, 20 + max(prongs), -108, 4, COPPER, 35)]
    if tier >= 2:   # shoulder coil rings and a high collar
        p += [E("uarm_f", 0, 0, 22, 22, COPPER, 38), E("uarm_f", 0, 0, 12, 12, GRAPHITE_D, 39), E("uarm_f", 0, 0, 6, 6, a, 40, glow=True),
              P("torso", ((-40, -150), (40, -156), (34, -120), (-34, -116)), COPPER, 6, tint=0.9),
              C("pack", -20, -40, -50, -170, 4, COPPER, -33), G("pack", ((-56, -170), (-44, -194), (-46, -172), (-34, -190), (-42, -168)), a, -32)]
    if tier == 3:   # signal halo behind the head
        import math
        p += [E("head", -20 + 78 * math.cos(math.radians(a_)), -10 + 78 * math.sin(math.radians(a_)), 6, 6, ORANGE, 30, glow=True)
              for a_ in range(0, 360, 30)]
    return p


if __name__ == "__main__":
    build("arcrelay")
