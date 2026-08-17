#!/usr/bin/env bash
set -euo pipefail

godot_bin="${1:-godot}"
mapfile -t tests < <(find tests -maxdepth 1 -type f -name '*_test.gd' -print | sort)

if ((${#tests[@]} == 0)); then
  echo "No headless tests found" >&2
  exit 1
fi

for test_script in "${tests[@]}"; do
  echo "Running $test_script"
  "$godot_bin" --headless --path . --script "res://$test_script"
done

echo "Passed ${#tests[@]} headless test suites"
