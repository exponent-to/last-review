#!/bin/sh
# Copy a tested build/web export into a checkout of the website repository and
# refresh its release manifest. Usage: sh scripts/publish-web.sh <blog-checkout>
set -eu
cd "$(dirname "$0")/.."
site="${1:?Usage: publish-web.sh <blog-checkout>}"
[ -f build/web/index.html ] || { echo "Run scripts/build-web.sh first." >&2; exit 1; }
[ -d "$site/public" ] || { echo "$site does not look like the website repository." >&2; exit 1; }
target="$site/public/prs-please"
mkdir -p "$target" "$site/docs"
# Only generated export files; --delete removes files a new export no longer has.
rsync -a --delete --exclude '.*' build/web/ "$target/"
python3 - "$target" "$site/docs/prs-please-release.json" "$(git rev-parse HEAD)" <<'PY'
import hashlib, json, pathlib, sys
target, manifest, commit = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.iterdir()) if p.is_file()}
release = {
    "game_commit": commit,
    "engine": "Godot 4.7.2 stable, Compatibility renderer, single-thread Web export",
    "files_sha256": files,
}
manifest.write_text(json.dumps(release, indent=2) + "\n")
print(f"Published {len(files)} files from {commit[:7]} into {target}")
PY
