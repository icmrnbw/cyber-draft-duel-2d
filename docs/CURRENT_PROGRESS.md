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
