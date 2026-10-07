"""Negative-case inventory checks; fixtures are retained under project builds/."""
import time
import unittest

from PIL import Image, ImageDraw

from art_safety import checked_path, prepare_output, write_text
from verify_art_inventory import inspect_frame, read_resource, resource_path


class InventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = checked_path(f"builds/art-inventory-tests/run-{time.time_ns()}")
        cls.directory.mkdir(parents=True, exist_ok=True)

    def image(self, name, mode="RGBA", color=(0, 0, 0, 0), body=False):
        image = Image.new(mode, (512, 512), color)
        if body:
            ImageDraw.Draw(image).rectangle((100, 100, 400, 480), fill=(255, 255, 255, 255))
        path = prepare_output(self.directory / name)
        image.save(path)
        return path

    def test_rejects_opaque_rgba_and_empty_alpha(self):
        for name, color in (("opaque.png", (20, 30, 40, 255)), ("empty.png", (0, 0, 0, 0))):
            with self.subTest(name=name), self.assertRaises(ValueError):
                inspect_frame(self.image(name, color=color))

    def test_rejects_rgb_without_alpha(self):
        with self.assertRaises(ValueError):
            inspect_frame(self.image("rgb.png", mode="RGB", color=(255, 255, 255)))

    def test_accepts_transparent_frame_with_opaque_body(self):
        result = inspect_frame(self.image("valid.png", body=True))
        self.assertEqual((result["alpha_min"], result["alpha_max"]), (0, 255))
        self.assertEqual(result["body_bbox"], (100, 100, 401, 481))

    def test_resource_path_rejects_escape(self):
        with self.assertRaises(ValueError):
            resource_path("res://../outside.png")

    def test_array_order_preserved(self):
        frames = [self.image(f"ordered{n}.png", body=True) for n in range(4)]
        root = checked_path(".")
        externals = "\n".join(f'[ext_resource type="Texture2D" path="res://{path.relative_to(root).as_posix()}" id="f{n}"]'
                              for n, path in enumerate(frames))
        path = self.directory / "ordered.tres"
        write_text(path, externals + '\n[resource]\nattack_frames = Array[Texture2D]([ExtResource("f3"), ExtResource("f1"), ExtResource("f0"), ExtResource("f2")])\n')
        arrays, warnings = read_resource(path)
        self.assertEqual(arrays["attack_frames"], [frames[3], frames[1], frames[0], frames[2]])
        self.assertEqual(warnings, [])

    def test_unresolved_id_is_not_missing_coverage(self):
        path = self.directory / "unresolved.tres"
        write_text(path, '[resource]\nidle_frames = Array[Texture2D]([ExtResource("unknown")])\n')
        with self.assertRaisesRegex(ValueError, "Unresolved texture"):
            read_resource(path)

    def test_unsupported_array_is_not_missing_coverage(self):
        path = self.directory / "unsupported.tres"
        write_text(path, '[resource]\nidle_frames = Array[Texture2D]([null])\n')
        with self.assertRaisesRegex(ValueError, "Unsupported frame expression"):
            read_resource(path)


if __name__ == "__main__":
    unittest.main()
