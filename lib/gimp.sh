#!/usr/bin/env bash

cb_gimp_appimage_supported() {
    local os_id="" os_version="" libc_line="" libc_version="" libc_major="" libc_minor=""
    if [[ -r /etc/os-release ]]; then
        os_id="$(sed -n 's/^ID=//p' /etc/os-release | head -n1 | tr -d '"')"
        os_version="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | head -n1 | tr -d '"')"
    fi
    if [[ "$os_id" == "debian" && "$os_version" =~ ^([0-9]+) ]]; then
        (( BASH_REMATCH[1] >= 13 )) && return 0
    fi
    libc_line="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
    libc_version="${libc_line##* }"
    if [[ "$libc_version" =~ ^([0-9]+)\.([0-9]+) ]]; then
        libc_major="${BASH_REMATCH[1]}"
        libc_minor="${BASH_REMATCH[2]}"
        if (( libc_major > 2 || (libc_major == 2 && libc_minor >= 41) )); then
            return 0
        fi
    fi
    return 1
}

cb_gimp_fetch_release_metadata() {
    cb_require_command python3 || return 1
    local page="$CB_CACHE/gimp-downloads.html"
    cb_download 'https://www.gimp.org/downloads/' "$page" || return 1
    python3 - "$page" <<'PY'
import html
import re
import sys
from html.parser import HTMLParser

class Text(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
    def handle_data(self, data):
        self.parts.append(data)

raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
p = Text()
p.feed(raw)
plain = html.unescape(" ".join(p.parts))

# Find the ARM64 AppImage filename and its published SHA-256 on the official page.
versions = re.findall(r"GIMP-(\d+\.\d+\.\d+)-aarch64\.AppImage", plain)
if not versions:
    raise SystemExit("Could not find an ARM64 AppImage version on the official GIMP page.")
version = versions[0]
filename = f"GIMP-{version}-aarch64.AppImage"
match = re.search(
    r"SHA256\s+hash\s+sum\s+for\s+" + re.escape(filename) + r"\s*[:：]\s*([0-9a-fA-F]{64})",
    plain,
    re.IGNORECASE,
)
if not match:
    # Accommodate formatting where the filename and checksum are separated by markup/text.
    idx = plain.find(filename)
    nearby = plain[max(0, idx - 500):idx + 1200]
    hashes = re.findall(r"\b[0-9a-fA-F]{64}\b", nearby)
    if len(hashes) != 1:
        raise SystemExit("Could not safely associate a SHA-256 checksum with the GIMP ARM64 AppImage.")
    checksum = hashes[0].lower()
else:
    checksum = match.group(1).lower()

major, minor, _patch = version.split(".")
url = f"https://download.gimp.org/gimp/v{major}.{minor}/linux/{filename}"
print(version)
print(checksum)
print(url)
PY
}

cb_gimp_write_appimage_launcher() {
    local target="$CB_BIN/.gimp.new.$$"
    cat > "$target" <<'LAUNCHER'
#!/usr/bin/env sh
set -eu
APP="$HOME/.local/opt/gimp/GIMP.AppImage"
TMPDIR="$HOME/.cache/cbapp/tmp/gimp"
if [ ! -x "$APP" ]; then
    printf '%s\n' 'GIMP AppImage is missing. Run: cbapp install gimp' >&2
    exit 127
fi
mkdir -p "$TMPDIR"
FREE_KB="$(df -Pk "$TMPDIR" 2>/dev/null | awk 'NR==2 {print $4}')"
case "$FREE_KB" in
    ''|*[!0-9]*) printf '%s\n' 'Could not determine free space for GIMP extraction.' >&2; exit 1 ;;
esac
if [ "$FREE_KB" -lt 1000000 ]; then
    printf '%s\n' 'GIMP needs approximately 1 GiB of free space for AppImage extraction.' >&2
    exit 1
fi
cd "$HOME" || exit 1
export TMPDIR APPIMAGE_EXTRACT_AND_RUN=1
exec "$APP" "$@"
LAUNCHER
    chmod 755 "$target"
    mv -f -- "$target" "$CB_BIN/gimp"
}

cb_gimp_write_flatpak_launcher() {
    local target="$CB_BIN/.gimp.new.$$"
    cat > "$target" <<'LAUNCHER'
#!/usr/bin/env sh
set -eu
if ! command -v flatpak >/dev/null 2>&1; then
    printf '%s\n' 'Flatpak is required for this GIMP installation.' >&2
    exit 127
fi
exec flatpak run --user org.gimp.GIMP "$@"
LAUNCHER
    chmod 755 "$target"
    mv -f -- "$target" "$CB_BIN/gimp"
}

cb_install_gimp_appimage() {
    local metadata version checksum url actual temp app_dir new_file
    metadata="$(cb_gimp_fetch_release_metadata)" || return 1
    version="$(printf '%s\n' "$metadata" | sed -n '1p')"
    checksum="$(printf '%s\n' "$metadata" | sed -n '2p')"
    url="$(printf '%s\n' "$metadata" | sed -n '3p')"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { cb_die 'GIMP release version could not be validated.'; return 1; }
    [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || { cb_die 'GIMP SHA-256 from the official page is invalid.'; return 1; }
    [[ "$url" == https://download.gimp.org/* ]] || { cb_die 'GIMP download URL is not from the official download host.'; return 1; }

    cb_check_free_kb "$CB_HOME" 600000 || return 1
    temp="$CB_CACHE/GIMP-${version}-aarch64.AppImage.part"
    cb_info "Downloading official GIMP ${version} ARM64 AppImage..."
    cb_download "$url" "$temp" || return 1
    cb_check_min_size "$temp" 100000000 || return 1
    actual="$(cb_sha256 "$temp")" || return 1
    [[ "$actual" == "$checksum" ]] || {
        cb_die "GIMP checksum mismatch. Expected $checksum, got $actual. The download was not installed."
        return 1
    }
    cb_ok 'GIMP official SHA-256 checksum verified.'

    app_dir="$CB_APPS/gimp"
    mkdir -p -- "$app_dir"
    new_file="$app_dir/.GIMP.AppImage.new.$$"
    cp -- "$temp" "$new_file"
    chmod 755 "$new_file"
    mv -f -- "$new_file" "$app_dir/GIMP.AppImage"
    cb_gimp_write_appimage_launcher || return 1
    cb_write_desktop gimp GIMP 'GIMP image editor' "\"$CB_BIN/gimp\" %F" applications-graphics 'Graphics;2DGraphics;RasterGraphics'
    cb_state_write gimp appimage "$version" "$url"
    cb_report_installed gimp "GIMP $version"
}

cb_install_gimp_flatpak() {
    command -v flatpak >/dev/null 2>&1 || {
        cb_die 'This OS is below GIMP AppImage vendor support and Flatpak is not installed. AppPilot will not install system packages; ask an administrator to install Flatpak once, or use Debian 13/Raspberry Pi OS based on Debian 13.'
        return 1
    }
    cb_info 'Using Flatpak in per-user mode. No system-wide installation will be performed.'
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user --noninteractive --assumeyes flathub org.gimp.GIMP
    cb_gimp_write_flatpak_launcher || return 1
    cb_write_desktop gimp GIMP 'GIMP image editor' "\"$CB_BIN/gimp\" %F" org.gimp.GIMP 'Graphics;2DGraphics;RasterGraphics'
    local version
    version="$(flatpak info --user org.gimp.GIMP 2>/dev/null | awk -F': ' '/^Version:/ {print $2; exit}')"
    version="${version:-managed by Flatpak}"
    cb_state_write gimp flatpak "$version" flathub
    cb_report_installed gimp "GIMP ($version, user Flatpak)"
}

cb_install_gimp() {
    cb_require_arm64 || return 1
    local backend
    backend="$(cb_state_get gimp Backend)"
    if [[ "$backend" == "flatpak" ]]; then
        command -v flatpak >/dev/null 2>&1 || { cb_die 'This GIMP installation uses Flatpak, but the flatpak command is unavailable.'; return 1; }
        cb_info 'Updating GIMP through the existing per-user Flatpak installation...'
        if flatpak info --user org.gimp.GIMP >/dev/null 2>&1; then
            flatpak update --user --noninteractive --assumeyes org.gimp.GIMP
        else
            flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            flatpak install --user --noninteractive --assumeyes flathub org.gimp.GIMP
        fi
        cb_gimp_write_flatpak_launcher || return 1
        cb_write_desktop gimp GIMP 'GIMP image editor' "\"$CB_BIN/gimp\" %F" org.gimp.GIMP 'Graphics;2DGraphics;RasterGraphics'
        local version
        version="$(flatpak info --user org.gimp.GIMP 2>/dev/null | awk -F': ' '/^Version:/ {print $2; exit}')"
        cb_state_write gimp flatpak "${version:-managed by Flatpak}" flathub
        cb_ok 'GIMP Flatpak update completed.'
        return 0
    fi
    if cb_gimp_appimage_supported; then
        cb_install_gimp_appimage
    else
        cb_warn 'The GIMP AppImage is listed by GIMP for Debian 13 or newer. This system does not meet that baseline.'
        if [[ -n "$backend" && "$backend" == "appimage" ]]; then
            cb_die 'The existing AppImage installation cannot be updated safely on this OS. Upgrade the OS or switch installation backend manually.'
            return 1
        fi
        cb_install_gimp_flatpak
    fi
}

cb_remove_gimp() {
    local backend
    backend="$(cb_state_get gimp Backend)"
    if [[ "$backend" == "flatpak" ]]; then
        command -v flatpak >/dev/null 2>&1 || { cb_die 'Flatpak is required to remove the installed GIMP application.'; return 1; }
        flatpak uninstall --user --noninteractive --assumeyes org.gimp.GIMP
        cb_info 'Shared Flatpak runtimes and the Flathub remote were left untouched.'
    fi
    rm -f -- "$CB_BIN/gimp"
    rm -rf -- "$CB_APPS/gimp"
    rm -f -- "$(cb_state_file gimp)"
    cb_remove_desktop gimp
    cb_ok 'GIMP application files removed. User preferences, brushes, plug-ins and projects were kept.'
}
