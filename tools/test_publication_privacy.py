"""Exercise privacy checks against actual temporary Git repositories."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CHECKER = Path(__file__).with_name("check_publication_privacy.py")


class PublicationPrivacyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="publication-privacy-")
        self.root = Path(self.directory.name)
        self.env = os.environ.copy()
        self.env.update({
            "GIT_AUTHOR_NAME": "Ricadom", "GIT_COMMITTER_NAME": "Ricadom",
            "GIT_AUTHOR_EMAIL": "alias@users.noreply.github.com",
            "GIT_COMMITTER_EMAIL": "alias@users.noreply.github.com",
        })
        self.git("init", "-q")
        self.git("config", "core.hooksPath", ".unused-test-hooks")
        (self.root / "README.md").write_text("Public project\n", encoding="utf-8")
        self.git("add", "README.md")
        self.git("commit", "-qm", "base")
        self.base = self.git("rev-parse", "HEAD").stdout.strip()

    def tearDown(self):
        # Git packs and refs can be read-only on Windows. Use TemporaryDirectory's
        # platform-aware cleanup for this test-owned directory only.
        self.directory.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, env=self.env,
                              capture_output=True, text=True, check=True)

    def stage(self, text):
        (self.root / "new.md").write_text(text, encoding="utf-8")
        self.git("add", "new.md")

    def check(self, staged=True):
        args = [sys.executable, str(CHECKER), "--base", self.base]
        if staged:
            args.append("--staged")
        return subprocess.run(args, cwd=self.root, env=self.env,
                              capture_output=True, text=True)

    def test_clean_alias_is_allowed(self):
        self.stage("Ricadom personal project\n")
        self.git("commit", "-qm", "safe update")
        self.assertEqual(self.check(staged=False).returncode, 0)

    def test_source_snapshot_without_upstream_history_is_checked(self):
        result = subprocess.run([sys.executable, str(CHECKER)], cwd=self.root,
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)

    def test_email_is_blocked_without_echoing_it(self):
        value = "person" + "@" + "example.net"
        self.stage(value)
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(value, result.stdout)

    def test_absolute_user_path_is_blocked(self):
        self.stage("C:" + "\\Users" + "\\example\\project")
        self.assertEqual(self.check().returncode, 1)

    def test_secret_is_blocked_without_echoing_it(self):
        value = "ghp_" + "x" * 40
        self.stage(value)
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(value, result.stdout)

    def test_committer_email_is_also_checked(self):
        self.stage("safe content\n")
        self.env["GIT_COMMITTER_EMAIL"] = "person" + "@" + "example.net"
        self.git("commit", "-qm", "update")
        self.assertEqual(self.check(staged=False).returncode, 1)

    def test_tracked_local_credentials_are_blocked(self):
        (self.root / ".kazumi_build_defines.env").write_text("{}", encoding="utf-8")
        self.git("add", ".kazumi_build_defines.env")
        self.assertEqual(self.check().returncode, 1)

    def test_push_checks_the_actual_outgoing_revision(self):
        self.stage("safe file\n")
        self.env["GIT_AUTHOR_EMAIL"] = "person" + "@" + "example.net"
        self.git("commit", "-qm", "unsafe identity")
        unsafe = self.git("rev-parse", "HEAD").stdout.strip()
        self.git("checkout", "-q", self.base)
        payload = f"refs/heads/other {unsafe} refs/heads/other {'0' * 40}\n"
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--base", self.base, "--pre-push"],
            input=payload, cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
