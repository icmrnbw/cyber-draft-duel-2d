# Cyber Draft-Duel 2D — Handoff

Written 2026-10-03. Everything here was checked against the repo at commit `5169fb9` unless marked **unverified**. Numbers marked *placeholder* were never playtested.

## 1. What this is

A portrait-orientation (720×1280) Android mobile auto-battler in **Godot 4.7.1 / GDScript**. You draft 4 of 5 unit types, build your starting squad in-match through "choose 1 of 3" cards, and watch a deterministic real-time battle resolve over up to 10 rounds with 3 lives per side. Between rounds you pick growth cards (add a unit, duplicate a stack, level a stack up). Outside matches you earn **Bits**, unlock Lv.2/Lv.3 for each unit type in the Heroes screen, and climb a rating ladder through three arenas.

The visual direction is a soft-shaded, painterly chibi look (not cel-shaded, not pixel art), inspired by Draft Showdown. It is a solo project; there is no real PvP — every opponent is one of 5 canned bot hands.

Repo: `github.com/icmrnbw/cyber-draft-duel-2d` (branch `master`). The older 3D version lives at `D:\vapecoder\cyber-draft-duel` and is shelved — don't develop there, but it still hosts the Meshy script (see §7).

## 2. Current state at a glance

| Area | State |
|---|---|
| Core loop (draft → deploy → rounds → result) | Working end to end |
| 5 units, Lv.1 art, all animation states | Done (soft-shaded style) |
| Lv.2/Lv.3 **idle** art, all 5 units | Done, new style, wired in |
| Lv.2/Lv.3 **attack / walk / retreat** art | **Still the old flat style** — the main art gap (§6) |
| Lv.2+ abilities | Enforcer ✔ (stagger, berserk), Demolitionist ✔ (Firestorm). Trooper / Marksman / Field Medic: **none** |
| Heroes screen, Bits economy, rating, arenas | Working, numbers are placeholders |
| Rewarded ads | **Stub** — pays out instantly (§9) |
| Online PvP | Does not exist in this repo |
| Release build | None. Debug APK only, no release keystore |
| Google Play account / marketing | Nothing started |

Last APK: `D:\vapecoder\builds\cyber-draft-duel-2d-debug.apk`, 74.5 MB, built 2026-09-11 (gitignored). It predates nothing important in the code, but it does **not** include anything done after that date.

## 3. Game rules and systems

**Flow:** `splash_screen` → `main_menu` → `draft_screen` → `match` → (rematch | main menu). Also `heroes_screen`, `unit_detail_screen`, `settings_screen`, `matchmaking_screen` (casual-mode "searching for opponent" theater).

**Draft:** exactly 4 *distinct* types out of 5 (so every hand is "everyone but one"). Distinctness is enforced for the bot too.

**Deployment:** your squad starts **empty** each match. `match_controller.gd::_resolve_initial_deployment()` runs `UnitDatabase.HAND_SIZE` (4) rounds of the same growth-pick cards used mid-match; because the roster is empty every card is an "add", and you can pick the same type four times. The result is saved to `GameState.player_hand` so REMATCH reuses it. `GameState.player_drafted_types` (the 4 drafted types) is separate from `player_hand` (what's deployed) — "add" offers always draw from the drafted types, never from what happens to be deployed.

**Rounds:** `RoundState` (`scripts/sim/round_state.gd`). 3 lives per side, max 10 rounds. A draw replays the round with a fresh seed. After a decisive round the bot auto-grows and the player picks a growth card. Offer kinds: `add` (new Lv.1 unit), `double` (duplicate an entire (type, level) stack), `levelup` (promote a whole stack one level). `double` offers are only included 55% of the time (`PLAYER_DOUBLE_INCLUDE_CHANCE`) — lowered on purpose, duplication was too strong. `levelup` offers only appear if the player unlocked that tier in the Heroes screen. Max level is 3.

**Progression (`PlayerProfile` autoload, saved to `user://player_profile.json`):** Bits (+30 win / +10 loss or draw), per-unit unlocked tier (Lv.2 costs 150, Lv.3 costs 350 *placeholder*), rating (start 1000, +25 win / −18 loss, floor 800), daily +75 Bits claim. Every unit always starts a match at Lv.1; unlocks only *allow* level-up offers. Arenas are rating brackets (`ArenaDatabase`): Asteroid Belt 800+, Frozen Reach 1150+, Molten Core 1350+, each with its own floor art.

**Roster (current stats from `resources/*.tres`):**

| Unit | HP | Dmg | Move | Notes |
|---|---|---|---|---|
| Enforcer | 200 | 22 | 4.2 | Melee tank. Lv.2 Heavy Strikes: 35% stagger for 0.6 s on hit. Lv.3 Berserk: attacks up to 40% faster as HP drops. |
| Trooper | 100 | 9 | 4.7 | Mid-range rifle. No ability. |
| Marksman | 70 | 29 | 2.4 | Long-range. No ability. |
| Demolitionist | 90 | 18 | 2.7 | Splash radius 1.8. Lv.2 Firestorm: each splash leaves a fire patch (12 dps, 3 s, radius 1.8). |
| Field Medic | 85 | 38 (heal) | 4.1 | Support. No ability. |

All unit definitions are data (`UnitDefinition` `.tres` files). `BattleSim` reads ability fields generically and never branches on unit identity — a new ability means new fields on the resource plus a generic check in the sim, not unit-specific code.

## 4. Architecture

- **`scripts/sim/`** — deterministic simulation, no `Node` dependencies (`RefCounted`/`Resource` only). `BattleSim` ticks at fixed 1/60 s. **Do not add rendering or engine-time dependencies here.** Fire patches (`_fire_patches`) are part of the sim and deterministic (no RNG).
- **`scripts/match_controller.gd`** — presentation only. Consumes sim events, builds unit views, projectiles, VFX, HUD, growth cards. It never mutates sim state. Converts sim space to screen space in `_sim_to_screen()`.
- **Autoloads:** `GameState` (hands/seed across scenes), `PlayerProfile` (persistence), `GameSettings` (sound toggle, saved separately from progress), `AdService` (stub).
- **Team color:** one neutral sprite per unit, colored per side by `shaders/team_trim_2d.gdshader` as a silhouette **rim light** (`TeamColor.apply()`). Base color = unit identity (steel / violet / crimson / olive / teal); rim color = side.
- **Frame animation:** `UnitDefinition` carries `attack_frames`/`walk_frames`/`retreat_frames` plus `lv2_*` and `lv3_*` variants; resolver methods (`attack_frames_for_level(level)` etc.) fall back Lv.3 → Lv.2 → base. Empty arrays fall back to procedural motion. Always go through the resolvers, never read the arrays directly.
- **`tools/`** (excluded from export — verify `exclude_filter` in your preset): `screenshot_tool` (windowed screenshots with flags such as `--auto_deploy`, `--tier_preview`, `--firepatch`), `balance_harness.gd`, `bot_vs_progressed_harness.gd`, `round_smoke_test.gd`, `slice_sheets.py`, `wire_frames.py`, `synth_sfx.py`.

## 5. Build and run

Run: open the project root in Godot 4.7.1+. Main scene is `splash_screen.tscn`.

Toolchain on the owner's machine (`D:\vapecoder`): Godot console binary at `C:\Users\rnast\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe` (not on PATH), Android SDK `C:\Users\rnast\AppData\Local\Android\Sdk`, JDK 17, debug keystore in `%APPDATA%\Godot\keystores`, export templates 4.7.1 installed.

```
# only needed after adding new assets/classes (reimport pass; run it twice if a .tres
# references brand-new PNGs — the first pass often errors, the second is clean)
Godot_v4.7.1-stable_win64_console.exe --path . --headless --editor --quit-after 30

# debug APK
Godot_v4.7.1-stable_win64_console.exe --path . --headless --export-debug "Android" "../builds/cyber-draft-duel-2d-debug.apk"
```

`export_presets.cfg` is **gitignored**, so a fresh clone has none. Recreate a debug-only Android preset: arm64-v8a, `gradle_build/use_gradle_build=false`, package `com.vapecoder.cyberdraftduel2d` (deliberately different from the 3D game so both can be installed), version 1.0 / code 1. There is no release keystore, so `--export-release` will not work.

Non-obvious Android requirements already handled in `project.godot`: `rendering/textures/vram_compression/import_etc2_astc=true`, and `display/window/handheld/orientation=1` (an **int**; the string `"portrait"` silently exports a landscape manifest — desktop screenshots can't reveal this).

Tests/tools (headless):

```
godot --headless --script tools/balance_harness.gd     # full 5x5 hand matrix, multi-round
godot --headless --script tools/round_smoke_test.gd
```

Windowed screenshot QA needs a real window, not `--headless`:
`godot --resolution 720x1280 --quit-after 60 res://tools/screenshot_tool.tscn -- --scene=res://scenes/match.tscn --out=C:/path/out.png`

## 6. Art pipeline and status

**Style:** soft-shaded semi-realistic painterly render, glossy highlights, plain background, bulky chibi proportions. **Tier language:** Lv.2 = "energized" (cyan glowing seams, cyan-edged weapon, slightly more aggressive silhouette); Lv.3 = "overcharged" (orange glowing cracks through armor, weapon crackling with orange arcs).

**Gap to close:** Lv.2/Lv.3 *attack, walk, retreat* frames in `assets/` are the old flat cel-shaded art, so a unit visibly changes style when it moves after leveling. Only the idle frames (`<unit>_lv2_idle_breatheN.png`, `_lv3_`) are new.

**In flight:** a batch of 30 sheets (attack/walk/retreat × 5 units × 2 tiers) was generated in a ChatGPT conversation. I inspected 8 of them in the browser (Enforcer, Trooper, Demolitionist, Marksman, Medic; both tiers where sampled) and they were good: true 2×2 four-frame grids, the identical weapon in all four panels, correct tier colors, no invented gear. They are **not downloaded**. Next step: ask for them as three zips of 10 individual alpha-transparent PNGs (ChatGPT caps at 10 images per request), then slice and wire. Those ChatGPT sheets have baked alpha, so slicing needs no background removal — only crop, pad, resize. Handover spec for the generator: `D:\vapecoder\unit_tier_art_handover.txt` and `.zip` (includes reference images). Hard-won rule inside it: demand the *exact same* weapon/model in all four panels.

**Slicing/wiring:** `tools/slice_sheets.py` (2×2 slicer with inset, square-pad, resize to 512) and `tools/wire_frames.py`. Its `UNITS` dict was once left stale after a one-off fix (an old buggy Enforcer walk sheet), so check it before any dict-driven re-slice. After any resize, check hardcoded texture-size math (HP-bar offsets in `match_controller.gd` assume 512 px frames).

**Generators and what we learned:**
- **Meshy** (`gpt-image-2`, `nano-banana-pro`): script and ledger are in the *old 3D repo* (§7). `gpt-image-2` produced the best single Enforcer frames of anything tried (correct twin tonfas, clean white background). But its moderation blocks multi-panel "same character in a grid" prompts and weapon-in-motion poses, and after a run of rejections *every* prompt started failing (suspected cooldown). Failed tasks cost 0 credits. Last request from the owner — "regenerate according to how the Enforcer currently looks, these are too chibi" (use stocky proportions: moderate head, wide pauldrons, tank build) — was **not completed**; all four attempts were blocked.
- **ChatGPT (web):** best multi-panel consistency, but manual (owner relays prompts and files).
- **Local Stable Diffusion** (outside the repo, `D:\vapecoder\tools\ComfyUI` and `D:\vapecoder\tools\lora_training`): ComfyUI 0.36 + DreamShaper 8 + IP-Adapter + a style LoRA trained on the 80 base-tier frames (`vapestyle_lora.safetensors`, 8000 steps, ~90 min on the RTX 3060 6 GB). Verdict: autonomous and free, good character consistency per frame, but weapon-in-hand shapes drift and a pose sequence can't be done by prompting alone; targeted inpainting fixed a bad weapon on one frame. Treat it as a fallback, not the production path. It is not currently running (last restart exited with code 4 — probably a port or process left over; check before assuming).

## 7. External tools and secrets

- **Meshy:** `D:\vapecoder\cyber-draft-duel\tools\meshy.py` (text-to-image costs ~9 credits). API key at `D:\vapecoder\.secrets\meshy.key`, spend ledger at `D:\vapecoder\.meshy\ledger.json`. The script's `DEFAULT_BUDGET` (1928) is a local ceiling matching the real balance on 2026-08-24, **not a live balance**; the ledger shows 1620 committed, 308 left. Flags like `--dry-run` go *before* the subcommand. Check the real balance on meshy.ai before big batches.
- **Telegram delivery:** `D:\vapecoder\cyber-draft-duel\tools\telegram_send.py` (config gitignored). Bot uploads cap at 50 MB; the APK is now 74.5 MB, so send a link instead (`--text`).
- **Build hosting:** only LAN `python -m http.server 8765` in `D:\vapecoder\builds` works today (phone must be on the same WiFi). ngrok is installed but needs the owner's authtoken. GitHub Releases (free) vs. a ~$5/month VPS was proposed and not decided.

## 8. Balance

A purpose-built multi-round harness (`tools/balance_harness.gd`) simulates all 5 legal hands against each other (40 seeds each). On 2026-08-27 it cut the win-rate spread from 37.8 to 10.6 points (all hands 44–55%). **That result is stale**: afterward, all five move speeds were cut ~15%, the duplicate-offer inclusion chance was set to 55%, and Firestorm was added. Re-run the harness before trusting balance, and change one or two units at a time — every buff so far made a different unit the new outlier. Enforcer's stagger/berserk numbers and the whole economy (Bits, costs, rating deltas, daily claim) are first-pass guesses.

## 9. Before any real release

1. ~~Remove the `[DEBUG] +1000 BITS` button~~ — already removed (`scripts/heroes_screen.gd:23`, 2026-09-10). The `proto_test` scene is excluded from the Android export preset (preset is gitignored; re-add the filter if recreated).
2. **Ads are a stub**: `AdService.ADS_AVAILABLE := false` and `show_rewarded()` grants the reward immediately. Wire an AdMob Godot plugin inside `show_rewarded()` only; call sites already pass a callback that must run only on a completed ad.
3. Create a release keystore and a release export preset; the project has only ever produced debug APKs.
4. Decide APK size strategy (74.5 MB debug, `assets/` is ~64 MB). Previous downscales to fit delivery limits were rejected by the owner; Play requires AAB anyway.
5. Google Play developer account ($25) has not been registered. Play requires a 12-tester / 14-day closed test for new personal accounts.
6. Finish the Lv.2/Lv.3 attack/walk/retreat art (§6).

## 10. Open work, roughly by value

1. Download, slice, wire the 30 new tier sheets; delete the old flat Lv.2/Lv.3 attack/walk/retreat frames.
2. Design Lv.2+ abilities for Trooper, Marksman, Field Medic (ideas floated, never approved: Trooper evasion, Marksman crit, Medic shield/damage reduction). Follow the Enforcer pattern: new `UnitDefinition` fields, generic checks in `BattleSim`, no unit-specific sim code.
3. Re-run balance after the above; playtest the economy.
4. Unverified-by-eye UI: growth-pick screen with live spawned roster, Heroes layout, draft "already picked" dimming. Logic-tested only.
5. Dynamic background extras not done: ambient sparks/dust, shooting stars/debris for the asteroid theme.
6. SFX are procedurally synthesized (`tools/synth_sfx.py`); nobody has confirmed they sound good.
7. Combat is "everyone in one lane, each unit seeks the nearest enemy". Draft Showdown is closer to row-vs-row; noted, deliberately not acted on.
8. README table listed Enforcer's Lv.2+ ability as "—" — wrong, corrected in this change.

## 11. Gotchas that cost real time

- Animation amplitudes must be fractions of the sprite's scale (`base_scale.x * k`), never flat constants — this exact distortion bug hit four times. Re-check every amplitude whenever a scale changes.
- Verify at the real target: Android behavior needs the exported manifest or a device, not a desktop screenshot.
- Z-order: floor art and unit sprites share `z_index = 0` and are ordered by scene-tree add order; a node added later at `z_index = -1` renders *behind the opaque floor* and is invisible.
- `class_name` globals don't resolve in a fresh headless run until the editor has scanned the project once; plain `--script` tests can't see autoloads, so keep `RoundState`/`BattleSim` decoupled from them (pass data in).
- A mirrored all-Trooper matchup draws forever (no RNG to break ties). Never use perfect mirrors in smoke tests.
- Python on this Windows machine: set `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1` for tools that print non-Latin text, or they crash on the Cyrillic console codepage.
- After fixing one constraint in an art prompt (weapon count), re-check *all* identity features (visor shape etc.) — fixes silently break unrelated ones. Inspect every sliced frame, not a sample.
- Never call `PlayerProfile.unlock_next_tier()` in test hooks (it saves to the real profile); mutate `_unlocked_tiers` in memory like `screenshot_tool --tier_preview` does.

## 12. Working with the owner

- They react strongly to unverified claims. Say what you checked and how; say "not eyeballed" when it wasn't.
- They prefer reusing an existing UI flow over a new bespoke screen (the deploy screen was built, then rejected for the existing growth-pick cards).
- Hero-visible effects and menu motion must be *obviously* animated and use generated art, not code-drawn approximations; subtle changes get reported as "I didn't notice anything".
- For visual requests, get the reference image attached, the specific gap named, and whether it needs generated art or code-drawn UI, before building.
- Business/launch messages were agreed to go via Telegram, in Russian, kept brief.
