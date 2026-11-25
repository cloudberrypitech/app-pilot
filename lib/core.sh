#!/usr/bin/env bash
# Shared runtime functions for Cloudberry Pi AppPilot.

CB_NAME="Cloudberry Pi AppPilot"
CB_VERSION="1.2.0"
CB_HOME="${HOME:?HOME must be set}"
CB_LOCAL="${CB_HOME}/.local"
CB_BIN="${CB_LOCAL}/bin"
CB_OPT="${CB_LOCAL}/opt"
CB_APPS="${CB_OPT}"
CB_DESKTOP="${CB_LOCAL}/share/applications"
CB_CACHE="${XDG_CACHE_HOME:-${CB_HOME}/.cache}/cbapp"
CB_STATE="${XDG_STATE_HOME:-${CB_HOME}/.local/state}/cbapp"
CB_LOG="${CB_STATE}/cbapp.log"
CB_LOCK="${CB_STATE}/install.lock"
CB_LOCKED=0
CB_STAGE=""

if [[ -t 1 ]]; then
    CB_C_RESET=$'\033[0m'
    CB_C_BLUE=$'\033[1;34m'
    CB_C_GREEN=$'\033[1;32m'
    CB_C_YELLOW=$'\033[1;33m'
    CB_C_RED=$'\033[1;31m'
else
    CB_C_RESET=""; CB_C_BLUE=""; CB_C_GREEN=""; CB_C_YELLOW=""; CB_C_RED=""
fi

cb_info() { printf '%s[INFO]%s %s\n' "$CB_C_BLUE" "$CB_C_RESET" "$*"; }
cb_ok()   { printf '%s[ OK ]%s %s\n' "$CB_C_GREEN" "$CB_C_RESET" "$*"; }
cb_warn() { printf '%s[WARN]%s %s\n' "$CB_C_YELLOW" "$CB_C_RESET" "$*" >&2; }
cb_die()  { printf '%s[FAIL]%s %s\n' "$CB_C_RED" "$CB_C_RESET" "$*" >&2; return 1; }

cb_cleanup() {
    local rc=$?
    if [[ -n "${CB_STAGE:-}" && -d "$CB_STAGE" ]]; then
        rm -rf -- "$CB_STAGE" || true
    fi
    if [[ "${CB_LOCKED:-0}" == "1" && -d "$CB_LOCK" ]]; then
        rm -rf -- "$CB_LOCK" || true
    fi
    return "$rc"
}

cb_on_error() {
    local rc=$?
    local line="${1:-?}"
    local cmd="${2:-unknown}"
    trap - ERR
    printf '\n%s[ERROR]%s command failed (exit %s) at line %s:\n  %s\n' \
        "$CB_C_RED" "$CB_C_RESET" "$rc" "$line" "$cmd" >&2
    printf 'AppPilot log: %s\n' "$CB_LOG" >&2
    exit "$rc"
}

cb_require_user() {
    [[ -n "${CB_HOME:-}" && "$CB_HOME" == /* && -d "$CB_HOME" ]] || \
        { cb_die 'HOME must be an absolute path to an existing directory.'; return 1; }
    if [[ "$(id -u)" -eq 0 ]]; then
        cb_die 'Do not run AppPilot as root or with sudo. Run it as your regular user.'
        return 1
    fi
    [[ -w "$CB_HOME" ]] || { cb_die "Home directory is not writable: $CB_HOME"; return 1; }
}

cb_setup_dirs() {
    mkdir -p -- "$CB_BIN" "$CB_OPT" "$CB_DESKTOP" "$CB_CACHE" "$CB_STATE/apps" "$CB_STATE/backups"
    chmod 700 "$CB_STATE" "$CB_STATE/apps" 2>/dev/null || true
}

cb_setup_logging() {
    cb_setup_dirs
    touch "$CB_LOG" || { cb_die "Cannot write log file: $CB_LOG"; return 1; }
    chmod 600 "$CB_LOG" 2>/dev/null || true
    # Duplicate output to the per-user log without changing the caller's shell.
    exec > >(tee -a "$CB_LOG") 2>&1
}

cb_acquire_lock() {
    cb_setup_dirs
    if ! mkdir -- "$CB_LOCK" 2>/dev/null; then
        local old_pid=""
        [[ -r "$CB_LOCK/pid" ]] && old_pid="$(cat "$CB_LOCK/pid" 2>/dev/null || true)"
        if [[ "$old_pid" =~ ^[0-9]+$ ]] && kill -0 "$old_pid" 2>/dev/null; then
            cb_die "Another AppPilot operation is running (PID $old_pid)."
            return 1
        fi
        cb_die "A stale lock exists at $CB_LOCK. Confirm no AppPilot operation is running, then remove that directory and retry."
        return 1
    fi
    printf '%s\n' "$$" > "$CB_LOCK/pid"
    CB_LOCKED=1
}

cb_require_command() {
    command -v "$1" >/dev/null 2>&1 || { cb_die "Required command not found: $1"; return 1; }
}

cb_require_download_tool() {
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        cb_die 'Neither curl nor wget is installed. AppPilot will not install system packages.'
        return 1
    fi
}

cb_require_arm64() {
    local machine
    machine="$(uname -m)"
    [[ "$machine" == "aarch64" || "$machine" == "arm64" ]] || {
        cb_die "This catalogue entry requires 64-bit ARM (aarch64); detected: $machine"
        return 1
    }
    local bits
    bits="$(getconf LONG_BIT 2>/dev/null || printf unknown)"
    [[ "$bits" == "64" ]] || { cb_die "64-bit userspace required; getconf reports: $bits"; return 1; }
}

cb_download() {
    local url="$1" destination="$2"
    cb_require_download_tool || return 1
    mkdir -p -- "$(dirname -- "$destination")"
    if command -v curl >/dev/null 2>&1; then
        curl --fail --location --show-error --connect-timeout 25 --retry 4 --retry-delay 3 \
            --output "$destination" "$url"
    else
        wget --https-only --tries=4 --timeout=25 --show-progress --output-document="$destination" "$url"
    fi
    [[ -s "$destination" ]] || { cb_die "Download returned an empty file: $url"; return 1; }
}

cb_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        cb_die 'A SHA-256 utility (sha256sum or shasum) is required for checksum verification.'
        return 1
    fi
}

cb_check_min_size() {
    local file="$1" minimum="$2" actual
    actual="$(wc -c < "$file" | tr -d '[:space:]')"
    [[ "$actual" =~ ^[0-9]+$ ]] || { cb_die "Could not determine file size: $file"; return 1; }
    (( actual >= minimum )) || { cb_die "Downloaded file is suspiciously small ($actual bytes): $file"; return 1; }
}

cb_check_free_kb() {
    local path="$1" required_kb="$2" free_kb
    mkdir -p -- "$path"
    free_kb="$(df -Pk "$path" | awk 'NR==2 {print $4}')"
    [[ "$free_kb" =~ ^[0-9]+$ ]] || { cb_warn "Could not determine available disk space at $path"; return 0; }
    (( free_kb >= required_kb )) || {
        cb_die "Insufficient free space at $path: need about $((required_kb / 1024)) MiB, have about $((free_kb / 1024)) MiB."
        return 1
    }
}

cb_state_file() { printf '%s/apps/%s.conf' "$CB_STATE" "$1"; }

cb_state_get() {
    local app="$1" key="$2" file
    file="$(cb_state_file "$app")"
    [[ -r "$file" ]] || return 0
    awk -F= -v wanted="$key" '$1 == wanted {sub(/^[^=]*=/, ""); print; exit}' "$file"
}

cb_state_write() {
    local app="$1" backend="$2" version="$3" source="$4" file tmp
    file="$(cb_state_file "$app")"
    tmp="${file}.new.$$"
    {
        printf 'App=%s\n' "$app"
        printf 'Backend=%s\n' "$backend"
        printf 'Version=%s\n' "$version"
        printf 'Source=%s\n' "$source"
        printf 'InstalledAt=%s\n' "$(date -Is 2>/dev/null || date)"
    } > "$tmp"
    chmod 600 "$tmp"
    mv -f -- "$tmp" "$file"
}

cb_desktop_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    value="${value//\`/\\\`}"
    printf '%s' "$value"
}

cb_write_desktop() {
    local id="$1" name="$2" comment="$3" exec_line="$4" icon="$5" categories="$6"
    local file="$CB_DESKTOP/$id.desktop" tmp try_exec
    tmp="${file}.new.$$"
    try_exec="${exec_line%% *}"
    try_exec="${try_exec#\"}"
    try_exec="${try_exec%\"}"
    {
        printf '[Desktop Entry]\n'
        printf 'Version=1.0\nType=Application\n'
        printf 'Name=%s\n' "$name"
        printf 'GenericName=%s\n' "$name"
        printf 'Comment=%s\n' "$comment"
        printf 'Exec=%s\n' "$exec_line"
        printf 'TryExec=%s\n' "$try_exec"
        printf 'Icon=%s\n' "$icon"
        printf 'Terminal=false\nStartupNotify=true\n'
        printf 'Categories=%s;\n' "$categories"
    } > "$tmp"
    chmod 644 "$tmp"
    mv -f -- "$tmp" "$file"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$CB_DESKTOP" >/dev/null 2>&1 || cb_warn 'Could not refresh the desktop application database; the .desktop entry was still written.'
    fi
}

cb_remove_desktop() {
    rm -f -- "$CB_DESKTOP/$1.desktop"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$CB_DESKTOP" >/dev/null 2>&1 || true
    fi
}

cb_report_installed() {
    local app="$1" label="$2"
    cb_ok "$label installed for this user."
    printf '  Launcher: %s/%s\n' "$CB_BIN" "$app"
    printf '  Menu:     %s/%s.desktop\n' "$CB_DESKTOP" "$app"
    printf '  Log:      %s\n' "$CB_LOG"
}

cb_print_version() {
    printf '%s %s\n' "$CB_NAME" "$CB_VERSION"
}
