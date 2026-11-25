#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$ROOT/bin/cbapp"
for file in "$ROOT"/lib/*.sh; do bash -n "$file"; done
bash -n "$ROOT/install.sh"

version="$(bash "$ROOT/bin/cbapp" version)"
[[ "$version" == *"1.1.0"* ]]

catalogue="$(bash "$ROOT/bin/cbapp" list)"
[[ "$catalogue" == *"gimp"* ]]
[[ "$catalogue" == *"jetbrains"* ]]
[[ "$catalogue" == *"turbowarp"* ]]
[[ "$catalogue" == *"appimage"* ]]\n[[ "$catalogue" == *"APPLICATION"* ]]\nhelp_text="$(bash "$ROOT/bin/cbapp" help)"\n[[ "$help_text" == *"add-file"* ]]\n[[ "$help_text" == *"add-url"* ]]\n[[ "$help_text" == *"add-brew"* ]]\ngrep -Fq "cb_catalogue_add_file" "$ROOT/lib/catalogue.sh"\ngrep -Fq "cb_catalogue_add_url" "$ROOT/lib/catalogue.sh"\ngrep -Fq "brew install --cask" "$ROOT/lib/catalogue.sh"

# GIMP installer contract: pinned official ARM64 AppImage, checksum, and
# dedicated non-overwriting user paths. These checks do not execute downloads.
grep -Fq 'CB_GIMP_VERSION="3.2.8"' "$ROOT/lib/gimp.sh"
grep -Fq '3fd61dbc40b760f7806ffc04c29dc0d93021b799b9d0e6977571c4425d0323b0' "$ROOT/lib/gimp.sh"
grep -Fq 'APPIMAGE_EXTRACT_AND_RUN=1' "$ROOT/lib/gimp.sh"
grep -Fq '1000000' "$ROOT/lib/gimp.sh"
grep -Fq 'Refusing to overwrite existing installation data' "$ROOT/lib/gimp.sh"
grep -Fq 'gimp-appimage-pi.desktop' "$ROOT/lib/gimp.sh" || grep -Fq 'CB_GIMP_DESKTOP=' "$ROOT/lib/gimp.sh"
! grep -Eq '(^|[[:space:]])(sudo|apt-get|apt|flatpak)([[:space:]]|$)' "$ROOT/lib/gimp.sh"

help="$(bash "$ROOT/bin/cbapp" help)"
[[ "$help" == *"self-uninstall"* ]]

printf 'AppPilot smoke tests passed.\n'
