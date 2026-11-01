"""Safety regression checks for exact reconstruction; no installed files touched."""
import difflib
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("rebuild", HERE / "rebuild.py")
rebuild = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rebuild)
SCRATCH = HERE.parent / ".validation"


class ReconstructionSafety(unittest.TestCase):
    def temporary(self):
        SCRATCH.mkdir(exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="safety-", dir=SCRATCH)
        assert Path(temporary.name).resolve().is_relative_to(SCRATCH.resolve())
        self.addCleanup(temporary.cleanup)
        return Path(temporary.name)

    def test_context_application_preserves_target_encoding(self):
        source = b"one\ntwo\nthree\n"
        expected = b"\xef\xbb\xbfone\r\nchanged\r\nthree"
        patch = "".join(difflib.unified_diff(rebuild.canonical(source).splitlines(True),
                                             rebuild.canonical(expected).splitlines(True),
                                             fromfile="a/input", tofile="b/output", n=1)).encode()
        result = rebuild.encode_target(rebuild.apply_unified(source, patch),
                                       {"bom": True, "newline": "crlf", "ends_with_newline": False})
        self.assertEqual(result, expected)

    def test_wrong_context_cannot_be_fuzzily_applied(self):
        patch = b"--- a/input\n+++ b/output\n@@ -1,2 +1,2 @@\n stable\n-old\n+new\n"
        with self.assertRaisesRegex(ValueError, "context"):
            rebuild.apply_unified(b"different\nold\n", patch)

    def test_changed_upstream_hash_is_rejected_without_mutation(self):
        path = self.temporary() / "upstream.lua"
        data = b"changed upstream\n"
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, "SHA256"):
            rebuild.pinned_read(path, hashlib.sha256(b"audited upstream\n").hexdigest())
        self.assertEqual(path.read_bytes(), data)

    def test_unsafe_paths_and_existing_output_are_rejected(self):
        scratch = self.temporary()
        for relative in ["../escape", "/absolute", "C:/drive", "bad\\separator"]:
            with self.assertRaises(ValueError):
                rebuild.safe_join(scratch, relative)
        existing = scratch / "already-there"
        existing.mkdir()
        sentinel = existing / "keep.txt"
        sentinel.write_bytes(b"do not overwrite")
        process = subprocess.run([sys.executable, str(HERE / "rebuild.py"),
                                  "--mod-id", "Codex_MFSOpticsFix_4221", "--output", str(existing)],
                                 capture_output=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(sentinel.read_bytes(), b"do not overwrite")
        self.assertEqual([p.name for p in existing.iterdir()], ["keep.txt"])


if __name__ == "__main__":
    unittest.main()
