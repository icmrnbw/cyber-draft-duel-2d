"""Write guard shared by the project art tools. There are no delete operations."""
from pathlib import Path
import os
import stat

PROJECT_ROOT = Path(__file__).absolute().parent.parent


def checked_path(value, *, must_exist=False):
    """Reject escapes, traversal, Windows streams and linked/reparse ancestors."""
    raw = Path(value)
    if ".." in raw.parts:
        raise ValueError(f"Parent traversal is forbidden: {value}")
    path = raw if raw.is_absolute() else PROJECT_ROOT / raw
    path = Path(os.path.abspath(path))
    try:
        path.relative_to(PROJECT_ROOT)
    except ValueError:
        raise ValueError(f"Path must remain under {PROJECT_ROOT}: {value}") from None
    for part in path.parts[1:]:
        if ":" in part:
            raise ValueError(f"Alternate streams are forbidden: {value}")
    for ancestor in [*reversed(path.parents), path]:
        try:
            info = ancestor.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400):
            raise ValueError(f"Linked/reparse path is forbidden: {ancestor}")
    if path.resolve() != path:
        raise ValueError(f"Resolved path differs from requested path: {value}")
    if must_exist and not path.is_file():
        raise ValueError(f"Required file is missing: {path}")
    return path


def prepare_output(value):
    path = checked_path(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    return checked_path(path)


def write_text(value, text):
    prepare_output(value).write_text(text, encoding="utf-8", newline="\n")
