"""Regression tests for asset safety, alpha, scale and idempotent wiring.

All fixtures stay in builds/art-pipeline-tests; no cleanup/deletion runs.
Invoke with bundled Python -B tools/test_art_pipeline.py.
"""
import hashlib
import json
import stat
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from PIL import Image, ImageDraw
from art_safety import PROJECT_ROOT, checked_path, prepare_output, write_text
import slice_sheets
from slice_sheets import normalize_sheet, import_manifest, entry_outputs
from wire_frames import wired_text

FIXTURES = checked_path(f"builds/art-pipeline-tests/run-{time.time_ns()}")


class ArtPipelineTests(unittest.TestCase):
    def setUp(self):
        self.directory = FIXTURES / self._testMethodName
        self.directory.mkdir(parents=True, exist_ok=True)

    def sheet(self, name="sheet.png", alpha=128, sizes=None):
        image = Image.new("RGBA", (200, 200))
        draw = ImageDraw.Draw(image)
        for i in range(4):
            w, h = (sizes or [(40, 60)]*4)[i]
            x, y = i%2*100+10, i//2*100+10
            draw.rectangle((x, y, x+w-1, y+h-1), fill=(255, 255, 255, alpha))
        path = prepare_output(self.directory / name)
        image.save(path)
        return path

    def test_reject_path_escape_and_traversal(self):
        for path in (PROJECT_ROOT.parent / "outside.png", "../outside.png",
                     "assets/../../outside.png", "assets/secret.png:stream"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                checked_path(path)
        self.assertEqual(checked_path("builds/valid.png"), PROJECT_ROOT / "builds/valid.png")

    def test_reject_windows_junction_ancestor(self):
        linked = self.directory / "junction"
        original = Path.lstat
        def fake_lstat(path, *args, **kwargs):
            if path == linked:
                return SimpleNamespace(st_mode=stat.S_IFDIR, st_file_attributes=0x400)
            return original(path, *args, **kwargs)
        with patch.object(Path, "lstat", autospec=True, side_effect=fake_lstat):
            with self.assertRaisesRegex(ValueError, "Linked/reparse"):
                checked_path(linked / "do-not-write.png")

    def test_reject_symlink_ancestor(self):
        linked = self.directory / "link"
        original = Path.lstat
        def fake_lstat(path, *args, **kwargs):
            if path == linked:
                return SimpleNamespace(st_mode=stat.S_IFLNK, st_file_attributes=0)
            return original(path, *args, **kwargs)
        with patch.object(Path, "lstat", autospec=True, side_effect=fake_lstat):
            with self.assertRaisesRegex(ValueError, "Linked/reparse"):
                checked_path(linked / "do-not-write.png")

    def test_preserve_white_and_partial_alpha_without_double_mask(self):
        source = self.sheet()
        before = hashlib.sha256(source.read_bytes()).hexdigest()
        for background in ("alpha", "legacy_white"):
            frames, metadata = normalize_sheet(source, background=background)
            self.assertTrue(metadata["alpha_preserved"])
            for frame in frames:
                self.assertEqual(frame.size, (512, 512))
                self.assertEqual(frame.getpixel((256, 250)), (255, 255, 255, 128))
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), before)

    def test_common_scale_and_foot_alignment(self):
        frames, report = normalize_sheet(self.sheet(alpha=255, sizes=[(20, 40), (40, 40), (20, 40), (30, 40)]))
        boxes = [frame.getchannel("A").getbbox() for frame in frames]
        self.assertEqual([b[3] for b in boxes], [481]*4)
        widths = [b[2]-b[0] for b in boxes]
        self.assertAlmostEqual(widths[1]/widths[0], 2, delta=0.01)
        self.assertEqual(report["common_scale"], 11.25)

    def test_reject_empty_opaque_and_overlapping_inputs(self):
        source = self.sheet()
        with self.assertRaisesRegex(ValueError, "overlap"):
            normalize_sheet(source, boxes=[[0,0,110,100],[100,0,200,100],[0,100,100,200],[100,100,200,200]])
        opaque = prepare_output(self.directory / "opaque.png")
        Image.new("RGB", (200, 200), "white").save(opaque)
        with self.assertRaisesRegex(ValueError, "opaque"):
            normalize_sheet(opaque)
        empty = prepare_output(self.directory / "empty.png")
        Image.new("RGBA", (200, 200)).save(empty)
        with self.assertRaisesRegex(ValueError, "empty"):
            normalize_sheet(empty)

    def test_alpha_one_noise_does_not_change_scale_or_visible_baseline(self):
        clean = self.sheet(alpha=128)
        noisy = prepare_output(self.directory / "noisy.png")
        with Image.open(clean) as source:
            image = source.copy()
        for xy in ((0, 0), (99, 99), (101, 96), (199, 199), (0, 199)):
            image.putpixel(xy, (255, 255, 255, 1))
        image.save(noisy)
        clean_frames, clean_report = normalize_sheet(clean, glow_padding=2)
        noisy_frames, noisy_report = normalize_sheet(noisy, glow_padding=2)
        self.assertEqual(clean_report["common_scale"], noisy_report["common_scale"])
        self.assertEqual(clean_report["source_bboxes"], noisy_report["source_bboxes"])
        for actual, expected in zip(noisy_frames, clean_frames):
            self.assertEqual(actual.tobytes(), expected.tobytes())
            box = actual.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
            self.assertAlmostEqual(box[3], 481, delta=2)
            self.assertEqual(actual.getpixel((256, 250)), (255, 255, 255, 128))

    def test_boundary_warning_blocks_apply_until_reviewed(self):
        source = self.sheet(alpha=255)
        with Image.open(source) as original:
            image = original.copy()
        image.putpixel((0, 25), (255, 255, 255, 128))
        image.save(source)
        entry = {"sheet":str(source), "out_prefix":"edge", "frame_names":["a","b","c","d"]}
        manifest = self.directory / "manifest.json"
        write_text(manifest, json.dumps({"version":1, "entries":[entry]}))
        with patch.object(slice_sheets, "ASSETS", self.directory/"assets"):
            with self.assertRaisesRegex(ValueError, "reviewed exception"):
                import_manifest(manifest, apply=True, report_dir=self.directory/"preview")
        self.assertFalse((self.directory/"assets").exists())
        self.assertFalse((self.directory/"preview").exists())

    def test_reject_unsafe_output_name(self):
        for prefix in ("../outside", "safe/bad", "bad.png:stream"):
            with self.assertRaises(ValueError):
                entry_outputs({"out_prefix":prefix, "frame_names":["a","b","c","d"]})

    def test_dry_run_preserves_runtime_and_apply_retains_source(self):
        source = self.sheet()
        entry = {"sheet": str(source), "out_prefix":"fixture", "frame_names":["a","b","c","d"]}
        manifest = self.directory / "manifest.json"
        write_text(manifest, json.dumps({"version":1, "entries":[entry]}))
        assets = self.directory / "assets"
        with patch.object(slice_sheets, "ASSETS", assets):
            report = import_manifest(manifest, report_dir=self.directory/"preview")
            self.assertEqual(report["mode"], "dry-run")
            self.assertFalse(assets.exists())
            self.assertTrue((self.directory/"preview"/"fixture.png").is_file())
            source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
            import_manifest(manifest, apply=True, report_dir=self.directory/"applied")
            self.assertEqual(len(list(assets.glob("*.png"))), 4)
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), source_hash)

    def test_bad_later_entry_writes_nothing(self):
        source = self.sheet()
        empty = prepare_output(self.directory/"empty.png")
        Image.new("RGBA", (200,200)).save(empty)
        entries = [{"sheet":str(path), "out_prefix":prefix, "frame_names":["a","b","c","d"]}
                   for path, prefix in ((source,"valid"),(empty,"invalid"))]
        manifest = self.directory/"manifest.json"
        write_text(manifest, json.dumps({"version":1,"entries":entries}))
        with patch.object(slice_sheets, "ASSETS", self.directory/"assets"):
            with self.assertRaises(ValueError):
                import_manifest(manifest, apply=True, report_dir=self.directory/"preview")
        self.assertFalse((self.directory/"assets").exists())
        self.assertFalse((self.directory/"preview").exists())

    def test_wiring_deduplicates_and_is_idempotent(self):
        text = ('[gd_resource type="Resource" load_steps=3 format=3]\n'
                '[ext_resource type="Texture2D" path="res://assets/a.png" id="1_a"]\n'
                '[ext_resource type="Texture2D" path="res://assets/a.png" id="1_a"]\n'
                '\n[resource]\nhp = 200.0\nhp = 200.0\n'
                'walk_frames = Array[Texture2D]([ExtResource("1_a")])\n'
                'walk_frames = Array[Texture2D]([ExtResource("1_a")])\n')
        sets = {"walk_frames":[f"res://assets/{c}.png" for c in "abcd"]}
        result = wired_text(text, sets)
        self.assertEqual(result, wired_text(result, sets))
        self.assertEqual(result.count("walk_frames ="), 1)
        self.assertEqual(result.count('id="1_a"'), 1)
        self.assertEqual(result.count("hp = 200.0"), 1)
        self.assertIn("load_steps=5", result)

    def test_wiring_rejects_conflicting_duplicates(self):
        header = '[gd_resource load_steps=3 format=3]\n'
        a = '[ext_resource type="Texture2D" path="res://assets/a.png" id="same"]\n'
        b = '[ext_resource type="Texture2D" path="res://assets/b.png" id="same"]\n'
        with self.assertRaisesRegex(ValueError, "Conflicting duplicate ext"):
            wired_text(header+a+b+"[resource]\nhp = 1\n", {})
        with self.assertRaisesRegex(ValueError, "Conflicting duplicate property"):
            wired_text(header+a+"[resource]\nhp = 1\nhp = 2\n", {})


if __name__ == "__main__":
    print(f"Retained test fixtures: {FIXTURES}")
    unittest.main(verbosity=2)
