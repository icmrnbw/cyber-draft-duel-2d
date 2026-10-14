# Live continuation checklist

Updated: 2026-10-04, start of new-unit action batch.

Last verified checkpoint: `continuation-originals-2026-10-04.md`.
Playable Android artifact: `builds/cyber-draft-duel-2d-20261004-v3-debug.apk`.

## Current work

- Root: Bulwark nine canonical action reworks, then Cryotek nine missing sets.
- Phaseblade: nine action sets in progress, one reviewed import at a time.
- ArcRelay: nine action sets in progress, one reviewed import at a time.
- Nullbreaker: nine action sets in progress, one reviewed import at a time.

Starting inventory: 84/120 explicit sets (54 manifested, 30 retained, 36 absent).
Bulwark's nine existing action sets require rework, so **45 sets / 180 frames**
remain to generate or replace. A source generation alone does not reduce this
count; reviewed source/slice, wiring and real Godot evidence are separate gates.

## After action art

1. Cross-state body scale (particularly Demo Lv2/Medic/Enforcer attacks), retained
   Lv1 Trooper alpha artifact, motion/VFX and dense small-screen readability.
2. Balance: control/area-sustain, doubling versus promotion value and bot difficulty.
3. Integrated regressions, final visual evidence and updated Android export;
   actual device performance remains unverified. Finish design/coverage/test/
   balance reports and logical commits. Preserve prior README/HANDOFF edits.

All sources, rejected attempts, previous runtime frames and APKs are retained.
No system-file deletion is authorized. No deletion commands are used.
Usage limits can interrupt without advance warning; save source/provenance and
per-unit progress immediately after each result.

## 2026-10-07 integration checkpoint

- All new PNGs imported (two headless editor passes; second pass clean).
- Headless suites pass: sim (231), ability (389), draft (210 hands), round smoke,
  round flow. Windowed `roster_preview` captured for all five new units and a
  live match screenshot; nothing failed to load.
- Phaseblade Lv3 attack applied from `art_sources/2026-10-07/phaseblade/lv3_attack_compact.png`
  (`lv3_attack_manifest.json`, zero slicer warnings) and wired; previously it fell
  back to Lv2 attack art.
- Art inventory: 95/120 explicit sets (65 manifest, 30 legacy, 25 missing).
- Still open: ArcRelay Lv1 walk needs moving-loop approval before wiring, then
  ArcRelay Lv2/Lv3 walk and all retreats; Phaseblade walk/retreat; Cryotek
  actions; Nullbreaker retreats and Lv3 attack; Bulwark action rework.

## 2026-10-07 action-frame scale lock

Per-sheet fitting into 512 px shrank action bodies against idle (Demolitionist
Lv2 idle 487 px vs attack 321 px; walks/retreats ~10-20% smaller). Manifest
entries for attack/walk/retreat now carry `"scale_lock": "idle"`: the slicer
scales the sheet so its median frame height equals the same tier's runtime idle
median height, and grows the canvas symmetrically past 512 px when a pose needs
room (feet stay at the same screen point under a centered Sprite2D). All 50
manifested action sets were re-applied; the audit and Godot captures
(`builds/qa-scale/`) confirm. Legacy Lv1 actions of the original five units have
no source manifest and were not touched.

Follow-up the same day (QA review): action feet now land on the tier's measured
idle foot line (older idles stand at ~491-512 px, not 481), removing a 20-29 px
jump on state changes. Median-height matching over-enlarged crouched/braced
poses, so 18 sets carry a reviewed `body_scale` derived from helmet-crown width
versus idle (documented per entry). Not applied to Bulwark (actions use a
different helmet; flagged for rework), ArcRelay (staff above head) or Trooper
(antenna), where the measurement is not valid.

## 2026-10-14 code-derived stand-ins and prompts

All 25 missing sets now have code-derived stand-ins (`tools/derive_frames.py`,
record in `art_sources/derived-2026-10-14/derived_record.json`): Cryotek all
actions and ArcRelay/Phaseblade walk/retreat from idle (leg scissor, bob, lean,
recoil, muzzle flash); Nullbreaker retreat from its own walk reversed with a
backward lean; Nullbreaker Lv3 attack from Lv2 attack with cyan->orange and the
Lv2->Lv3 idle colour shift. They are not generated art: the audit reports them as placeholders (95 real + 25 placeholder). The generator only rewrites frames whose bytes still match the hash it recorded, so imported art is never overwritten. Phaseblade/ArcRelay stand-ins use bob/lean/sway without the leg scissor (it tore the blade and doubled the staff).
Ready-to-paste prompts per sheet: `art_sources/prompts-2026-10-14/`; drop
results in `art_sources/incoming/` and run `tools/import_incoming.py`.

## 2026-10-14 vector roster (owner decision)

The owner chose code-drawn vector art for consistency and no generator
artifacts. `tools/vector_art.py` renders rigged parts with gradient shading,
bevels, gloss, panel lines and glow; `tools/vector_units/<unit>.py` defines each
unit's parts for three distinct tier designs (docs/tier-designs.md) on a shared
side-view rig (`common.py`) with 8-frame eased animations: idle, walk, retreat
and a per-unit attack (smash, burst, snipe, lob, heal, ram, slash, cryo spray,
chain lightning, rail). `tools/vector_units/export.py` copies frames to
`assets/vector/` and wires all 120 sets plus each unit's portrait sprite; the
audit reports them as `vector` (hashes in art_sources/vector-2026-10-14/).
Painted frames remain on disk but are unreferenced and excluded from export.
The game times 8-frame sets by the unit's attack rhythm and walk distance.
The team shader's saturation boost was lowered for the vivid vector palette.

QA follow-up (same day): tiers grow x1.07/x1.14 and add new parts per unit
(Lv1->Lv2 silhouette change 21-33%, Lv1->Lv3 37-50%, measured by
tools/vector_units/silhouette.py); per-unit height (tanks ~485-490 px,
skirmishers ~425-430) and gait (stride, bounce, stomp, sway, lean, knee);
ranged attacks brace, recoil, slide the back foot and kick the weapon, with
style moves (spray sweep, lob heave, staff raise-and-thrust, heal step-in) and
ejected casings. The 483 unreferenced painted runtime frames moved to
art_sources/legacy-runtime/ (under .gdignore), so a fresh clone never imports
or exports them regardless of export preset.
