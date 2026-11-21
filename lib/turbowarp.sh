#!/usr/bin/env bash

cb_install_turbowarp() {
    cb_require_arm64 || return 1
    cb_require_command python3 || return 1
    cb_require_download_tool || return 1
    cb_check_free_kb "$CB_HOME" 450000 || return 1

    local api="$CB_CACHE/turbowarp-latest.json"
    local metadata version url digest asset_name temp actual stage app_dir
    cb_info 'Querying TurboWarp official GitHub release metadata...'
    cb_download 'https://api.github.com/repos/TurboWarp/desktop/releases/latest' "$api" || return 1
    metadata="$(python3 - "$api" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    release = json.load(f)
assets = release.get("assets", [])
candidates = [a for a in assets if "linux-arm64" in a.get("name", "").lower() and a.get("name", "").lower().endswith(".appimage")]
if not candidates:
    raise SystemExit("Latest TurboWarp release has no Linux ARM64 AppImage")
a = candidates[0]
url = a.get("browser_download_url", "")
if not url.startswith("https://github.com/TurboWarp/desktop/releases/download/"):
    raise SystemExit("Unexpected TurboWarp download host")
digest = a.get("digest") or ""
if digest.startswith("sha256:"):
    digest = digest.split(":", 1)[1]
print(release.get("tag_name", "latest"))
print(a.get("name", "TurboWarp.AppImage"))
print(url)
print(digest)
PY
)" || { cb_die 'Could not identify a verified ARM64 AppImage in the latest TurboWarp release.'; return 1; }
    version="$(printf '%s\n' "$metadata" | sed -n '1p')"
    asset_name="$(printf '%s\n' "$metadata" | sed -n '2p')"
    url="$(printf '%s\n' "$metadata" | sed -n '3p')"
    digest="$(printf '%s\n' "$metadata" | sed -n '4p')"
    [[ "$url" == https://github.com/TurboWarp/desktop/releases/download/* ]] || { cb_die 'TurboWarp release URL failed host validation.'; return 1; }

    temp="$CB_CACHE/turbowarp.AppImage.part"
    cb_download "$url" "$temp" || return 1
    cb_check_min_size "$temp" 50000000 || return 1
    if [[ "$digest" =~ ^[0-9a-fA-F]{64}$ ]]; then
        actual="$(cb_sha256 "$temp")" || return 1
        [[ "${actual,,}" == "${digest,,}" ]] || { cb_die 'TurboWarp SHA-256 digest verification failed.'; return 1; }
        cb_ok 'TurboWarp release SHA-256 digest verified.'
    else
        cb_warn 'GitHub did not provide a SHA-256 digest for this asset; download host and release metadata were checked, but checksum verification was unavailable.'
    fi

    app_dir="$CB_APPS/turbowarp"
    stage="$app_dir/.TurboWarp.AppImage.new.$$"
    mkdir -p -- "$app_dir"
    cp -- "$temp" "$stage"
    chmod 755 "$stage"
    mv -f -- "$stage" "$app_dir/TurboWarp.AppImage"

    local launcher="$CB_BIN/.turbowarp.new.$$"
    cat > "$launcher" <<'LAUNCHER'
#!/usr/bin/env sh
set -eu
APP="$HOME/.local/opt/turbowarp/TurboWarp.AppImage"
if [ ! -x "$APP" ]; then
    printf '%s\n' 'TurboWarp AppImage is missing. Run: cbapp install turbowarp' >&2
    exit 127
fi
cd "$HOME" || exit 1
export APPIMAGE_EXTRACT_AND_RUN=1
exec "$APP" "$@"
LAUNCHER
    chmod 755 "$launcher"
    mv -f -- "$launcher" "$CB_BIN/turbowarp"
    cb_write_desktop turbowarp TurboWarp 'TurboWarp Desktop' "\"$CB_BIN/turbowarp\" %U" applications-development 'Development;Education'
    cb_state_write turbowarp appimage "$version" "$url"
    cb_report_installed turbowarp "TurboWarp $version ARM64"
}

cb_remove_turbowarp() {
    rm -f -- "$CB_BIN/turbowarp"
    rm -rf -- "$CB_APPS/turbowarp"
    rm -f -- "$(cb_state_file turbowarp)"
    cb_remove_desktop turbowarp
    cb_ok 'TurboWarp application files removed.'
}
