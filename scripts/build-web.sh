#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ ! -f .tools/templates/web_nothreads_release.zip ]; then
  echo "Missing Godot Web template. Run: sh scripts/bootstrap-web.sh" >&2
  exit 1
fi
engine_version="$(sh scripts/run.sh --version)"
case "$engine_version" in
  4.7.2.*) ;;
  *) echo "Expected Godot 4.7.2; found $engine_version" >&2; exit 1 ;;
esac
mkdir -p build/web
touch build/.gdignore
sh scripts/run.sh --headless --editor --import
sh scripts/run.sh --headless --export-release Web "$PWD/build/web/index.html"
cp art/fonts/IBMPlexMono-Regular.ttf build/web/loader-font.ttf
cp art/fonts/OFL.txt build/web/loader-font-LICENSE.txt
echo "Built $PWD/build/web/index.html"
echo "Run locally: python3 scripts/serve-web.py"
