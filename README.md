# Cyber Draft-Duel 2D

A deterministic, real-time 2D auto-battler built in Godot 4.7 (GDScript). Draft a squad, build it up through in-match upgrade picks, and watch a fixed-timestep battle simulation resolve against an opponent.

## Core loop

1. **Draft** — pick 4 unit types out of the available roster.
2. **Deploy** — starting squad is empty; you build it round-by-round via the same "choose 1 of 3" growth-pick cards used for in-match upgrades, so you can go all-in on one type or mix freely.
3. **Battle** — a deterministic, seeded real-time sim (`BattleSim`) resolves the round; the presentation layer (`match_controller.gd`) just renders whatever the sim produces.
4. **Grow** — between rounds, pick upgrades that add units, level up existing ones, or duplicate a type into your squad.

Matches are always against a bot hand (`UnitDatabase.random_bot_hand()`) — there is no real PvP yet. **Ranked** is an honestly-framed solo difficulty ladder; **Casual** is matchmaking-theater with no rating on the line.

## Roster

Five unit types, each with Lv1 (base) → Lv3 art/ability tiers:

| Unit | Role | Lv2+ ability |
|---|---|---|
| Enforcer | Heavy melee tank | — |
| Trooper | Mid-range rifle | — |
| Marksman | Long-range sniper | — |
| Demolitionist | Splash-damage grenadier | Firestorm — splash attacks leave a burning ground patch that deals damage over time |
| Field Medic | Support healer | — |

Tier art language: **Lv2 = "energized"** (cyan glowing circuitry/seams), **Lv3 = "overcharged"** (orange glowing cracks/veins), applied consistently across idle/attack/walk/retreat animation states.

## Architecture

- **`scripts/sim/`** — the deterministic simulation layer. `BattleSim` runs on a fixed `1/60s` timestep and knows nothing about rendering; `RoundState` owns squad composition (`roster_a`, the deployed squad) separately from the drafted type pool (`type_pool_a`, what "add" growth offers can bring in).
- **`scripts/match_controller.gd`** — presentation only. Consumes events emitted by the sim and drives sprites, VFX, and UI; never mutates sim state directly.
- **`scripts/game_state.gd`** — autoload carrying drafted hand, squad, and match seed across scene transitions.
- **`resources/*.tres`** — per-unit `UnitDefinition` resources (stats, ability parameters, art paths).
- **`scenes/`** — splash, main menu, draft, match, heroes (collection), unit detail, matchmaking, settings.
- **`tools/`** — dev-only utilities (headless screenshot/QA tooling driven by CLI args). Excluded from the exported build.

## Running it

Open the project root in Godot 4.7+ and run. `splash_screen.tscn` is the configured main scene.

Useful QA entry points via `tools/screenshot_tool.tscn` (see the script's header for the full flag list):

```
godot --resolution 720x1280 --quit-after 60 res://tools/screenshot_tool.tscn -- --scene=res://scenes/match.tscn --auto_deploy
```

## Status

Actively in development. Full 5-unit roster, main menu, draft/deploy/battle flow, and rounds/lives system are implemented and balanced (see `stage6-balance-report.md` in the parent directory for the last full balance pass). Lv2/Lv3 art is mid-upgrade from an older flat-shaded style to match the soft-shaded painterly look already shipped for Lv1 — idle frames are done for all 5 units; attack/walk/retreat frames are in progress.
