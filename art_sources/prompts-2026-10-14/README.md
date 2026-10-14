# Prompts for the 25 missing animation sheets

The game currently uses code-derived stand-ins for these sets
(`art_sources/derived-2026-10-14/derived_record.json`). To replace one with real art:

1. Open the prompt file in this folder, attach the idle image it names (from `assets/`),
   and paste the prompt into ChatGPT. One sheet per request works best.
2. Check the result: four complete figures, transparent background, the same weapon in
   every panel, the right tier colours. Regenerate if any of these fail.
3. Save it as the `drop_sheet_as` path listed for it in `index.json`
   (folder `art_sources/incoming/`).

That's all: the slicer (scale and foot line locked to idle) and wiring are run from
`index.json`, which overwrites the derived stand-in for that set.
