# Ten-unit roster design

This document is the data contract for the expanded draft roster. Every entry is
a `UnitDefinition`, so the simulator stays generic: a unit's level abilities are
declared in its `.tres` resource and resolved by `BattleSim` without unit-name
branches.

| Unit | Type | Job | Base profile | Lv2 | Lv3 |
|---|---|---|---|---|---|
| Enforcer | Melee | Front-line tank | Durable close-range pressure | Heavy Strikes: chance to stagger on hit | Berserk: faster attacks as HP falls |
| Trooper | Mid | Generalist rifle | Reliable mid-range damage | Burst Protocol: every fourth attack fires three reduced hits | Suppressive Volley: the burst suppresses outgoing damage |
| Marksman | Long | Single-target finisher | Slow, high-damage ranged shots | Charged Round: every third shot deals increased damage | Target Lock: charged shots mark the target for amplified follow-up damage |
| Demolitionist | Mid | Area denial | Splash damage controls clusters | Firestorm: splash attacks leave a damaging ground patch | Scorched Ground: patches slow enemies |
| Field Medic | Support | Sustain | Heals the most injured non-support ally | Aegis Dose: heals grant a capped expiring shield | Trauma Reset: heals cleanse control and grant short immunity |
| Bulwark | Melee | Protector | High-health shield anchor | Aegis Ram: every fourth hit deals extra damage and grants a 2.5s self-shield | Fortress Pulse: shield lasts 3.5s and the empowered hit briefly suppresses the target |
| Phaseblade | Melee | Mobile disruptor | Fast, fragile close-range threat | Phase Lunge: every third hit deals extra damage and lunges toward the target | Rift Mark: lunging hits mark the target |
| Cryotek | Mid | Area control | Splash projector with moderate range | Cryo Lock: hits slow by 24% for 1.25s | Thermal Collapse: every third hit deals extra impact and slows by 42% for 1.6s |
| ArcRelay | Mid | Anti-swarm control | Mid-range chain specialist | Arc Chain: every fourth hit jumps to two nearby enemies for reduced damage | Signal Jam: chained targets are briefly suppressed |
| Nullbreaker | Long | Shield-piercing finisher | Very long range, slow charged damage | Piercing Charge: every third shot deals 175% damage; 80% bypasses shields | Expose Core: charged shots mark the target |

The roster keeps four draft slots. A hand must contain four distinct resources
from the ten registered resources; duplicate copies are created only by the
between-round growth system. Named bot archetypes remain four-card legal hands,
while seeded sampling can draw any valid four-of-ten combination.

## Art coverage

The production resolver already supports four states (`idle`, `attack`, `walk`,
`retreat`) and three tier overrides. The original five units have their base
state art; all five now have generated replacements for all six tier action
states, with source/contact-sheet review. The final eighteen Trooper,
Demolitionist and Field Medic sets were also imported and captured across four
frame positions in Godot. Runtime evidence remains separate from final
movement and cross-state scale approval.
The five new units currently have reviewed four-frame idle sheets for Lv1, Lv2,
and Lv3 (15 sheets / 60 runtime frames). Bulwark has nine wired action sheets
(36 runtime frames), but all nine failed independent identity/foot-cycle review
and require regeneration from canonical idle references. All
action states for the other four new units remain empty until each generated
sheet passes the same boundary, foot-baseline, and contact-sheet review. Empty
action arrays use the existing procedural presentation fallback and do not block
simulation or draft logic.

All generated source sheets stay in dated folders under `art_sources/`; runtime slices
are written under `assets/`. The slicer preserves alpha, uses one scale and foot
baseline per sheet, and keeps project-local content-hash backups before replacing
an existing runtime frame.

## Tuning constraints

The new units are deliberately complementary rather than strictly stronger:

- Bulwark buys time and protects itself, but has the lowest movement speed among
  melee units.
- Phaseblade creates pressure through movement, but has low health and no area
  damage.
- Cryotek and ArcRelay control groups, with lower single-target damage than a
  Marksman or Nullbreaker.
- Nullbreaker applies shield-piercing charged pressure at long range, balanced
  by a long attack interval and low health. A generic damage partition bypasses
  shields on its periodic Lv2+ special; ordinary and unshielded damage are
  unchanged. Marksman's shots retain normal shield absorption. See
  `nullbreaker-role-2026-10-04.md` for exact tests and the sampled balance limit.

The first expanded pass has run against loaded resources: 2,219 baseline
battles and a 1,008-battle controlled tuning comparison. See
`balance-2026-10-04.md` for methods, outliers and the ArcRelay/Cryotek adjustment.
Final balance, progression-policy comparison and larger samples remain open.
