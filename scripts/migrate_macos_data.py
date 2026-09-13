#!/usr/bin/env python3
"""Copy a stopped local macOS build's App Group data to ~/.clashhako."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from urllib.parse import quote


class MigrationError(Exception):
    pass


def rebase(value, source, destination):
    if isinstance(value, str):
        for old, new in [(str(source), str(destination)),
                         (quote(str(source)), quote(str(destination)))]:
            value = value.replace(old + "/", new + "/")
            if value == old:
                value = new
        return value
    if isinstance(value, list):
        return [rebase(item, source, destination) for item in value]
    if isinstance(value, dict):
        return {key: rebase(item, source, destination) for key, item in value.items()}
    # Some preferences contain JSON encoded as Data, including override patches.
    if isinstance(value, bytes):
        try:
            decoded = json.loads(value)
        except (ValueError, UnicodeDecodeError):
            return value
        return json.dumps(rebase(decoded, source, destination), ensure_ascii=False).encode()
    return value


def copy_data(source, destination, preferences, import_preferences):
    source = source.expanduser().absolute()
    destination = destination.expanduser().absolute()
    if not source.is_dir() or source.is_symlink():
        raise MigrationError("The source must be an existing directory, not a symlink.")
    if destination.exists() or destination.is_symlink():
        raise MigrationError("The destination already exists. Preserve or rename it before migrating.")
    if source.resolve() in destination.resolve().parents or destination.resolve() in source.resolve().parents:
        raise MigrationError("The source and destination must be separate directories.")
    migrated_preferences = rebase(preferences, source, destination)
    stage = Path(tempfile.mkdtemp(prefix=".clashhako-migration-", dir=destination.parent))
    try:
        for current, directories, files in os.walk(source, followlinks=False):
            current = Path(current)
            relative = current.relative_to(source)
            if current == source:
                directories[:] = [name for name in directories if name != "temp"]
            target = stage / relative
            target.mkdir(mode=0o700, parents=True, exist_ok=True)
            for name in directories:
                if (current / name).is_symlink():
                    raise MigrationError("The source contains a directory symlink; resolve it before migrating.")
            for name in files:
                original = current / name
                if name == ".com.apple.containermanagerd.metadata.plist" or original.suffix == ".lock":
                    continue
                if not stat.S_ISREG(original.lstat().st_mode):
                    raise MigrationError("The source contains a symlink or special file; resolve it before migrating.")
                copied = target / name
                if original.suffix.lower() in {".json", ".yaml", ".yml", ".plist"}:
                    data = original.read_bytes()
                    if original.suffix.lower() == ".plist":
                        data = plistlib.dumps(rebase(plistlib.loads(data), source, destination))
                    elif original.suffix.lower() == ".json":
                        data = json.dumps(rebase(json.loads(data), source, destination),
                                          ensure_ascii=False, indent=2).encode()
                    else:
                        data = rebase(data.decode("utf-8"), source, destination).encode()
                    copied.write_bytes(data)
                else:
                    shutil.copyfile(original, copied)
                copied.chmod(0o600)
        # Keep a private recovery copy, including the original preference values.
        backup = stage / "migration"
        backup.mkdir(mode=0o700)
        for name, values in [("original-preferences.plist", preferences),
                             ("local-preferences.plist", migrated_preferences)]:
            file = backup / name
            file.write_bytes(plistlib.dumps(values))
            file.chmod(0o600)
        if destination.exists():
            raise MigrationError("The destination was created while copying. Quit Clash and retry.")
        import_preferences(backup / "local-preferences.plist")
        stage.rename(destination)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return destination


def export_preferences(domain):
    result = subprocess.run(["/usr/bin/defaults", "export", domain, "-"], capture_output=True)
    if result.returncode:
        return None
    return plistlib.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    identifiers = Path(__file__).resolve().parents[1] / "apple/HakoClient/Shared/HakoAppIdentifiers.swift"
    bundle = re.search(r'static let macAppBundleID = "([^"]+)"', identifiers.read_text()).group(1)
    parser.add_argument("--bundle-id", default=bundle)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--destination", type=Path, default=Path.home() / ".clashhako")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise MigrationError("Run this command on the Mac that holds your Clash data.")
    processes = subprocess.check_output(["/bin/ps", "-axo", "comm="], text=True)
    if any(line.strip().endswith(("/Clash.app/Contents/MacOS/Clash", "/HakoProxyServer", "/HakoMacExtension"))
           for line in processes.splitlines()):
        raise MigrationError("Quit Clash and stop its VPN/proxy service before migrating; closing the window is not enough.")
    group = "group." + args.bundle_id
    local = args.bundle_id + ".local"
    source = args.source or Path.home() / "Library/Group Containers" / group
    if export_preferences(local):
        raise MigrationError("Local preferences already exist. Back them up before importing old settings.")
    preferences = export_preferences(group)
    if preferences is None:
        raise MigrationError("Could not export the old preferences. Check the bundle ID and directory access.")

    def import_preferences(path):
        result = subprocess.run(["/usr/bin/defaults", "import", local, str(path)], capture_output=True)
        if result.returncode:
            raise MigrationError("Could not import local preferences. The original data is unchanged.")

    destination = copy_data(source, args.destination, preferences, import_preferences)
    print(f"Migration complete: {destination}")
    print(f"Original data retained: {source}")
    print("Open the newly built Clash.app to use the copied data.")


if __name__ == "__main__":
    try:
        main()
    except (MigrationError, OSError, ValueError, plistlib.InvalidFileException) as error:
        # Do not print config contents or command stdout; they can contain credentials.
        print(f"Migration failed: {error}" if isinstance(error, MigrationError)
              else "Migration failed while reading or copying data. Original data was retained.", file=sys.stderr)
        sys.exit(1)
