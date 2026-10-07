"""Safe 2x2 sprite import with a preview-first manifest and legacy slice_sheet API.

Default manifest mode writes only a validation report/contact sheets under builds.
Only --apply writes the four 512px runtime frames per entry. Sources are retained.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw
from art_safety import PROJECT_ROOT, checked_path, prepare_output, write_text

STAGING = PROJECT_ROOT / "art_sources"
ASSETS = PROJECT_ROOT / "assets"
TARGET = 512
PAD_FRAC = 0.06
INSET = 14
BG_THRESHOLD = 230
IDLE_FRAME_NAMES = ["breathe1", "breathe2", "breathe3", "breathe4"]
STATES = ("idle", "attack", "walk", "retreat")
TOKEN = re.compile(r"^[a-z][a-z0-9_]*$")


def frame_names_for(unit, state):
    if state == "idle":
        return IDLE_FRAME_NAMES.copy()
    if state == "attack":
        return (["idle", "windup", "strike", "recover"] if unit == "enforcer" else
                ["ready", "reach", "peak", "pullback"] if unit == "field_medic" else
                ["ready", "fire", "recoil", "settle"])
    return [f"{state}{n}" for n in range(1, 5)]


def entry_outputs(entry):
    prefix, names = entry["out_prefix"], entry["frame_names"]
    if not isinstance(prefix, str) or not TOKEN.fullmatch(prefix):
        raise ValueError(f"Invalid output prefix: {prefix!r}")
    if (not isinstance(names, list) or len(names) != 4 or len(set(names)) != 4
            or any(not isinstance(n, str) or not TOKEN.fullmatch(n) for n in names)):
        raise ValueError("Each entry requires exactly four unique safe frame names")
    return [checked_path(ASSETS / f"{prefix}_{name}.png") for name in names]


def normalize_sheet(sheet_path, *, inset=0, background="alpha", foot_y=481, boxes=None,
                    boundary_alpha_threshold=0, geometry_alpha_threshold=8, glow_padding=0):
    """Use ONE scale per sheet and a shared foot baseline; never per-pose scaling."""
    source = checked_path(sheet_path, must_exist=True)
    if not isinstance(inset, int) or inset < 0:
        raise ValueError("inset must be a nonnegative integer")
    if not isinstance(foot_y, int) or not 64 <= foot_y <= 511:
        raise ValueError("foot_y must be an integer between 64 and 511")
    if background not in ("alpha", "legacy_white"):
        raise ValueError("background must be alpha or legacy_white")
    with Image.open(source) as original:
        has_alpha = "A" in original.getbands() or "transparency" in original.info
        img = original.convert("RGBA")
    w, h = img.size
    if boxes is None:
        if w % 2 or h % 2:
            raise ValueError(f"Sheet must be even-sized for its default 2x2 grid: {source}")
        boxes = [(gx*w//2, gy*h//2, (gx+1)*w//2, (gy+1)*h//2)
                 for gx, gy in ((0, 0), (1, 0), (0, 1), (1, 1))]
    if not isinstance(boxes, (list, tuple)) or len(boxes) != 4:
        raise ValueError("boxes must contain exactly four pixel rectangles")
    for box in boxes:
        if (not isinstance(box, (list, tuple)) or len(box) != 4
                or any(not isinstance(n, int) for n in box)):
            raise ValueError("Each box requires four integer pixel coordinates")
        x0, y0, x1, y1 = box
        if not (0 <= x0 < x1 <= w and 0 <= y0 < y1 <= h
                and x1-x0 > 2*inset and y1-y0 > 2*inset):
            raise ValueError(f"Invalid or empty inset box: {box}")
    for i, a in enumerate(boxes):
        for b in boxes[i+1:]:
            if max(a[0], b[0]) < min(a[2], b[2]) and max(a[1], b[1]) < min(a[3], b[3]):
                raise ValueError("Frame crop boxes must not overlap")
    crop_boxes = list(boxes)
    if background == "alpha" and (not has_alpha or img.getchannel("A").getextrema()[0] == 255):
        raise ValueError(f"Expected transparent alpha sheet, got an opaque image: {source}")
    if not isinstance(boundary_alpha_threshold, int) or not 0 <= boundary_alpha_threshold <= 8:
        raise ValueError("boundary_alpha_threshold must be between 0 and 8 (out of 255)")
    if not isinstance(geometry_alpha_threshold, int) or not 0 <= geometry_alpha_threshold <= 8:
        raise ValueError("geometry_alpha_threshold must be between 0 and 8 (out of 255)")
    if not isinstance(glow_padding, int) or not 0 <= glow_padding <= 32:
        raise ValueError("glow_padding must be between 0 and 32 source pixels")
    frames, boxes, warnings, edge_alpha, padded_boxes, anchors = [], [], [], [], [], []
    for index, (x0, y0, x1, y1) in enumerate(crop_boxes):
        frame = img.crop((x0+inset, y0+inset, x1-inset, y1-inset))
        # Alpha sources ALWAYS retain their original alpha, including white armor.
        if background == "legacy_white" and not has_alpha:
            pixels = frame.load()
            for y in range(frame.height):
                for x in range(frame.width):
                    r, g, b, a = pixels[x, y]
                    if min(r, g, b) > BG_THRESHOLD:
                        pixels[x, y] = (r, g, b, 0)
        alpha = frame.getchannel("A")
        # Only geometry ignores <=8/255 generator residue. Original RGBA pixels
        # remain unchanged inside the padded crop; no alpha mask is multiplied.
        geometry = alpha.point(lambda a: 255 if a > geometry_alpha_threshold else 0)
        bbox = geometry.getbbox()
        if bbox is None:
            raise ValueError(f"Panel {index+1} is empty: {source}")
        edges = [(0,0,1,frame.height), (frame.width-1,0,frame.width,frame.height),
                 (0,0,frame.width,1), (0,frame.height-1,frame.width,frame.height)]
        edge_max = max(alpha.crop(edge).getextrema()[1] for edge in edges)
        edge_alpha.append(edge_max)
        if edge_max > boundary_alpha_threshold:
            warnings.append(f"Panel {index+1} touches its crop boundary (alpha {edge_max}); inspect for clipping")
        boxes.append(bbox)
        padded = (max(0, bbox[0]-glow_padding), max(0, bbox[1]-glow_padding),
                  min(frame.width, bbox[2]+glow_padding), min(frame.height, bbox[3]+glow_padding))
        padded_boxes.append(padded)
        anchors.append(((bbox[0]+bbox[2])/2-padded[0], bbox[3]-padded[1]))
        frames.append(frame.crop(padded))
    margin = round(TARGET * PAD_FRAC)
    scale = min((TARGET-2*margin)/max(f.width for f in frames),
                (foot_y-margin)/max(anchor[1] for anchor in anchors))
    bottom_padding = max(f.height-anchor[1] for f, anchor in zip(frames, anchors))
    if bottom_padding:
        scale = min(scale, (TARGET-foot_y)/bottom_padding)
    normalized = []
    for frame, anchor in zip(frames, anchors):
        size = (max(1, round(frame.width*scale)), max(1, round(frame.height*scale)))
        resized = frame.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (TARGET, TARGET))
        # No alpha mask here: mask paste would multiply semitransparent alpha twice.
        # LANCZOS can add a two-to-three pixel translucent fringe beyond the
        # mathematically scaled anchor when a glow padding crop is requested.
        # Keep the historical exact baseline for ordinary crops, and leave a
        # tiny safety lip only on padded crops.
        safety_lip = 2 if glow_padding else 0
        canvas.paste(resized, (round(TARGET/2-anchor[0]*scale), foot_y-round(anchor[1]*scale)-safety_lip))
        normalized.append(canvas)
    metadata = {"source": str(source.relative_to(PROJECT_ROOT)).replace("\\", "/"),
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "source_size": [w, h], "crop_boxes": crop_boxes, "alpha_preserved": has_alpha,
                "common_scale": scale, "foot_y": foot_y, "source_bboxes": boxes,
                "geometry_alpha_threshold": geometry_alpha_threshold, "glow_padding": glow_padding,
                "padded_bboxes": padded_boxes,
                "runtime_size": [TARGET, TARGET], "boundary_alpha_threshold": boundary_alpha_threshold,
                "edge_alpha_max": edge_alpha, "warnings": warnings}
    return normalized, metadata


def load_manifest(manifest_path):
    manifest_path = checked_path(manifest_path, must_exist=True)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if manifest.get("version") != 1 or not isinstance(manifest.get("entries"), list) or not manifest["entries"]:
        raise ValueError("Manifest requires version: 1 and a nonempty entries list")
    outputs, sources = set(), set()
    for entry in manifest["entries"]:
        source = checked_path(entry["sheet"], must_exist=True)
        sources.add(source)
        for path in entry_outputs(entry):
            if path in outputs:
                raise ValueError(f"Duplicate output in manifest: {path}")
            outputs.add(path)
        if "resource" in entry:
            checked_path(entry["resource"], must_exist=True)
            if not re.fullmatch(r"(lv[23]_)?(idle|attack|walk|retreat)_frames", entry.get("property", "")):
                raise ValueError("Wiring property must be a tier-aware animation frames property")
    if outputs & sources:
        raise ValueError("Runtime outputs must never overwrite source sheets")
    return manifest


def contact_sheet(frames, title, names):
    contact = Image.new("RGB", (TARGET*2, (TARGET+32)*2+36), "#252b37")
    draw = ImageDraw.Draw(contact)
    draw.text((12, 10), title, fill="white")
    for i, frame in enumerate(frames):
        x, y = i%2*TARGET, 36+i//2*(TARGET+32)
        for cy in range(0, TARGET, 32):
            for cx in range(0, TARGET, 32):
                shade = "#626979" if (cx//32+cy//32)%2 else "#7b8190"
                draw.rectangle((x+cx, y+cy, x+cx+31, y+cy+31), fill=shade)
        contact.paste(frame, (x, y), frame)
        draw.text((x+10, y+TARGET+8), names[i], fill="white")
    return contact


def import_manifest(manifest_path, *, apply=False, report_dir=None, wire=False):
    manifest = load_manifest(manifest_path)
    report_dir = checked_path(report_dir or f"builds/art-preview/{Path(manifest_path).stem}")
    # Prepare every image and every resource in memory before any runtime write.
    prepared = []
    for entry in manifest["entries"]:
        frames, metadata = normalize_sheet(entry["sheet"], inset=entry.get("inset", 0),
            background=entry.get("background", "alpha"), foot_y=entry.get("foot_y", 481), boxes=entry.get("boxes"),
            boundary_alpha_threshold=entry.get("boundary_alpha_threshold", 0),
            geometry_alpha_threshold=entry.get("geometry_alpha_threshold", 8), glow_padding=entry.get("glow_padding", 0))
        if entry.get("boundary_alpha_threshold", 0) and not entry.get("boundary_alpha_reason", "").strip():
            raise ValueError("A nonzero boundary alpha threshold requires a documented boundary_alpha_reason")
        if apply and metadata["warnings"] and not entry.get("reviewed_boundary_exception", "").strip():
            raise ValueError(f"{entry['out_prefix']}: crop-boundary warnings require a reviewed exception reason before --apply")
        metadata["boundary_alpha_reason"] = entry.get("boundary_alpha_reason", "")
        metadata["reviewed_boundary_exception"] = entry.get("reviewed_boundary_exception", "")
        outputs = entry_outputs(entry)
        metadata["outputs"] = [str(p.relative_to(PROJECT_ROOT)).replace("\\", "/") for p in outputs]
        prepared.append((entry, frames, metadata, outputs))
    rewrites = {}
    if wire:
        from wire_frames import plan_manifest_wiring
        rewrites = plan_manifest_wiring(manifest, allow_pending_outputs=True)
    report = {"mode": "apply" if apply else "dry-run", "sources_retained": True,
              "entries": [item[2] for item in prepared], "wiring": [str(p) for p in rewrites]}
    report_path = checked_path(report_dir / "validation.json")
    contact_paths = [checked_path(report_dir / f"{entry['out_prefix']}.png") for entry, _, _, _ in prepared]
    protected = {checked_path(e["sheet"]) for e in manifest["entries"]}
    protected.update(p for _, _, _, paths in prepared for p in paths)
    protected.update(checked_path(e["resource"]) for e in manifest["entries"] if "resource" in e)
    if report_path in protected or any(p in protected for p in contact_paths):
        raise ValueError("Preview outputs collide with a source, runtime frame or resource")
    if apply:
        # Preserve each replaced file once per content hash. Repeated imports do
        # not overwrite earlier originals. Backups remain project-local.
        for path in [p for _, _, _, paths in prepared for p in paths] + list(rewrites):
            if path.exists():
                original = checked_path(path, must_exist=True).read_bytes()
                digest = hashlib.sha256(original).hexdigest()
                relative = path.relative_to(PROJECT_ROOT)
                backup = checked_path(PROJECT_ROOT / "art_sources" / "previous" / digest / relative)
                if not backup.exists():
                    prepare_output(backup).write_bytes(original)
    for (entry, frames, _, outputs), contact_path in zip(prepared, contact_paths):
        contact_sheet(frames, entry["out_prefix"], entry["frame_names"]).save(prepare_output(contact_path))
        if apply:
            for frame, path in zip(frames, outputs):
                frame.save(prepare_output(path))
    if apply:
        for path, contents in rewrites.items():
            write_text(path, contents)
    write_text(report_path, json.dumps(report, indent=2) + "\n")
    print(f"{report['mode']}: {len(prepared)} sheets; report: {report_path}")
    return report


def slice_sheet(sheet_path: Path, out_prefix: str, frame_names: list[str]) -> None:
    """Legacy call signature; alpha images are never white-keyed."""
    entry = {"out_prefix": out_prefix, "frame_names": frame_names}
    outputs = entry_outputs(entry)
    source = checked_path(sheet_path, must_exist=True)
    if source in outputs:
        raise ValueError("Runtime outputs must never overwrite source sheets")
    frames, _ = normalize_sheet(source, inset=INSET, background="legacy_white")
    for frame, output in zip(frames, outputs):
        frame.save(prepare_output(output))
        print(f"saved {output.name}")


# Retained legacy lookups; explicit manifests are the production source of truth.
UNITS = {
    unit: {state: (f"{unit}_final_{state}", frame_names_for(unit, state)) for state in STATES}
    for unit in ("enforcer", "trooper", "marksman", "demolitionist", "field_medic")
}
for _unit in UNITS:
    UNITS[_unit]["idle"] = (f"{_unit}_idle_breathe", IDLE_FRAME_NAMES)
UNITS["enforcer"]["walk"] = ("enforcer_walk_sideview", frame_names_for("enforcer", "walk"))
UNITS["field_medic"]["retreat"] = ("field_medic_final_retreat_v2", frame_names_for("field_medic", "retreat"))
IDLE_TIERS = {f"{unit}_lv{tier}": (f"{unit}_lv{tier}_idle_breathe", IDLE_FRAME_NAMES)
              for unit in UNITS for tier in (2, 3)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("unit", nargs="?", choices=list(UNITS))
    parser.add_argument("--manifest")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--wire", action="store_true")
    parser.add_argument("--report-dir")
    parser.add_argument("--idle-tiers", action="store_true")
    args = parser.parse_args()
    if args.manifest:
        import_manifest(args.manifest, apply=args.apply, report_dir=args.report_dir, wire=args.wire)
        return
    if not args.apply:
        parser.error("Legacy dictionary imports require --apply; prefer an explicit --manifest")
    pending = []
    if args.idle_tiers:
        pending = [(STAGING / sheet / "ref_0.png", f"{prefix}_idle", names)
                   for prefix, (sheet, names) in IDLE_TIERS.items()]
    else:
        for unit, states in UNITS.items():
            if args.unit and args.unit != unit:
                continue
            pending.extend((STAGING / sheet / "ref_0.png", f"{unit}_{state}", names)
                           for state, (sheet, names) in states.items())
    # Fail before the first output if any selected legacy source is unavailable.
    for source, prefix, names in pending:
        checked_path(source, must_exist=True)
        entry_outputs({"out_prefix": prefix, "frame_names": names})
        normalize_sheet(source, inset=INSET, background="legacy_white")
    for source, prefix, names in pending:
        slice_sheet(source, prefix, names)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        raise SystemExit(f"Art import rejected: {error}") from error
