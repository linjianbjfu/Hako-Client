"""Exercise scope reporting through real isolated Git repositories."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("change_scope.py")


class ChangeScopeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="hako-scope-test-")
        self.addCleanup(temporary.cleanup)
        self.repo = Path(temporary.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Skill Test")
        self.git("config", "user.email", "skill-test@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        hooks = self.repo / ".git/empty-hooks"
        hooks.mkdir()
        self.git("config", "core.hooksPath", str(hooks))
        (self.repo / "old name.txt").write_text("initial\n")
        (self.repo / "tracked.txt").write_text("initial\n")
        self.git("add", ".")
        self.git("commit", "-qm", "baseline")
        self.base = self.git("rev-parse", "HEAD").strip()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True)

    def run_scope(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), "--repo", str(self.repo), *args],
                              capture_output=True, text=True)

    def test_layers_renames_and_unusual_names_are_separate(self):
        self.git("mv", "old name.txt", "new name.txt")
        self.git("commit", "-qm", "rename")
        (self.repo / "tracked.txt").write_text("staged\n")
        self.git("add", "tracked.txt")
        (self.repo / "tracked.txt").write_text("unstaged\n")
        unusual = "untracked\nname.txt"
        (self.repo / unusual).write_text("untracked\n")
        before = self.git("status", "--porcelain=v1", "-z")
        result = self.run_scope("--base", self.base)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["paths"]["committed"], ["new name.txt", "old name.txt"])
        self.assertEqual(data["paths"]["staged"], ["tracked.txt"])
        self.assertEqual(data["paths"]["unstaged"], ["tracked.txt"])
        self.assertEqual(data["paths"]["untracked"], [unusual])
        self.assertEqual(data["mergeBase"], self.base)
        self.assertEqual(self.git("status", "--porcelain=v1", "-z"), before)

    def test_worktree_only_does_not_claim_committed_scope(self):
        (self.repo / "README.md").write_text("docs\n")
        result = self.run_scope()
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["scopeKind"], "worktree-only")
        self.assertIsNone(data["mergeBase"])
        self.assertEqual(data["paths"]["committed"], [])
        self.assertEqual(data["areas"], ["documentation"])

    def test_alternate_head_and_merge_base(self):
        (self.repo / "first.txt").write_text("first\n")
        self.git("add", ".")
        self.git("commit", "-qm", "first")
        first = self.git("rev-parse", "HEAD").strip()
        (self.repo / "second.txt").write_text("second\n")
        self.git("add", ".")
        self.git("commit", "-qm", "second")
        result = self.run_scope("--base", self.base, "--head", first)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["paths"]["committed"], ["first.txt"])
        self.assertNotEqual(data["head"], data["worktreeHead"])

    def test_bad_ref_and_incomplete_comparison_fail(self):
        for args in [("--base", "missing-ref"), ("--head", self.base)]:
            result = self.run_scope(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
