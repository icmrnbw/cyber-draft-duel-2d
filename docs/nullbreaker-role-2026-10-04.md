# Nullbreaker shield-piercing role — 2026-10-04

Nullbreaker now has a mechanical distinction from Marksman. At Lv2+, every third
shot still deals 175% normal damage, but **80% of that damage bypasses shields**.
The remaining 20% interacts with shields normally. At Lv3, its existing mark
still increases subsequent incoming damage by 25% for 2.5 seconds. Marksman
retains its 180% charged hit with ordinary shield absorption and its separate
20%/2-second mark.

No base damage, cadence, range, power scaling, draft, progression, or profile
values changed. The authored descriptions now give the exact effects.

## Generic simulation contract

`UnitDefinition.special_shield_bypass_fraction` defaults to zero and is clamped
to `[0, 1]`. It shares the periodic special attack's tier/cadence gate. There
are no unit-name branches. Each special primary, burst, splash, or chain hit
partitions its already-modified damage. Ordinary hits, self-defense, and damage
over time retain normal shield interaction.

For all hits against a target during one tick, let total damage be `D`, its
bypassing subset be `B`, and shield after queued protection be `S`. The shield
absorbs `min(S, max(0, D - B))`; HP takes the unabsorbed part of `D`. This
partitions existing damage; it never adds damage. Against an unshielded target,
the hit is identical to the old charged shot.

`SimUnit.pending_shield_bypass` records `B` without changing HP/shield during
attack decisions. The existing deferred path still applies same-tick heals,
Medic shields, and Bulwark shields before resolving accumulated damage. Existing
suppression and marks modify both portions once. A newly applied mark affects
later attacks, preserving the previous status timing. Resolution clears the new
accumulator, and `setup()` creates fresh unit state. Simultaneous lethal hits
still allow both combatants to fire.

With base damage 37, one charged shot is 64.75 total damage. A 24-point Bulwark
shield now absorbs 12.95 while 51.8 reaches HP, leaving 11.05 shield. Ordinary
absorption would consume all 24 and deal 40.75 HP damage. Against a 14-point
Medic shield, the shot likewise deals 51.8 HP damage and leaves 1.05 shield.
All values scale with the existing power multiplier.

## Verification

Installed Godot 4.7.1, headless, existing imports only:

- **389 ability checks**, including all three tier gates; ordinary-hit behavior;
  exact unshielded per-tick state/event equivalence; depleted/insufficient
  shields; same-tick Medic and Bulwark protection on both sides; suppression,
  active/new marks, and power scaling; actual shipped damage versus equal-tier
  shield values; and full shipped-roster seeded replays.
  Log: `builds/nullbreaker-ability80-v2-20261004.log`.
- **149 simulation checks**, including fraction bounds, unnamed generic units,
  mixed ordinary/piercing hits in both team and attacker orders, multiple burst
  hits, splash/chain secondaries, deferred state/reset, no repeated damage after
  resolution, and simultaneous deaths through full shields.
  Log: `builds/nullbreaker-sim80-20261004.log`.
- `git diff --check` passed for the changed simulation source files.

All fixtures use in-memory resource copies/state; no player progress was read
or changed. No editor import, asset edits, file deletion, or commits were used.

## Balance comparison

### Follow-up: simultaneous mixed-cap protection

Independent review found an existing source-order bug: an equal-tier Bulwark
starting with 90 shield received 126 or 144 shield from simultaneous Medic and
self protection, depending on which source was queued first. The resolver now
orders each target's contributions by ascending cap, with source ID as the
stable tie breaker. Each contribution retains its own cap and can never shrink
an already stronger shield. This lets low-cap protection contribute before
higher-cap protection, without allowing a large low-cap dose to use a higher
source's cap. Durations still take the maximum; cleanse/immunity remain deferred.

The resumed check passed **231 simulation regressions**, including reversed
queues, swapped source/team order, saturated/existing shields, large low-cap
doses, cleanse, immunity and same-tick piercing damage. All **389 ability
checks** also passed. Logs: `builds/shield-order-sim-resume-20261004.log` and
`builds/shield-order-ability-resume-20261004.log`.

The same 1,008-battle panel passed in 99.538 seconds after the order fix:
`builds/shield-order-balance-20261004.json`. All 336 aggregate rows exactly
match the preceding 80% report, including durations; this sampled panel did
not reach the regression's sensitive cap condition. The exact regression,
not changed win rates, establishes the correction.

### Shield-piercing parameter comparison

The reference is the existing post-control-tuning report
`builds/balance-control-tune-20261004.json`. The same squads suite includes 504
four-unit battles, 168 twelve-unit battles, and 336 controlled-slot battles,
with the same seeds, archetypes, tiers, and side reversals. Dense and slot panels
remain coarse one-seed samples. Draws count as half a win.

An initial 50% setting passed the regression suites but produced **identical
aggregate rows, including battle durations**, across all 1,008 battles:
`builds/nullbreaker-balance-squads-20261004.json` and matching `.log`;
99.584 seconds, no harness failures or battle timeouts. Its 32.375 shieldable
base damage exceeds a single Medic shield (14) or Bulwark shield (24), making
the effect relevant mainly to accumulated shields. The final 80% setting lowers
the shieldable portion to 12.95, so it affects either authored shield directly.

The final 80% setting completed another **1,008 battles in 99.573 seconds**,
with no failures or battle timeouts:
`builds/nullbreaker80-balance-squads-20261004.json` and matching `.log`.
Base-stat report entries match the reference exactly. Every Lv1 row is
unchanged, as required by the Lv2 gate.

All sampled win/loss/draw counts remained unchanged. Four aggregate duration
rows changed (positive values mean longer battles, summed over that row):

| Panel | Tier | Matchup | Games | Total duration change |
|---|---:|---|---:|---:|
| Four units | 2 | Mobility vs anti-armor | 6 | +25.8 s |
| Four units | 3 | Mobility vs anti-armor | 6 | +9.6 s |
| Twelve units | 3 | Mobility vs anti-armor | 2 | +0.2 s |
| Controlled slot 0 | 3 | Phaseblade fourth slot vs anti-armor | 2 | +3.2 s |

The anti-armor archetype's four-unit win rates therefore remain
42.9% / 28.6% / 35.7% at Lv1/Lv2/Lv3 (42 games per tier); twelve-unit rates
remain 57.1% / 35.7% / 35.7% (14 games per tier). The role difference is exact
and tested against authored shield values, but this pass does **not** establish
improved overall win rate or resolve the existing control/dense/progression
balance concerns. Duel and full-progression panels were not rerun for this
isolated shield change.

## Reproduce

From the project directory, with `$godot` pointing to the installed Godot 4.7.1
console executable, choose fresh output filenames (reports refuse overwrites):

```powershell
& $godot --path . --headless --log-file builds/nullbreaker-ability-next.log --script res://tools/ability_regression_test.gd
& $godot --path . --headless --log-file builds/nullbreaker-sim-next.log --script res://tools/sim_regression_test.gd
& $godot --path . --headless --log-file builds/nullbreaker-balance-next.log --script res://tools/balance_harness.gd -- --suite=squads --report=res://builds/nullbreaker-balance-next.json
```
