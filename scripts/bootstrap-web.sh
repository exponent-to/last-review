#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Only fetch the Web member of the official multi-platform archive (~1.2 GB).
# GODOT_TEMPLATE_DIR can share the template cache between local worktrees.
python3 - "${GODOT_TEMPLATE_DIR:-$PWD/.tools/templates}" <<'PY'
import io
from pathlib import Path
import sys
import subprocess
import zipfile

VERSION = "4.7.2.stable"
URL = "https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.7.2"
NAME = "web_nothreads_release.zip"
destination = Path(sys.argv[1]).expanduser().resolve()
template = destination / NAME
version_file = destination / "version.txt"
if template.is_file() and version_file.is_file() and version_file.read_text().strip() == VERSION:
    with zipfile.ZipFile(template) as package:
        if package.testzip() is not None:
            raise SystemExit("Cached Web template is corrupt; remove it and bootstrap again.")
    print(f"Godot {VERSION} Web template already installed: {template}")
    raise SystemExit(0)


class RemoteArchive(io.RawIOBase):
    """Seekable HTTP ranges let ZipFile validate/extract only the needed member."""

    def __init__(self, url):
        result = subprocess.run(
            ["curl", "-fsSLI", "--retry", "2", "--max-time", "60", "--write-out", "\n%{url_effective}", url],
            check=True, capture_output=True, text=True,
        )
        headers, self.url = result.stdout.rsplit("\n", 1)
        lengths = [line.split(":", 1)[1].strip() for line in headers.splitlines() if line.lower().startswith("content-length:")]
        if not lengths:
            raise OSError("Official archive did not provide its content length.")
        self.length = int(lengths[-1])
        self.position = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=io.SEEK_SET):
        origins = {io.SEEK_SET: 0, io.SEEK_CUR: self.position, io.SEEK_END: self.length}
        if whence not in origins or origins[whence] + offset < 0:
            raise ValueError("Invalid archive seek")
        self.position = origins[whence] + offset
        return self.position

    def read(self, size=-1):
        if size < 0:
            size = self.length - self.position
        size = min(size, self.length - self.position)
        if size <= 0:
            return b""
        start = self.position
        result = subprocess.run(
            ["curl", "-fsSL", "--retry", "2", "--max-time", "120", "--max-filesize", str(size),
             "--range", f"{start}-{start + size - 1}", "--write-out", "%{http_code}", self.url],
            check=True, capture_output=True,
        )
        if result.stdout[-3:] != b"206":
            raise OSError("Official download server did not honor the requested byte range.")
        data = result.stdout[:-3]
        if len(data) != size:
            raise OSError("Incomplete template download. Re-run bootstrap-web.sh.")
        self.position += len(data)
        return data


print(f"Fetching Godot {VERSION} single-threaded Web template from the official archive…", flush=True)
with zipfile.ZipFile(RemoteArchive(URL)) as archive:
    version = archive.read("templates/version.txt").decode().strip()
    if version != VERSION:
        raise SystemExit(f"Unexpected template version: {version!r}")
    data = archive.read("templates/" + NAME)  # ZipFile verifies the member CRC.
with zipfile.ZipFile(io.BytesIO(data)) as package:
    if package.testzip() is not None:
        raise SystemExit("Downloaded Web template failed ZIP integrity validation.")
destination.mkdir(parents=True, exist_ok=True)
partial = template.with_suffix(".zip.part")
partial.write_bytes(data)
partial.replace(template)
version_file.write_text(VERSION + "\n")
print(f"Installed {template} ({len(data) / 1024 / 1024:.1f} MiB)")
PY
