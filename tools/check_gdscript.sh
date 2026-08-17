#!/usr/bin/env bash
set -euo pipefail

godot_bin="${1:-godot}"
mapfile -t scripts < <(find core tests ui -type f -name '*.gd' -print | sort)

if ((${#scripts[@]} == 0)); then
  echo "No GDScript files found" >&2
  exit 1
fi

for script in "${scripts[@]}"; do
  "$godot_bin" --headless --path . --check-only --script "res://$script"
done

echo "Parsed ${#scripts[@]} GDScript files"
