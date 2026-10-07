# Animation coverage audit — 2026-10-04

This is a file-and-visual audit, not a claim that all animations are finished.
The current roster has **84 of 120 explicit four-frame arrays**. Of those, 54
sets have generated-source manifests and 30 retain legacy wiring. **36 sets
are absent**; runtime fallback does not count as an explicit animation set.

The 54 manifested sets comprise 30 original-roster replacements, 15 new-unit
idles, and 9 Bulwark actions. The Bulwark actions need rework following the
independent comparison below. All 30 original-roster Lv2/Lv3 action replacements
are now wired. The 30 retained sets are original-unit idles and Lv1 actions.

## All 120 slots

Each cell describes one explicit four-frame animation set.

- **H**: existing art retained from the handoff (Lv1 actions and original-unit
  idles); present and wired. No new complete visual approval is claimed here.
- **G**: new generated replacement is present, sourced and wired. Source/pixel
  integrity passed; final runtime motion approval remains separate.
- **C**: new canonical idle sheet is present, sourced and wired. This is an
  identity reference, not proof of sufficient breathing motion at mobile scale.
- **F**: old flat tier-action art remains wired; replacement is required.
- **R**: generated and wired, but independent visual audit requires rework.
- **—**: no explicit animation array (36 slots); fallback is not completion.

| Unit | L1 idle | L1 attack | L1 walk | L1 retreat | L2 idle | L2 attack | L2 walk | L2 retreat | L3 idle | L3 attack | L3 walk | L3 retreat |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Enforcer | H | H | H | H | H | G | G | G | H | G | G | G |
| Trooper | H | H | H | H | H | G | G | G | H | G | G | G |
| Marksman | H | H | H | H | H | G | G | G | H | G | G | G |
| Demolitionist | H | H | H | H | H | G | G | G | H | G | G | G |
| Field Medic | H | H | H | H | H | G | G | G | H | G | G | G |
| Bulwark | C | R | R | R | C | R | R | R | C | R | R | R |
| Phaseblade | C | — | — | — | C | — | — | — | C | — | — | — |
| Cryotek | C | — | — | — | C | — | — | — | C | — | — | — |
| ArcRelay | C | — | — | — | C | — | — | — | C | — | — | — |
| Nullbreaker | C | — | — | — | C | — | — | — | C | — | — | — |

Counts: H=30, G=30, C=15, F=0, R=9, missing=36. A complete-quality total cannot
be inferred by adding the nonmissing cells: wiring, style, identity, movement,
and real Godot presentation each need their own evidence.

October4 continuation added Enforcer Lv2 retreat and Lv3 attack/walk/retreat
under `art_sources/2026-10-04/`. All four generated sources and normalized
contact sheets were inspected. Godot captured and displayed all four frame
positions for every Enforcer tier/state (`builds/enforcer-final-20261004-frame0.png`
through `frame3.png`). No old flat tier action appears in those views. The attack
poses reserve space for the raised weapon and appear smaller than idle, so
cross-state scale/motion polish is still a separate review item.

The resumed batch added Trooper, Demolitionist and Field Medic Lv2/Lv3
attack/walk/retreat: 18 sheets and 72 runtime frames. Sources, exact prompts,
rejections and review notes are indexed in
`art_sources/2026-10-04/original-actions-generation-record.json`. All source and
normalized frames were inspected. Godot imported them and all four frame
positions were captured and inspected for all tiers/states in
`builds/{trooper,medic,demo}-originals-20261004-frame{0,1,2,3}.png`.
Demolitionist Lv2 and Medic attacks still show smaller bodies than their idle
poses due to effect/weapon extent; fix this during cross-state scale polish.
Medic casts use custom nonoverlapping crops to retain the drone and pulse.
The Lv3 cast's tight top-row split has an explicitly reviewed <=5/255 alpha
fringe exception; no opaque silhouette is cut. Sources retain their full alpha.

## Reproducible file checks

Run `python -B tools/verify_art_inventory.py --json builds/art-inventory-20261004.json`.
The audit reads the actual `UnitDatabase.roster()` resource list, then checks
each of its twelve explicit array properties. It validates four unique texture
paths, frame order, dimensions, visible body pixels and genuinely transparent
background pixels. Every manifest source and output is constrained to the
project by the shared path guard. It re-normalizes the source in memory and
compares exact RGBA pixels against each wired output; this catches a stale
runtime image even when the filename exists. No source/runtime file is changed
or deleted. Only the requested JSON report is written.

Observed result at this audit snapshot:

```text
PASS: art file/wiring integrity; 84/120 explicit sets (54 manifest, 30 legacy, 36 missing)
17 manifests, 55 entries, 54 unique source sheets, 216 manifest runtime frames; visual approval is separate
```

There are 336 unique wired frame paths in total. The two Marksman manifests
both describe the same Lv2 attack source and outputs. Consequently **33
manifest entries in the initial audit were 32 unique source sheets**, not 33 sheets or approvals.
`--require-complete` returns failure until every explicit slot exists.

`builds/art-inventory-originals-20261004.json` contains only three warnings:
crop-edge alpha-1 warnings from the older duplicate Marksman manifest. The
45 identical duplicate resource declarations/assignments were consolidated by
the safe wiring tool while importing the final original-unit replacements. The
newer combined Marksman manifest documents its alpha threshold. These warnings
are distinct from identity/motion quality. Conflicting duplicate declarations
would be errors. Seven targeted negative-case tests in
`tools/test_art_inventory.py` pass, including opaque RGBA, blank frames,
missing alpha, path escape, unresolved resource IDs and unsupported arrays.

## Independent Bulwark review

Review compared all three canonical idle sheets with the corresponding attack
sheets and the Lv1 walk/retreat sheets under `art_sources/2026-10-03/`. The
Lv2/Lv3 walk/retreat runtime contact sheets under
`builds/art-preview/new_units_action_manifest/` were also visually inspected.
The file audit verified that contact-sheet inputs match the manifest source
normalization. No Godot motion capture is part of this independent review.

| Feature | Canonical idle, all tiers | Current actions, all tiers | Decision |
|---|---|---|---|
| Helmet | Rounded dome with large circular ear module | Squared front/top and smaller angular side module | Identity drift |
| Chest/armor | Broad silver chest slabs, smooth chunky mass | Angular segmented chest and slimmer, more jointed limbs | Identity/proportion drift |
| Shield | Large shield with split/forked cyan central structure and multiple side insets | Narrower rectangular shield with a single inset light bar | Different shield design |
| Hammer | Compact bevelled head with energy around its front profile | Larger rectangular block with a long inset light bar | Different weapon design |
| Walk | Reference identity should be carried into a cycle | Near leg stays forward, far leg stays back across all four poses; no clear passing/opposite-contact frame | Regenerate leg cycle |
| Retreat | Reference identity should withdraw while facing the opponent | Two repeated stance families; far foot lifts, but opposite contact/weight transfer is not established | Regenerate backward cycle |

The attack sequence itself has a readable raised-hammer anticipation and strike,
and all sheets retain one hammer and one shield. The transparent margins and
tier energy are usable. Those positives do not resolve the identity mismatch.
All **nine Bulwark action sets are R (rework)**. Earlier manifest wording that
says they were reviewed is a record of an earlier review, not a final acceptance.
Keep the sources; use the canonical idle reference for new generation.

The canonical idles have very subtle pose changes. They are retained as identity
references, but idle motion should also be judged in the Godot preview before
claiming the full 120-set quality target.

## Original-roster style spot check

The original 30-set replacement goal is now covered by generated sources and
wiring. The former Trooper tier actions used different flat rifle/helmet art;
the replacements retain its canonical silver dome, circular ear, visor and
black carbine. Demolitionist keeps its single drum launcher and canister;
Medic keeps its syringe and one spherical drone. Trooper walks received an
independent near/far leg and identity review. This closes the old flat tier-art
gap, while preserving the distinct motion/scale polish work described above.

## Acceptance needed after generation

For each replacement: inspect all four full source poses against the canonical
tier reference; verify both legs genuinely alternate for locomotion; inspect
every sliced frame; import in Godot; play the actual state sequence at gameplay
scale; capture evidence. A successful integrity command must never be promoted
to visual approval or 120-set completion.
