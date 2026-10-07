# Continuation checkpoint — 2026-10-04

> Superseded by `continuation-originals-2026-10-04.md` for current art coverage,
> Nullbreaker shield piercing, shield-order resolution, tests and the v3 APK.
> The remainder of this file is the earlier checkpoint, retained as history.

The ten-unit expansion remains in progress. This checkpoint supersedes the
October 3 import-blocked status and its premature Bulwark art approval.
No system files were deleted. Generated sources and previous runtime frames
are retained inside the project; art tools reject paths outside the project,
traversal and linked/reparse ancestors, and have no deletion operations.

## Implemented and checked

- Godot imports the new textures successfully.
- Phaseblade no longer retreats out of its own melee range. Lunge movement is
  deferred until all attack/movement decisions finish and stops at contact.
- ArcRelay chains have a finite 3.5m radius and stable target tie ordering.
- Cryotek Lv3 now has a stronger third-hit slow/burst; Bulwark's Lv3 shield lasts
  3.5 seconds versus 2.5 at Lv2. Enforcer has both tier descriptions.
- Detail screens show generic Lv2/Lv3 ability names/descriptions and locks;
  expanded draft/Heroes screens scroll, and all ten units resolve in detail.
- New specials have bounded presentation cues; at most 48 transient ability
  effects exist. Attack animation tweens now belong to their sprite so round
  cleanup cancels late callbacks against freed sprites.
- Five exact drawn attempts consume a life from both teams, then the regular
  result/growth/match-completion route runs. Perfect ties cannot replay forever.
- Smoke now exercises new units and actual tier promotions and fails on a
  nonterminal simulation or exhausted safety limit.
- The balance harness covers all tiers, duels, archetypes, dense squads,
  controlled fourth slots and fresh/unlocked progression. See the separate
  balance report for measured outliers and the retained small control buff.

## Art in this checkpoint

Using the built-in image generator, generated and wired Enforcer Lv2 retreat
and Lv3 attack, walk and retreat: **four sheets / sixteen 512px runtime frames**.
Exact prompts, reference roles in the prompts, output filenames and rejected
attempts are retained in `art_sources/2026-10-04/generation-record.json`.
Two retreat attempts failed alternating-leg review; one attack failed cell
clearance. Those sources were retained and never wired. Selected retreat sheets
use crop order 1,4,3,2 to reverse the alternating gait. Source/contact-sheet QA
verified both tonfas, tier-specific shoulder design, alpha, cell clearance and
common per-sheet scaling. Boundary exceptions concern alpha-1 generator residue,
not clipped geometry. Godot frame-cycle evidence is recorded under builds.

Current integrity count: **84/120 explicit sets**, comprising **36 manifested**
and **48 legacy** sets, with **36 missing**. There are 9 manifests, 37 entries,
36 unique source sheets and 144 manifested runtime frames. Wiring is not final
visual approval. The original Trooper/Demolitionist/Medic still need **18** tier
action replacements, and all **9** Bulwark action sets need canon/motion rework.

## Verification evidence

| Check | Result | Log / artifact under builds/ |
|---|---|---|
| Ten-unit ability/replay tests after tuning | PASS 327 | ability-after-tune-20261004.log |
| Sim, draw cap, lunge/order/reset regressions | PASS 94 | sim-draw-regression-20261004.log |
| Draft combinations and seeded sampling | PASS 210 hands, 512 samples, all ten units | draft-regression-20261004.log |
| New-unit progression smoke | PASS, 3 rounds and 3 promotions | smoke-20261004.log |
| Production draw routing and animation cleanup | PASS, 3 result screens, 2 growth routes, 1 match end; no surviving tween | round-flow-cleanup-20261004.log |
| Heroes/draft/detail scenes | PASS 40 checks; screenshots retained | ui-roster-preview-20261004.log, ui-preview/ |
| Full balance baseline | PASS 2,219 battles / 96 matches | balance-baseline-v2-20261004.json |
| Control adjustment comparison | PASS 1,008 squad battles | balance-control-tune-20261004.json |
| Progression after adjustment | PASS 96 matches / 400 round battles | balance-progression-after-20261004.json |
| Focused Phaseblade rendering after cleanup fix | PASS, 3 lunges/marks, peak 4/48 effects, cleanup true | phase-fixed-20261004.log |
| Dense 80-unit rendering | PASS 720 ticks, peak 48/48, cleanup true | dense80-20261004.log |
| Art source/pixel/wiring integrity | PASS; incomplete coverage correctly reported | art-inventory-final-20261004.json |
| Enforcer all tiers/states, four frame positions | PASS capture; inspected all four contact views | enforcer-final-preview-20261004.log, enforcer-final-20261004-frame0.png through frame3.png |
| Android debug export | PASS signed and verified; desktop build only | android-export-v2-20261004.log |

The first broad ability preview completed at tick812 but exited1 because it
did not trigger lunge before Phaseblade died. Its other screenshots are useful
evidence, not a pass for all required effects. The focused preview then triggered
lunge but exposed a freed-sprite callback. The corrected `phase-fixed` run is
clean. The dense run was still in progress at720 ticks: it is bounded rendering
stress evidence, not a completed match or Android device-performance result.
Later focused/dense previews used desktop OpenGL compatibility; the earlier
broad preview used the project's mobile Vulkan renderer.

The Enforcer previews show all six tier-action replacements with no old flat
frames. Full movement polish remains separate: the attack body appears smaller
than idle because the frame reserves room for the raised weapon. Dense preview
screenshots show readable individual effects but substantial overlapping bars,
labels and ground patches; crowd readability still needs refinement.

Android checkpoint: `builds/cyber-draft-duel-2d-20261004-v2-debug.apk`,
93,899,303 bytes, SHA256
`f509921e776593e6620042b9e411ab557c0c2b3c8d49ae0e5f4f9500b9da285d`.
The initial export succeeded with a missing-icon diagnostic. Setting the existing
project swords icon removed that diagnostic; the v2 export log is clean and
Godot signed/verified the APK. ZIP inspection found no tools/, art_sources/ or
builds/ entries among919 entries. No device installation was attempted.

## Reproduction

Executable used:
`C:\Users\rnast\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`

From the project directory, assign that path to `$godot`, then use:

```powershell
& $godot --path . --headless --editor --import
& $godot --path . --headless --script res://tools/ability_regression_test.gd
& $godot --path . --headless --script res://tools/sim_regression_test.gd
& $godot --path . --headless --script res://tools/draft_regression_test.gd
& $godot --path . --headless --script res://tools/round_smoke_test.gd
& $godot --path . --headless res://tools/round_flow_regression.tscn
& $godot --path . --resolution 720x1280 res://tools/ui_roster_preview.tscn
& $godot --path . --rendering-method gl_compatibility --fixed-fps 60 --resolution 720x1280 res://tools/ability_preview.tscn -- --unit=phaseblade --ticks=1000 --require=lunge,mark
& $godot --path . --rendering-method gl_compatibility --fixed-fps 60 --resolution 720x1280 res://tools/ability_preview.tscn -- --dense --ticks=720
& $godot --path . --rendering-method gl_compatibility --resolution 720x1280 res://tools/roster_preview.tscn -- --unit=enforcer --capture-cycle --out=res://builds/enforcer-final.png
python -B tools/verify_art_inventory.py --json builds/art-inventory-final-20261004.json
& $godot --path . --headless --export-debug Android builds/cyber-draft-duel-2d-20261004-v2-debug.apk
```

Per-run logs use `--log-file` with the corresponding builds path in the table.
The selected manifest imports use `python -B tools/slice_sheets.py --manifest
art_sources/2026-10-04/<manifest>.json --apply --wire` after dry-run/contact review.

## Remaining stages

1. Original art: Trooper, Demolitionist and Medic Lv2/Lv3 attack/walk/retreat (18).
2. New-unit art: Phaseblade/Cryotek/ArcRelay/Nullbreaker action states (36), plus
   Bulwark action canon/foot-cycle rework (9); retain approved idle references.
3. Finish runtime motion/VFX and small-screen visual review for every slot;
   current effect cues are implemented but not a complete generated VFX library.
4. More balance iterations, especially dense area sustain, control viability,
   duplication/promotion value and bot difficulty. Nullbreaker's charged/mark
   role still overlaps Marksman; it does not currently bypass shields or armor.
5. Final integrated regression and an updated Android artifact after completion;
   actual device performance remains unverified. Keep QA/source/cache out of export.
6. Consolidate final design matrix, coverage, test/balance reports and logical
   commits. Existing README/HANDOFF edits were preserved; no commit was made.
