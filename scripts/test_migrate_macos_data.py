import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import uuid

spec = importlib.util.spec_from_file_location("migration", Path(__file__).with_name("migrate_macos_data.py"))
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class MigrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "旧配置 Group"
        self.source.mkdir()
        self.destination = self.root / ".clashhako"

    def test_preserves_originals_and_rebases_files_and_preferences(self):
        working = self.source / "working"
        working.mkdir()
        node_path = str(working / "provider.yaml")
        profile = {"path": node_path, "source": "node α", "enabled": True}
        original = json.dumps(profile).encode()
        (working / "profiles.json").write_bytes(original)
        (working / "config.yaml").write_text(f'path: "{node_path}"\n')
        (working / "nodes.bin").write_bytes(b"\x00\xff")
        (self.source / ".com.apple.containermanagerd.metadata.plist").write_bytes(b"skip")
        (self.source / "temp").mkdir()
        (self.source / "temp/socket").write_text("stale")
        preferences = {"proxyShare.independent.enabled": True, "proxyShare.port": 7890,
                       "config": json.dumps(profile).encode(), "opaque": b"\x00\xff"}
        imported = []
        migration.copy_data(self.source, self.destination, preferences,
                            lambda path: imported.append(plistlib.loads(path.read_bytes())))
        self.assertEqual((working / "profiles.json").read_bytes(), original)
        expected = str(self.destination / "working/provider.yaml")
        self.assertEqual(json.loads((self.destination / "working/profiles.json").read_bytes())["path"], expected)
        self.assertIn(expected, (self.destination / "working/config.yaml").read_text())
        self.assertEqual((self.destination / "working/nodes.bin").read_bytes(), b"\x00\xff")
        self.assertFalse((self.destination / "temp").exists())
        self.assertFalse((self.destination / ".com.apple.containermanagerd.metadata.plist").exists())
        self.assertEqual(json.loads(imported[0]["config"])["path"], expected)
        self.assertTrue(imported[0]["proxyShare.independent.enabled"])
        self.assertEqual(imported[0]["opaque"], b"\x00\xff")
        self.assertEqual(os.stat(self.destination).st_mode & 0o777, 0o700)
        self.assertEqual(os.stat(self.destination / "working/profiles.json").st_mode & 0o777, 0o600)
        self.assertEqual(plistlib.loads((self.destination / "migration/original-preferences.plist").read_bytes()), preferences)

    def test_existing_destination_is_not_overwritten(self):
        self.destination.mkdir()
        (self.destination / "keep").write_text("new data")
        with self.assertRaises(migration.MigrationError):
            migration.copy_data(self.source, self.destination, {}, lambda _: self.fail("must not import"))
        self.assertEqual((self.destination / "keep").read_text(), "new data")

    def test_symlink_does_not_copy_external_files(self):
        secret = self.root / "unrelated"
        secret.write_text("private")
        (self.source / "link").symlink_to(secret)
        with self.assertRaises(migration.MigrationError):
            migration.copy_data(self.source, self.destination, {}, lambda _: self.fail("must not import"))
        self.assertFalse(self.destination.exists())
        self.assertEqual(secret.read_text(), "private")
        self.assertEqual(list(self.root.glob(".clashhako-migration-*")), [])

    def test_import_failure_leaves_originals_and_no_partial_destination(self):
        (self.source / "keep").write_text("old data")
        def fail(_):
            raise migration.MigrationError("import failed")
        with self.assertRaises(migration.MigrationError):
            migration.copy_data(self.source, self.destination, {}, fail)
        self.assertFalse(self.destination.exists())
        self.assertEqual((self.source / "keep").read_text(), "old data")
        self.assertEqual(list(self.root.glob(".clashhako-migration-*")), [])

    @unittest.skipUnless(sys.platform == "darwin", "requires macOS defaults")
    def test_imports_into_an_isolated_real_preference_domain(self):
        domain = "hako.migration.test." + uuid.uuid4().hex
        values = {"proxyShare.port": 7890, "proxyShare.independent.enabled": True,
                  "config": b'{"mode":"rule"}'}
        def importer(path):
            subprocess.run(["/usr/bin/defaults", "import", domain, str(path)],
                           capture_output=True, check=True)
        try:
            migration.copy_data(self.source, self.destination, values, importer)
            exported = subprocess.run(["/usr/bin/defaults", "export", domain, "-"],
                                      capture_output=True, check=True)
            actual = plistlib.loads(exported.stdout)
            self.assertEqual(actual["proxyShare.port"], 7890)
            self.assertTrue(actual["proxyShare.independent.enabled"])
            self.assertEqual(json.loads(actual["config"]), {"mode": "rule"})
        finally:
            subprocess.run(["/usr/bin/defaults", "delete", domain], capture_output=True)


if __name__ == "__main__":
    unittest.main()
