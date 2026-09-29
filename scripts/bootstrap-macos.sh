#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .tools
if [ ! -x .tools/Godot.app/Contents/MacOS/Godot ]; then
  curl -fL --retry 2 'https://downloads.godotengine.org/?flavor=stable&platform=macos.universal&slug=macos.universal.zip&version=4.7.2' -o .tools/godot-macos.zip
  unzip -q .tools/godot-macos.zip -d .tools
fi
if [ ! -f .tools/templates/macos.zip ]; then
  curl -fL --retry 2 'https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.7.2' -o .tools/export-templates.tpz
  unzip -q .tools/export-templates.tpz 'templates/macos.zip' 'templates/version.txt' -d .tools
fi
.tools/Godot.app/Contents/MacOS/Godot --version
