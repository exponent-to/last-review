#!/bin/sh
# Fetch the pinned Godot 4.7.2 Linux editor for CI. Prints its path.
set -eu
cd "$(dirname "$0")/.."
mkdir -p .tools
engine=".tools/Godot_v4.7.2-stable_linux.x86_64"
if [ ! -x "$engine" ]; then
  curl -fsSL --retry 2 'https://downloads.godotengine.org/?flavor=stable&platform=linux.64&slug=linux.x86_64.zip&version=4.7.2' -o .tools/godot-linux.zip
  unzip -q -o .tools/godot-linux.zip -d .tools
  rm .tools/godot-linux.zip
  chmod +x "$engine"
fi
echo "$PWD/$engine"
