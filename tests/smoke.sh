#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$ROOT/bin/cbapp"
for file in "$ROOT"/lib/*.sh; do bash -n "$file"; done
bash -n "$ROOT/install.sh"

version="$(bash "$ROOT/bin/cbapp" version)"
[[ "$version" == *"1.0.0"* ]]

catalogue="$(bash "$ROOT/bin/cbapp" list)"
[[ "$catalogue" == *"gimp"* ]]
[[ "$catalogue" == *"jetbrains"* ]]
[[ "$catalogue" == *"turbowarp"* ]]
[[ "$catalogue" == *"appimage"* ]]

help="$(bash "$ROOT/bin/cbapp" help)"
[[ "$help" == *"self-uninstall"* ]]

printf 'AppPilot smoke tests passed.\n'
