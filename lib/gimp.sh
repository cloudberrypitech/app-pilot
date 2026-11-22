#!/usr/bin/env bash
# GIMP: pinned, verified, non-destructive ARM64 AppImage installation.
# Installs only into AppPilot's dedicated user-local paths. Never uses root.

CB_GIMP_VERSION="3.2.8"
CB_GIMP_FILE="GIMP-${CB_GIMP_VERSION}-aarch64.AppImage"
CB_GIMP_SHA256="3fd61dbc40b760f7806ffc04c29dc0d93021b799b9d0e6977571c4425d0323b0"
CB_GIMP_URL="https://download.gimp.org/gimp/v3.2/linux/${CB_GIMP_FILE}"
CB_GIMP_ID="gimp-appimage-pi"
CB_GIMP_APP_DIR="$CB_APPS/${CB_GIMP_ID}-${CB_GIMP_VERSION}-arm64"
CB_GIMP_APP="$CB_GIMP_APP_DIR/${CB_GIMP_FILE}"
CB_GIMP_LAUNCHER="$CB_BIN/${CB_GIMP_ID}"
CB_GIMP_DESKTOP="$CB_DESKTOP/${CB_GIMP_ID}.desktop"

cb_gimp_check_platform() {
    cb_require_arm64 || return 1
    local libc_line libc_version libc_major libc_minor os_id os_version
    libc_line="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
    libc_version="${libc_line##* }"
    if [[ "$libc_version" =~ ^([0-9]+)\.([0-9]+) ]]; then
        libc_major="${BASH_REMATCH[1]}"
        libc_minor="${BASH_REMATCH[2]}"
        if (( libc_major > 2 || (libc_major == 2 && libc_minor >= 41) )); then
            return 0
        fi
    fi
    os_id=""
    os_version=""
    if [[ -r /etc/os-release ]]; then
        # Parse only ID and VERSION_ID as data; do not source the file.
        os_id="$(sed -n 's/^ID=//p' /etc/os-release | head -n1 | tr -d '"')"
        os_version="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | head -n1 | tr -d '"')"
    fi
    if [[ "$os_id" == debian || "$os_id" == raspbian ]]; then
        if [[ "$os_version" =~ ^([0-9]+) ]] && (( BASH_REMATCH[1] >= 13 )); then
            return 0
        fi
    fi
    cb_die "The official GIMP ARM64 AppImage requires Debian 13+/glibc 2.41+. Detected libc: ${libc_version:-unknown}; OS: ${os_id:-unknown} ${os_version:-unknown}. No system changes were made."
    return 1
}

cb_gimp_install_launcher() {
    local tmp="$CB_BIN/.${CB_GIMP_ID}.new.$$"
    [[ ! -e "$CB_GIMP_LAUNCHER" && ! -L "$CB_GIMP_LAUNCHER" ]] || {
        cb_die "Refusing to overwrite an existing user file: $CB_GIMP_LAUNCHER"
        return 1
    }
    cat > "$tmp" <<'LAUNCHER'
#!/usr/bin/env sh
set -eu
APP="$HOME/.local/opt/gimp-appimage-pi-3.2.8-arm64/GIMP-3.2.8-aarch64.AppImage"
if [ ! -x "$APP" ]; then
    printf '%s\n' 'GIMP AppImage is missing. Run: cbapp install gimp' >&2
    exit 127
fi
cd "$HOME" || exit 1
export APPIMAGE_EXTRACT_AND_RUN=1
exec "$APP" "$@"
LAUNCHER
    chmod 755 "$tmp"
    if ! mv -n -- "$tmp" "$CB_GIMP_LAUNCHER"; then
        cb_die "Could not create launcher without replacing an existing file: $CB_GIMP_LAUNCHER"
        return 1
    fi
    if [[ -e "$tmp" ]]; then
        rm -f -- "$tmp"
        cb_die "Launcher destination already existed; it was not overwritten: $CB_GIMP_LAUNCHER"
        return 1
    fi
    return 0
}

cb_gimp_install_desktop() {
    [[ ! -e "$CB_GIMP_DESKTOP" && ! -L "$CB_GIMP_DESKTOP" ]] || {
        cb_die "Refusing to overwrite an existing desktop entry: $CB_GIMP_DESKTOP"
        return 1
    }
    cb_write_desktop "$CB_GIMP_ID" "GIMP" "GIMP image editor (official ARM64 AppImage)" "\"$CB_GIMP_LAUNCHER\" %F" applications-graphics 'Graphics;2DGraphics;RasterGraphics'
}

cb_install_gimp() {
    local temp_root download actual magic stage state existing_backend existing_version
    cb_gimp_check_platform || return 1

    state="$(cb_state_file "$CB_GIMP_ID")"
    if [[ -r "$state" ]]; then
        existing_backend="$(cb_state_get "$CB_GIMP_ID" Backend)"
        existing_version="$(cb_state_get "$CB_GIMP_ID" Version)"
        if [[ "$existing_backend" == appimage && "$existing_version" == "$CB_GIMP_VERSION" \
            && -x "$CB_GIMP_APP" && -x "$CB_GIMP_LAUNCHER" && -r "$CB_GIMP_DESKTOP" ]]; then
            actual="$(cb_sha256 "$CB_GIMP_APP")" || return 1
            [[ "$actual" == "$CB_GIMP_SHA256" ]] || {
                cb_die "The existing AppPilot GIMP file failed checksum verification. It was left untouched."
                return 1
            }
            cb_ok "GIMP $CB_GIMP_VERSION is already installed and verified; no files were changed."
            return 0
        fi
        cb_die "AppPilot GIMP state exists but does not match this verified installation. Existing files were left untouched."
        return 1
    fi

    # Use dedicated names so legacy GIMP installs and personal data are untouched.
    if [[ -e "$CB_GIMP_APP_DIR" || -L "$CB_GIMP_APP_DIR" ]]; then
        cb_die "Refusing to overwrite existing installation data: $CB_GIMP_APP_DIR"
        return 1
    fi
    if [[ -e "$CB_GIMP_LAUNCHER" || -L "$CB_GIMP_LAUNCHER" ]]; then
        cb_die "Refusing to overwrite existing user launcher: $CB_GIMP_LAUNCHER"
        return 1
    fi
    if [[ -e "$CB_GIMP_DESKTOP" || -L "$CB_GIMP_DESKTOP" ]]; then
        cb_die "Refusing to overwrite existing desktop entry: $CB_GIMP_DESKTOP"
        return 1
    fi
    if [[ -e "$(cb_state_file "$CB_GIMP_ID")" ]]; then
        cb_die "AppPilot state already exists for $CB_GIMP_ID; leaving it untouched."
        return 1
    fi

    cb_require_command od || return 1
    cb_require_command wc || return 1
    cb_check_free_kb "$CB_HOME" 650000 || return 1
    mkdir -p -- "$CB_CACHE" "$CB_APPS"
    temp_root="$(mktemp -d "$CB_CACHE/gimp-install.XXXXXX")"
    download="$temp_root/$CB_GIMP_FILE"
    cb_info "Downloading official GIMP $CB_GIMP_VERSION ARM64 AppImage..."
    cb_download "$CB_GIMP_URL" "$download" || return 1
    cb_check_min_size "$download" 100000000 || return 1

    actual="$(cb_sha256 "$download")" || return 1
    [[ "$actual" == "$CB_GIMP_SHA256" ]] || {
        cb_die "GIMP SHA-256 mismatch. Expected $CB_GIMP_SHA256; received $actual. Nothing was installed."
        return 1
    }
    magic="$(od -An -tx1 -N4 "$download" | tr -d ' \n')"
    [[ "$magic" == "7f454c46" ]] || {
        cb_die "Downloaded GIMP file is not an ELF executable. Nothing was installed."
        return 1
    }
    cb_ok "Official GIMP $CB_GIMP_VERSION checksum and ELF format verified."

    stage="$CB_APPS/.${CB_GIMP_ID}.stage.$$"
    [[ ! -e "$stage" ]] || {
        cb_die "Temporary installation path already exists: $stage"
        return 1
    }
    mkdir -- "$stage"
    cp -- "$download" "$stage/$CB_GIMP_FILE"
    chmod 755 "$stage/$CB_GIMP_FILE"
    mv -- "$stage" "$CB_GIMP_APP_DIR"

    if ! cb_gimp_install_launcher; then
        cb_warn "The verified GIMP application files remain at $CB_GIMP_APP_DIR; no existing user file was changed."
        return 1
    fi
    if ! cb_gimp_install_desktop; then
        cb_warn "The GIMP launcher and application files remain installed; no existing desktop entry was changed."
        return 1
    fi
    cb_state_write "$CB_GIMP_ID" appimage "$CB_GIMP_VERSION" "$CB_GIMP_URL"
    cb_report_installed "$CB_GIMP_ID" "GIMP $CB_GIMP_VERSION (ARM64 AppImage)"
    printf '  AppImage: %s\n' "$CB_GIMP_APP"
    printf '  SHA-256:  %s\n' "$CB_GIMP_SHA256"
    printf '  Profile:  existing GIMP settings, brushes, plug-ins and projects were not changed.\n'
}

cb_remove_gimp() {
    local state
    state="$(cb_state_file "$CB_GIMP_ID")"
    if [[ ! -r "$state" ]]; then
        cb_die 'AppPilot does not have a managed GIMP AppImage installation to remove.'
        return 1
    fi
    # Remove only exact paths created by this AppPilot feature.
    rm -f -- "$CB_GIMP_LAUNCHER" "$CB_GIMP_DESKTOP" "$state"
    rm -rf -- "$CB_GIMP_APP_DIR"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$CB_DESKTOP" >/dev/null 2>&1 || true
    fi
    cb_ok 'AppPilot GIMP application files removed. GIMP profiles, brushes, plug-ins and projects were left untouched.'
}
