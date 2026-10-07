# Ten-unit continuation — working record

> Historical October 3 snapshot. See `continuation-2026-10-04.md` for current
> verified results. Import now works. The earlier Bulwark action acceptance
> below was revoked by independent identity/motion review: all nine action
> sets require rework. The old inventory counted 33 manifest entries but only
> 32 unique source sheets; it did not prove visual approval.

This is an in-progress record, not a completion claim. The registered roster now
has ten unit types, but the requested complete 120-set art coverage and final
ten-unit balance pass are not yet finished.

## Safety and initial state

The owner prohibits deleting system files. No deletion commands are used in this work. Art tools have no delete operation and reject writes outside this project, traversal, alternate streams, and linked/reparse ancestors. Canonical references and generated source sheets are retained. Existing runtime art is backed up before approved replacement.

Initial branch: `master`, HEAD `5169fb9`. Pre-existing changes were a modified README and untracked HANDOFF.md; these belong to the owner and are preserved.

## Verified baseline

Godot executable used below:

`C:\Users\rnast\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`

Each invocation used `--path D:\vapecoder\cyber-draft-duel-2d`.

| Arguments | Observed result |
|---|---|
| `--headless --editor --quit-after 30` | Exit 0, Godot 4.7.1 import completed |
| `--headless --script tools/round_smoke_test.gd` | Exit 0, five-round match completed, lives A=0/B=1 |
| `--headless --script tools/balance_harness.gd` | Exit 0, 800 multi-round matches, zero draws |
| `--resolution 720x1280 --quit-after 240 res://tools/screenshot_tool.tscn -- --scene=res://scenes/match.tscn --auto_deploy --out=D:/vapecoder/cyber-draft-duel-2d/builds/baseline-match-20261003.png` | Scene launched; PNG save failed because directory did not exist. Old tool incorrectly printed SAVED and exited 0. This is not a successful screenshot test. |
| Same screenshot command with `--out=D:/vapecoder/builds/baseline-match-20261003.png` | Exit 0; PNG exists and was visually inspected. Subsequent tool changes restrict outputs to project builds/. |

Baseline win rates (320 participations per hand; 800 total matches): no Demolitionist 57.2%, no Marksman 55.3%, no Enforcer 49.7%, no Field Medic 45.9%, no Trooper 41.9%. Spread 15.3 percentage points, side-A decisive win share 47.9%. This baseline measured base-tier combat only, not the new tier abilities. It is not evidence of ten-unit balance.

## Implemented work awaiting full integration review

- Five new data-driven resources are registered: Bulwark, Phaseblade, Cryotek,
  ArcRelay, and Nullbreaker. Their base stats, tier metadata, and generic
  special/mark/slow/chain/lunge/self-shield fields are authored in
  `resources/*.tres` and exposed through `UnitDatabase.roster()`.
- Fifteen canonical idle source sheets (Lv1/Lv2/Lv3 for each new unit) were
  generated, reviewed for panel boundaries and foot alignment, retained under
  `art_sources/2026-10-03/`, and sliced into 60 alpha-preserving runtime frames.
- Bulwark received a second, smaller attack-sheet generation after the first
  candidate failed the boundary check; the revised Lv1/Lv2/Lv3 attack, walk,
  and retreat sets passed the same review and are wired into
  `resources/bulwark.tres`. The rejected first attack source remains
  project-local for audit and was never wired.
- The draft and Heroes screens already use scrollable card/grid containers, so
  the ten-unit roster does not require a new scene or a replacement UI flow.
- `tools/balance_harness.gd` now uses legal four-card archetypes plus a
  deterministic sample of the 210 possible four-of-ten hands, and reports both
  per-hand and per-unit participation win rates. It has not been rerun after
  the new resources because the Godot importer is currently unavailable.

- Simulator reset clears persistent hazards and pending effects; round reset clears draw retry.
- Stagger is deferred until both teams' attack decisions finish, preventing same-tick retaliation bias.
- Fire damage uses exact remaining lifetime and counts as combat activity for stalemate detection.
- Generic periodic special attacks, outgoing-damage suppression, vulnerability marks, capped expiring heal shields, cleansing/control immunity, and fire slow.
- Trooper: Burst Protocol / Suppressive Volley; Marksman: Charged Round / Target Lock; Medic: Aegis Dose / Trauma Reset; Demolitionist: Firestorm / Scorched Ground.
- Tier portraits prefer tier idle frames, retaining resolver fallback.
- Presentation-only bounded transient effects, shield texture, status overlays and Berserk visual cadence.
- Safe explicit art manifests, alpha-preserving 512px slicing, common per-sheet scale, source retention and idempotent wiring.
- Dev-only `roster_preview.tscn` and `ability_preview.tscn`, using production unit views and shaders without match rewards or progression changes.

## Validation findings

The simulator baseline fixes passed `tools/sim_regression_test.gd` (46 checks) and the five-round smoke test. Log files are in ignored project `builds/`.

The Python art-pipeline suite currently passes all 13 checks, including alpha
preservation, boundary rejection, deterministic scaling, backup safety, and
idempotent wiring. The new-unit slices were created by that guarded pipeline.
`tools/verify_art_inventory.py` also passes: five manifests, 33 reviewed sheets,
and 128 unique 512px runtime frames have present source/resource/output paths.

The first full-tier visual battle exposed a serialization defect: custom ability fields placed before a `.tres` script assignment were ignored by Godot. The script assignment was moved immediately after `[resource]` in all four changed resources. The corrected real Godot preview then completed at tick 633 (winner B, exit 0), reporting 8 bursts, 2 suppressions, 4 charged attacks, 4 marks, 14 shields, 14 cleanses, 18 slow applications, 12 fire patches and 2 staggers. Captures for all eight new/status event categories were saved under `builds/ability-preview/`; shield, burst and mark screenshots were inspected. This confirms actual activation, not final tuning or complete art.

Command: `--resolution 720x1280 --quit-after 1800 res://tools/ability_preview.tscn -- --ticks=720`.

The dense preview (`--resolution 720x1280 --fixed-fps 60 --quit-after 1800 res://tools/ability_preview.tscn -- --dense --ticks=720`) ran 720 ticks with 40 starting units and exited 0. It captured all ten requested effect categories, including Firestorm and Berserk; final node count 495. The simulation was still in progress at the capture limit, so this is a bounded rendering/stress run, not a completed-match result or Android performance measurement.

The first Enforcer Lv2 attack sheet was rejected for cross-cell overlap. A second sheet can be sliced safely with explicit non-overlapping rectangles. The first walk sheet was rejected for repeating the same leading leg; its replacement alternates feet. Two retreat variants were rejected for poor foot progression or facing reversal. Whole-sheet review alone does not establish final animation quality.

The first headless Godot run after registering the five new resources reported
`No loader found for resource: res://assets/<new-unit>_*.png`: the generated PNG
files exist, but this headless script invocation has not produced Godot's
editor-side `.import`/compressed texture entries for them. Consequently the
post-expansion Godot ability run is not considered valid yet; its printed
original-roster count must not be read as ten-unit verification. The next
integration step is a project-local Godot editor import, followed by the
ten-unit draft, ability, simulation, smoke, screenshot, and balance runs.
The reused `builds/ability-regression-20261003.log` therefore contains the
import errors and a stale prior tail; it is not a clean ten-unit result.
`tools/import_generated_textures.ps1` records that import step with a project
root guard and no deletion operation.

New-unit action art, remaining original-unit art, final 120-set coverage, the
ten-unit balance iteration, Android export, and complete visual evidence remain
open. No Android export has been performed in this continuation yet. No system
files have been deleted or modified.
