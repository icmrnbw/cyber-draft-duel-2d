"""Import generated sheets dropped into art_sources/incoming/.

Each sheet named in art_sources/prompts-2026-10-14/index.json ("drop_sheet_as")
that exists becomes a slice_sheets.py manifest entry with the idle scale/foot
lock. Default is a dry run (contact sheets under builds/); --apply writes the
runtime frames over the code-derived stand-ins and wires the resources.

    python -B tools/import_incoming.py            # preview
    python -B tools/import_incoming.py --apply    # import and wire
"""
import argparse
import json

from art_safety import PROJECT_ROOT, checked_path, write_text
from slice_sheets import import_manifest

INDEX = "art_sources/prompts-2026-10-14/index.json"
MANIFEST = "art_sources/incoming/incoming_manifest.json"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    index = json.loads(checked_path(INDEX, must_exist=True).read_text(encoding="utf-8"))
    entries = []
    for item in index:
        if not (PROJECT_ROOT / item["drop_sheet_as"]).exists():
            continue
        entries.append({"sheet": item["drop_sheet_as"], "out_prefix": item["out_prefix"],
                        "frame_names": item["frame_names"], "resource": item["resource"],
                        "property": item["property"], "background": "alpha", "glow_padding": 4,
                        "scale_lock": "idle", "prompt_file": item["prompt"],
                        # Generators leave alpha<=1 specks at cell edges; anything
                        # stronger still blocks --apply until reviewed.
                        "boundary_alpha_threshold": 1,
                        "boundary_alpha_reason": "Alpha-1 generator residue at crop edges only; check the contact sheet."})
    if not entries:
        print("No sheets in art_sources/incoming/ yet.")
        return
    write_text(checked_path(MANIFEST), json.dumps({"version": 1, "entries": entries}, indent=2) + "\n")
    import_manifest(MANIFEST, apply=args.apply, report_dir="builds/art-preview/incoming", wire=args.apply)
    print(f"{'imported' if args.apply else 'previewed'} {len(entries)} sheet(s); contacts in builds/art-preview/incoming")


if __name__ == "__main__":
    main()
