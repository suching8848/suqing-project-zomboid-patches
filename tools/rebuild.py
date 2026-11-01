"""Rebuild selected patches using byte-pinned local upstream sources.

No network, subscriptions, deployment, game launch or source writes. Third-party
files are materialized only in a new isolated output directory. Python 3.10+.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_join(root, relative):
    p = PurePosixPath(relative)
    if not relative or p.is_absolute() or ".." in p.parts or "\\" in relative or ":" in relative:
        raise ValueError(f"Unsafe relative path: {relative}")
    root = root.resolve(strict=True)
    target = root.joinpath(*p.parts)
    if not target.resolve().is_relative_to(root):
        raise ValueError(f"Path leaves its declared root: {relative}")
    for part in [target, *target.parents]:
        if part.exists():
            st = part.lstat()
            if part.is_symlink() or getattr(st, "st_file_attributes", 0) & 1024:
                raise ValueError(f"Symlink/reparse source rejected: {relative}")
        if part == root:
            break
    return target


def canonical(data):
    text = data.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    return text if text.endswith("\n") else text + "\n"


def apply_unified(base, patch):
    """Apply exact unified hunks; no offset search, fuzzy context or shell calls."""
    source = canonical(base).splitlines(keepends=True)
    lines = patch.decode("utf-8").splitlines(keepends=True)
    if not lines:
        return "".join(source)
    if len(lines) < 3 or not lines[0].startswith("--- ") or not lines[1].startswith("+++ "):
        raise ValueError("Invalid unified diff headers")
    out, cursor, index = [], 0, 2
    while index < len(lines):
        match = re.fullmatch(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@\n", lines[index])
        if not match:
            raise ValueError("Invalid unified hunk header")
        old_start, old_count, new_start, new_count = match.groups()
        old_count, new_count = int(old_count or 1), int(new_count or 1)
        start = int(old_start) - (1 if old_count else 0)
        if not cursor <= start <= len(source):
            raise ValueError("Overlapping/out-of-range unified hunk")
        out.extend(source[cursor:start])
        cursor, index, removed, added = start, index + 1, 0, 0
        # New hunk positions must describe the exact output built so far.
        expected_new_start = int(new_start) - (1 if new_count else 0)
        if len(out) != expected_new_start:
            raise ValueError("Unified hunk output position mismatch")
        while index < len(lines) and not lines[index].startswith("@@ "):
            line = lines[index]
            if not line or line[0] not in " +-":
                raise ValueError("Unsupported unified diff line")
            kind, body = line[0], line[1:]
            if kind in " -":
                if cursor >= len(source) or source[cursor] != body:
                    raise ValueError("Unified diff context does not match pinned input")
                cursor += 1
                removed += 1
            if kind in " +":
                out.append(body)
                added += 1
            index += 1
        if removed != old_count or added != new_count:
            raise ValueError("Unified diff line counts disagree")
    out.extend(source[cursor:])
    return "".join(out)


def encode_target(text, recipe):
    if not recipe["ends_with_newline"]:
        if not text.endswith("\n"):
            raise ValueError("Canonical output lost its final newline")
        text = text[:-1]
    if recipe["newline"] == "crlf":
        text = text.replace("\n", "\r\n")
    elif recipe["newline"] != "lf":
        raise ValueError("Unsupported output newline encoding")
    data = text.encode("utf-8")
    return (b"\xef\xbb\xbf" if recipe["bom"] else b"") + data


def pinned_read(path, expected):
    data = path.read_bytes()
    if sha(data) != expected:
        raise ValueError(f"SHA256 mismatch: {path.name}; obtain the exact audited source version")
    return data


def reconstruct(entry, roots):
    mode = entry["mode"]
    if mode == "own":
        data = pinned_read(safe_join(ROOT, entry["repo_path"]), entry["sha256"])
    else:
        source = entry["source"]
        if source["root"] not in roots:
            raise ValueError(f"Missing --{source['root']}-root for {entry['path']}")
        data = pinned_read(safe_join(roots[source["root"]], source["path"]), source["sha256"])
        if mode == "patch":
            patch = pinned_read(safe_join(ROOT, entry["patch_path"]), entry["patch_sha256"])
            data = encode_target(apply_unified(data, patch), entry["text_encoding"])
        elif mode != "copy":
            raise ValueError("Unknown reconstruction mode")
    if len(data) != entry["size"] or sha(data) != entry["sha256"]:
        raise ValueError(f"Reconstructed output differs from audited runtime bytes: {entry['path']}")
    return data


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--workshop-root", type=Path)
    p.add_argument("--game-root", type=Path)
    p.add_argument("--mod-id", action="append", help="Repeat to select a subset; default: all 30")
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Reconstruct and verify in memory; write no output")
    mode.add_argument("--output", type=Path, help="New isolated output directory; never an installed mod directory")
    args = p.parse_args()
    manifest = json.loads((ROOT / "rebuild-manifest.json").read_text(encoding="utf-8"))
    mods = manifest["mods"]
    if args.mod_id:
        requested = set(args.mod_id)
        unknown = requested - {m["id"] for m in mods}
        if unknown:
            raise ValueError("Unknown Mod IDs: " + ", ".join(sorted(unknown)))
        mods = [m for m in mods if m["id"] in requested]
    roots = {name: path.resolve(strict=True) for name, path in
             [("workshop", args.workshop_root), ("game", args.game_root)] if path is not None}
    output = None
    if args.output:
        output = args.output.resolve()
        forbidden = [Path.home() / "Zomboid", *roots.values(), ROOT / "src", ROOT / "patches"]
        if any(output == f.resolve() or output.is_relative_to(f.resolve()) for f in forbidden):
            raise ValueError("Output must not be an installed/source mod directory")
        if output.is_relative_to(ROOT) and not any(output.is_relative_to(ROOT / name) for name in [".local-build", ".validation"]):
            raise ValueError("Output inside this repository must be in ignored .local-build or .validation")
        if output.exists():
            raise ValueError("Output already exists; use a new isolated directory (nothing is deleted)")
        if not output.parent.is_dir():
            raise ValueError("Output parent must already exist")
    built, directories, count = {}, set(), 0
    for mod in mods:
        for directory in mod.get("directories", []):
            relative = mod["folder"] + "/" + directory
            safe_join(ROOT, relative)  # Validate even in the read-only --check mode.
            directories.add(relative)
        for entry in mod["files"]:
            relative = mod["folder"] + "/" + entry["path"]
            if relative.casefold() in {x.casefold() for x in built}:
                raise ValueError("Case-colliding output paths")
            built[relative] = reconstruct(entry, roots)
        count += 1
    # No output is created until every input and every reconstructed hash passes.
    if output is not None:
        output.mkdir(exist_ok=False)
        for relative in sorted(directories):
            safe_join(output, relative).mkdir(parents=True, exist_ok=True)
        for relative, data in built.items():
            path = safe_join(output, relative)
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as stream:
                stream.write(data)
        for relative, data in built.items():
            if safe_join(output, relative).read_bytes() != data:
                raise ValueError("Output read-back mismatch")
        if any(not safe_join(output, relative).is_dir() for relative in directories):
            raise ValueError("Required directory layout read-back mismatch")
    report = {"result": "PASS", "mods": count, "files": len(built),
              "bytes": sum(len(b) for b in built.values()), "directories": len(directories),
              "required_directory_layout_verified": True, "all_output_sha256_verified": True,
              "output_written": output is not None, "deployment_performed": False,
              "gameplay_validation": "not performed; exact reconstruction is an offline content check"}
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, UnicodeError, KeyError) as exc:
        print(json.dumps({"result": "FAIL", "error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(1)
