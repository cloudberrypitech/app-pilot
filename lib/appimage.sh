#!/usr/bin/env bash

cb_safe_app_id() {
    local value="$1"
    value="${value,,}"
    value="${value// /-}"
    value="$(printf '%s' "$value" | tr -cd 'a-z0-9._-')"
    [[ "$value" =~ ^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$ ]] || return 1
    printf '%s' "$value"
}

cb_install_generic_appimage() {
    local source="$1" name="$2" id dest launcher icon
    [[ -n "$source" && -n "$name" ]] || { cb_die 'Usage: cbapp install appimage /path/to/file.AppImage "Application Name"'; return 1; }
    [[ -f "$source" && -r "$source" ]] || { cb_die "AppImage file not found or unreadable: $source"; return 1; }
    name="${name//$'\n'/ }"
    name="${name//$'\r'/ }"
    id="$(cb_safe_app_id "$name")" || { cb_die 'Application name must contain letters, numbers, dots, underscores or hyphens.'; return 1; }
    [[ "$id" != "cbapp" && "$id" != "gimp" && "$id" != "jetbrains-toolbox" && "$id" != "turbowarp" ]] || { cb_die 'That application ID is reserved by AppPilot.'; return 1; }
    dest="$CB_APPS/$id"
    mkdir -p -- "$dest"
    local new_file="$dest/.application.AppImage.new.$$"
    cp -- "$source" "$new_file"
    chmod 755 "&new_file"
    mv -f -- "$new_file" "$dest/application.AppImage"

    launcher="$CB_BIN/.$id.new.$$"
    cat > "$launcher" <<LAUNCHER
#!/usr/bin/env sh
set -eu
APP="\$HOME/.local/opt/$id/application.AppImage"
if [ ! -x "\$APP" ]; then
    printf '%s\\n' 'Application AppImage is missing. Reinstall it with cbapp.' >&2
    exit 127
fi
cd "\$HOME" || exit 1
export APPIMAGE_EXTRACT_AND_RUN=1
exec "\$APP" "\$@"
LAUNCHER
    chmod 755 "$launcher"
    mv -f -- "$launcher" "$CB_BIN/$id"

    icon="applications-other"
    cb_write_desktop "$id" "$name" "$name AppImage" "\"$CB_BIN/$id\" %U" "$icon" 'Utility'
    cb_state_write "$id" appimage local "$source"
    cb_ok "$name installed from local AppImage."
    printf '  Command: %s\n' "$id"
    printf '  Menu:    %s/%s.desktop\n' "$CB_DESKTOP" "$id"
}

cb_remove_generic_appimage() {
    local id="$1"
    rm -f -- "$CB_BIN/$id"
    rm -rf -- "$CB_APPS/$id"
    rm -f -- "$(cb_state_file "$id")"
    cb_remove_desktop "$id"
    cb_ok "Application '$id' removed."
}
