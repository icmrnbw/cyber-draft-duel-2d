"""Audit explicit animation coverage and manifest provenance without deleting files.

Default success means file/wiring integrity, NOT art approval or 120-set completion.
Use --require-complete to fail on absent animation arrays. Optional JSON output is
guarded to the project. Visual identity and motion still require human/image QA.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

from PIL import Image

from art_safety import PROJECT_ROOT, checked_path, write_text
from slice_sheets import entry_options, entry_outputs, normalize_sheet

STATES = ("idle", "attack", "walk", "retreat")
PROPERTIES = tuple(f"{'' if tier == 1 else f'lv{tier}_'}{state}_frames"
                   for tier in (1, 2, 3) for state in STATES)


def relative(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def resource_path(value: str) -> Path:
    if not value.startswith("res://"):
        raise ValueError(f"Expected project res:// path: {value}")
    return checked_path(value[6:], must_exist=True)


def read_resource(path: Path) -> tuple[dict[str, list[Path]], list[str]]:
    text = checked_path(path, must_exist=True).read_text(encoding="utf-8-sig")
    externals, arrays, warnings = {}, {}, []
    for declaration in re.findall(r"\[ext_resource\s+([^\]]+)\]", text):
        fields = dict(re.findall(r'(\w+)="([^"]*)"', declaration))
        if fields.get("type") != "Texture2D":
            continue
        identifier = fields["id"]
        resolved = resource_path(fields["path"])
        if identifier in externals:
            if externals[identifier] != resolved:
                raise ValueError(f"Conflicting external id {identifier} in {relative(path)}")
            warnings.append(f"{relative(path)}: repeated external id {identifier}")
        externals[identifier] = resolved
    expression = r"(?m)^((?:lv[23]_)?(?:idle|attack|walk|retreat)_frames)\s*=\s*Array\[Texture2D\]\(\[(.*?)\]\)"
    for prop, body in re.findall(expression, text, re.S):
        identifiers = re.findall(r'ExtResource\("([^"]+)"\)', body)
        residue = re.sub(r'ExtResource\("[^"]+"\)', "", body).strip(" \t\r\n,")
        if residue:
            raise ValueError(f"Unsupported frame expression in {relative(path)}:{prop}")
        try:
            frames = [externals[identifier] for identifier in identifiers]
        except KeyError as error:
            raise ValueError(f"Unresolved texture {error} in {relative(path)}:{prop}") from error
        if prop in arrays:
            if arrays[prop] != frames:
                raise ValueError(f"Conflicting assignments in {relative(path)}:{prop}")
            warnings.append(f"{relative(path)}: repeated assignment {prop}")
        arrays[prop] = frames
    authored = set(re.findall(r"(?m)^((?:lv[23]_)?(?:idle|attack|walk|retreat)_frames)\s*=", text))
    if authored - arrays.keys():
        raise ValueError(f"Unparsed frame arrays in {relative(path)}: {sorted(authored - arrays.keys())}")
    return arrays, warnings


def inspect_frame(path: Path) -> dict:
    path = checked_path(path, must_exist=True)
    with Image.open(path) as image:
        # 512x512, or larger and even-sized for scale-locked action frames
        # (the canvas grows symmetrically around the 512 frame's center).
        if image.width < 512 or image.height < 512 or image.width % 2 or image.height % 2:
            raise ValueError(f"Frame must be 512x512 or larger and even-sized: {relative(path)} ({image.size})")
        if "A" not in image.getbands():
            raise ValueError(f"Frame has no alpha channel: {relative(path)}")
        alpha = image.getchannel("A")
        low, high = alpha.getextrema()
        if low != 0 or high <= 8:
            raise ValueError(f"Frame must contain transparent background and visible art: {relative(path)} ({low}, {high})")
        return {"sha256": hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest(),
                "alpha_min": low, "alpha_max": high,
                "body_bbox": alpha.point(lambda a: 255 if a > 8 else 0).getbbox()}


def roster_resources() -> list[Path]:
    text = checked_path("scripts/sim/unit_database.gd", must_exist=True).read_text(encoding="utf-8-sig")
    declarations = dict(re.findall(r'const\s+(\w+)\s*:=\s*preload\("(res://resources/[^"]+\.tres)"\)', text))
    roster = re.search(r"static func roster\(\).*?:\s*return\s*\[([^\]]+)\]", text, re.S)
    if not roster:
        raise ValueError("Cannot read the explicit UnitDatabase roster")
    names = [name.strip() for name in roster[1].split(",") if name.strip()]
    if len(set(names)) != len(names):
        raise ValueError("Duplicate roster entry")
    return [resource_path(declarations[name]) for name in names]


def audit() -> dict:
    warnings, errors = [], []
    resources = roster_resources()
    arrays_by_resource = {}
    frame_metadata = {}
    for resource in resources:
        arrays, resource_warnings = read_resource(resource)
        warnings.extend(resource_warnings)
        arrays_by_resource[resource] = arrays
        for prop, frames in arrays.items():
            if len(frames) != 4 or len(set(frames)) != 4:
                errors.append(f"{relative(resource)}:{prop} needs four unique frame paths")
            for frame in frames:
                if frame not in frame_metadata:
                    frame_metadata[frame] = inspect_frame(frame)
            if len({frame_metadata[p]["sha256"] for p in frames}) < len(frames):
                errors.append(f"{relative(resource)}:{prop} has pixel-identical frames")

    manifest_paths = sorted(checked_path("art_sources").rglob("*_manifest.json"))
    if not manifest_paths:
        raise ValueError("No art manifests found")
    entry_count, seen_entries, source_paths, output_owners = 0, set(), set(), {}
    sets_with_manifests = {}
    normalized = {}
    for manifest_path in manifest_paths:
        data = json.loads(checked_path(manifest_path, must_exist=True).read_text(encoding="utf-8-sig"))
        if data.get("version") != 1 or not isinstance(data.get("entries"), list) or not data["entries"]:
            raise ValueError(f"Invalid manifest: {relative(manifest_path)}")
        for entry in data["entries"]:
            entry_count += 1
            source = checked_path(entry["sheet"], must_exist=True)
            resource = checked_path(entry["resource"], must_exist=True)
            prop = entry["property"]
            if prop not in PROPERTIES or resource not in arrays_by_resource:
                raise ValueError(f"Manifest owner is outside the playable animation roster: {entry}")
            outputs = entry_outputs(entry)
            owner = (resource, prop)
            signature = (source, owner, tuple(outputs))
            source_paths.add(source)
            seen_entries.add(signature)
            if arrays_by_resource[resource].get(prop) != outputs:
                errors.append(f"{relative(manifest_path)}: outputs do not match wired order for {relative(resource)}:{prop}")
            sets_with_manifests.setdefault(owner, set()).add(relative(manifest_path))
            options = entry_options(entry)
            cache_key = (source, json.dumps(options, sort_keys=True))
            if cache_key not in normalized:
                expected, metadata = normalize_sheet(source, **options)
                normalized[cache_key] = expected
                for warning in metadata["warnings"]:
                    warnings.append(f"{relative(manifest_path)}:{prop}: {warning}")
            expected = normalized[cache_key]
            for output, expected_image in zip(outputs, expected):
                if output in output_owners and output_owners[output] != owner:
                    errors.append(f"Conflicting owners of runtime output: {relative(output)}")
                output_owners[output] = owner
                if output not in frame_metadata:
                    frame_metadata[output] = inspect_frame(output)
                expected_hash = hashlib.sha256(expected_image.tobytes()).hexdigest()
                if frame_metadata[output]["sha256"] != expected_hash:
                    errors.append(f"Runtime pixels differ from manifest source/normalization: {relative(output)}")

    sets = []
    for resource in resources:
        for prop in PROPERTIES:
            frames = arrays_by_resource[resource].get(prop, [])
            manifests = sorted(sets_with_manifests.get((resource, prop), []))
            sets.append({"unit": resource.stem, "property": prop,
                         "status": "manifest_wired" if manifests else "legacy_wired" if frames else "missing",
                         "frames": [relative(path) for path in frames], "manifests": manifests})
    counts = dict(Counter(item["status"] for item in sets))
    return {"scope": "File, alpha, explicit wiring and source-pixel integrity only; not visual or Godot approval.",
            "roster_units": len(resources), "target_sets": len(sets), "counts": counts,
            "manifest_files": len(manifest_paths), "manifest_entries": entry_count,
            "unique_manifest_entries": len(seen_entries), "unique_source_sheets": len(source_paths),
            "manifest_runtime_frames": len(output_owners), "unique_wired_runtime_frames": len(frame_metadata),
            "errors": sorted(set(errors)), "warnings": sorted(set(warnings)), "sets": sets}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-complete", action="store_true")
    parser.add_argument("--json", help="Optional project-local JSON report")
    args = parser.parse_args()
    try:
        report = audit()
        if args.json:
            write_text(args.json, json.dumps(report, indent=2) + "\n")
    except (ValueError, KeyError, OSError) as error:
        print(f"FAIL: {error}")
        return 1
    counts = report["counts"]
    missing = counts.get("missing", 0)
    print(f"{'FAIL' if report['errors'] else 'PASS'}: art file/wiring integrity; "
          f"{report['target_sets'] - missing}/{report['target_sets']} explicit sets "
          f"({counts.get('manifest_wired', 0)} manifest, {counts.get('legacy_wired', 0)} legacy, {missing} missing)")
    print(f"{report['manifest_files']} manifests, {report['manifest_entries']} entries, "
          f"{report['unique_source_sheets']} unique source sheets, "
          f"{report['manifest_runtime_frames']} manifest runtime frames; visual approval is separate")
    for error in report["errors"]:
        print(f"ERROR: {error}")
    if report["warnings"]:
        print(f"{len(report['warnings'])} warnings (use --json for details)")
    return 1 if report["errors"] or (args.require_complete and missing) else 0


if __name__ == "__main__":
    raise SystemExit(main())
