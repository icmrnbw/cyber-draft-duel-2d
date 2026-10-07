# Original-unit art checkpoint — 2026-10-04

The original 30-set Lv2/Lv3 attack/walk/retreat replacement batch is now fully
wired. The ten-unit expansion remains unfinished. This checkpoint supersedes
the earlier October 4 checkpoint for current counts and fixes.

## Work completed in the resumed pass

- Generated and wired Trooper, Demolitionist and Field Medic's remaining 18
  tier-action sheets: **72 512px runtime frames**. Canonical idles and original
  Lv1 actions remain. All selected sources and normalized frames were inspected.
- Imported those frames in Godot and captured/inspected all four frame positions
  across each unit's three tiers and four states. Sources, exact prompts and
  rejected attempts are retained. Provenance index:
  `art_sources/2026-10-04/original-actions-generation-record.json`.
- Nullbreaker now bypasses shields with 80% of its Lv2+ charged-shot damage;
  ordinary and unshielded damage remain unchanged. The generic definition,
  deferred damage queue and exact tests carry the behavior. Its detail screen
  describes the mechanic and derives a shield-piercing tag from the data.
- Fixed simultaneous shields with different caps depending on source order:
  resolve lower-cap contributions first, then higher-cap contributions. Each
  source retains its cap and cannot shrink stronger existing protection.
- The safe wiring tool consolidated duplicate declarations in the three
  original resources. Runtime predecessors and resource snapshots remain in
  `art_sources/previous/`. No files were deleted, including system files.
- UI QA accepts a fresh `--out-dir=` so earlier screenshots remain intact.

## Current art count and visual limits

**84/120 explicit sets: 54 manifested, 30 retained, 36 missing.** The 54
manifested sets comprise all 30 original-unit tier actions, 15 canonical new-unit
idles and 9 Bulwark action sets that still require rework. There are 17 manifests,
55 entries, 54 unique sheets and 216 manifested runtime frames. The duplicate
Marksman source explains the extra entry; three old alpha-1 audit warnings remain.

Source/wiring integrity and successful rendering are not final movement approval.
The new Trooper cycles alternate near/far legs and preserve its rifle and helmet.
Medic keeps one drone/syringe; Demolitionist keeps its single drum launcher and
canister. Medic cast sheets use nonoverlapping custom crops; the Lv3 top-row
split retains the complete silhouette with a documented <=5/255 fringe exception.

Visible follow-up: attack bodies can appear smaller than idle because the common
sheet scale reserves room for weapon/effect extent. Demolitionist Lv2 is the most
obvious new example; Medic and previously generated Enforcer also need this
review. Existing Lv1 Trooper fire has a rectangular alpha-outline artifact.
Dense battles still need bar/label/effect readability work. These are open
polish items, not silently accepted as final quality.

## Verification

All logs/artifacts below are under `builds/`.

| Check | Result | Evidence |
|---|---|---|
| Godot import | Pass, clean log | `original-actions-import-20261004.log` |
| Ability regressions | Pass 389 | `shield-order-ability-resume-20261004.log` |
| Simulation regressions | Pass 231 | `shield-order-sim-resume-20261004.log` |
| Final shield-order balance panel | Pass 1,008 battles / 336 rows; no failures/timeouts | `shield-order-balance-20261004.json` |
| Progression smoke | Pass 4 rounds / 5 promotions | `smoke-originals-20261004.log` |
| Production draw route and animation cleanup | Pass 3 results / 2 growth routes / 1 match end | `round-flow-originals-20261004.log` |
| Heroes, draft and all ten detail screens | Pass 40 checks, Nullbreaker screenshot inspected | `ui-originals-20261004.log`, `ui-originals-20261004/` |
| Art source/pixel/wiring inventory | Pass, 36 missing correctly reported | `art-inventory-originals-20261004.json` |
| Trooper/Medic/Demolitionist tier/state rendering | Pass capture; all 12 images inspected | `{trooper,medic,demo}-originals-20261004-frame{0,1,2,3}.png` and corresponding preview logs |
| Android debug export/sign/verify | Pass, clean log | `android-originals-export-20261004.log` |
| Whitespace check | Pass | `git -c core.safecrlf=false diff --check` |

The final balance panel exactly matches the preceding 80% Nullbreaker panel's
aggregate results and durations. The targeted mixed-cap tests cover the fixed
edge case; unchanged sample wins do not establish final balance. See
`nullbreaker-role-2026-10-04.md` and `balance-2026-10-04.md`.

APK: `builds/cyber-draft-duel-2d-20261004-v3-debug.apk`, **94,919,207 bytes**.
SHA256: `ff9f209a20eddc18e71a6d109b350e591903f9261fd64b99049ef048508f91d6`.
ZIP inspection found 919 entries and no `art_sources/`, `tools/` or `builds/`
entries. Previous APKs remain. No installation or device-performance test was
performed, and no real player progression was changed. This is a debug checkpoint.

## Reproduction

Use the installed Godot 4.7.1 console executable with `--path .` from the project
directory. Add `--log-file builds/<fresh-name>.log` to each invocation:

```powershell
& $godot --path . --headless --editor --import
& $godot --path . --headless --script res://tools/ability_regression_test.gd
& $godot --path . --headless --script res://tools/sim_regression_test.gd
& $godot --path . --headless --script res://tools/balance_harness.gd -- --suite=squads --report=res://builds/shield-order-next.json
& $godot --path . --headless --script res://tools/round_smoke_test.gd
& $godot --path . --headless res://tools/round_flow_regression.tscn
& $godot --path . --rendering-method gl_compatibility --fixed-fps 60 --resolution 720x1280 res://tools/roster_preview.tscn -- --unit=trooper --capture-cycle --out=res://builds/trooper-next.png
& $godot --path . --rendering-method gl_compatibility --fixed-fps 60 --resolution 720x1280 res://tools/ui_roster_preview.tscn -- --out-dir=res://builds/ui-next
python -B tools/verify_art_inventory.py --json builds/art-inventory-next.json
& $godot --path . --headless --export-debug Android builds/cyber-draft-duel-next-debug.apk
```

Repeat the roster-preview invocation with `--unit=field_medic` and
`--unit=demolitionist`, each with a fresh output prefix. Source imports used
`python -B tools/slice_sheets.py --manifest art_sources/2026-10-04/<manifest>.json`
for dry-run/contact inspection followed by `--apply --wire`. Selected manifests
are the six Trooper manifests plus `field_medic_manifest.json` and
`demolitionist_manifest.json`.

## Three remaining stages

1. **Complete new-unit art:** 36 action sets for Phaseblade, Cryotek, ArcRelay
   and Nullbreaker, plus 9 Bulwark canon/gait reworks: **45 sets / 180 frames**.
   Each needs source, slice, identity/motion and real Godot review. Keep approved
   idles and rejected attempts; do not count procedural fallback as completion.
2. **Polish and balance:** correct cross-state body scale and retained alpha
   artifacts; review all abilities and small-screen/dense readability; continue
   control/area-sustain/duplication-versus-promotion/bot-difficulty comparisons.
   Current procedural ability cues are not a complete generated VFX library.
3. **Final validation and handoff:** integrated regressions and visual evidence,
   updated Android export and actual device checks when available, consolidated
   final design/coverage/test/balance reports and logical commits. Existing
   README/HANDOFF edits are preserved. No commits were made in this pass.

Parallel agents hit their usage limit after saving partial files. The root
recovered and reviewed them, generated the missing Medic Lv3 cast and Demo Lv3
retreat, and finished the original-unit batch and verification. No unfinished
agent report was counted as a completed asset or test.
