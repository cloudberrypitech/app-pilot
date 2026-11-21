#!/usr/bin/env bash

cb_install_jetbrains() {
    cb_require_arm64 || return 1
    cb_require_command python3 || return 1
    cb_require_download_tool || return 1
    cb_check_free_kb "$CB_HOME" 450000 || return 1

    local api="$CB_CACHE/jetbrains-toolbox-release.json"
    local url temp extract install_dir executable
    cb_info 'Querying JetBrains official release metadata for Linux ARM64...'
    cb_download 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' "$api" || return 1
    url="$(python3 - "$api" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
items = data.get("TBA") or []
if not items:
    raise SystemExit("JetBrains release API returned no Toolbox releases")
link = (items[0].get("downloads") or {}).get("linuxARM64", {}).get("link")
if not link or not link.startswith("https://"):
    raise SystemExit("JetBrains did not publish a valid linuxARM64 download link")
print(link)
PY
)" || { cb_die 'Could not extract JetBrains Toolbox ARM64 download URL.'; return 1; }

    temp="$CB_CACHE/jetbrains-toolbox.tar.gz"
    extract="$CB_CACHE/jetbrains-stage.$$"
    install_dir="$CB_APPS/jetbrains-toolbox"
    rm -rf -- "$extract"
    mkdir -p -- "$extract"
    cb_download "$url" "$temp" || return 1
    cb_check_min_size "$temp" 1000000 || return 1
    tar -tzf "$temp" >/dev/null || { cb_die 'JetBrains archive failed tar integrity check.'; return 1; }
    tar -xzf "$temp" -C "$extract"
    executable="$(find "$extract" -type f -name jetbrains-toolbox -perm -u+x -print -quit)"
    [[ -n "$executable" ]] || { cb_die 'JetBrains archive did not contain an executable jetbrains-toolbox binary.'; return 1; }

    local stage_install="$CB_APPS/.jetbrains-toolbox.new.$$"
    rm -rf -- "$stage_install"
    mkdir -p -- "$stage_install"
    cp -a "$extract/." "$stage_install/"
    rm -rf -- "$install_dir"
    mv -- "$stage_install" "$install_dir"
    rm -rf -- "$extract"

    local launcher="$CB_BIN/.jetbrains-toolbox.new.$$"
    cat > "$launcher" <<'LAUNCHER'
#!/usr/bin/env sh
set -eu
APP="$HOME/.local/opt/jetbrains-toolbox"
BIN="$(find "$APP" -type f -name jetbrains-toolbox -perm -u+x -print -quit 2>/dev/null)"
if [ -z "$BIN" ]; then
    printf '%s\n' 'JetBrains Toolbox executable is missing. Run: cbapp install jetbrains' >&2
    exit 127
fi
cd "$HOME" || exit 1
exec "$BIN" "$@"
LAUNCHER
    chmod 755 "$launcher"
    mv -f -- "$launcher" "$CB_BIN/jetbrains-toolbox"
    cb_write_desktop jetbrains-toolbox 'JetBrains Toolbox' 'Manage JetBrains IDEs' "\"$CB_BIN/jetbrains-toolbox\" %U" applications-development 'Development;IDE'
    cb_state_write jetbrains-toolbox official-api latest "$url"
    cb_report_installed jetbrains-toolbox 'JetBrains Toolbox (ARM64)'
}

cb_remove_jetbrains() {
    rm -f -- "$CB_BIN/jetbrains-toolbox"
    rm -rf -- "$CB_APPS/jetbrains-toolbox"
    rm -f -- "$(cb_state_file jetbrains-toolbox)"
    cb_remove_desktop jetbrains-toolbox
    cb_ok 'JetBrains Toolbox application files removed. IDEs installed separately through Toolbox and their settings were not targeted.'
}
