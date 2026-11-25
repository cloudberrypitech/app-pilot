#!/usr/bin/env bash
# Dynamic AppPilot catalogue: built-ins + local files + user URL/Homebrew entries.

cb_catalogue_db() { printf '%s/catalogue.tsv' "$CB_STATE"; }
cb_catalogue_downloads() { printf '%s/downloads' "$CB_STATE"; }

cb_catalogue_id() {
    local id
    id="$(cb_safe_app_id "$1")" || return 1
    [[ "$id" != "cbapp" ]] || return 1
    printf '%s' "$id"
}

cb_catalogue_add_record() {
    local id="$1" name="$2" kind="$3" source="$4" checksum="$5" description="$6"
    local db tmp
    db="$(cb_catalogue_db)"
    mkdir -p -- "$(dirname "$db")"
    touch "$db"
    if awk -F '\t' -v id="$id" '$1 == id {found=1} END {exit !found}' "$db"; then
        cb_die "Catalogue entry '$id' already exists. Remove its row from $db before replacing it."
        return 1
    fi
    tmp="${db}.new.$$"
    awk -F '\t' -v id="$id" '$1 != id' "$db" > "$tmp"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$name" "$kind" "$source" "$checksum" "$description" >> "$tmp"
    chmod 600 "$tmp"
    mv -f -- "$tmp" "$db"
    cb_ok "Added '$name' to the AppPilot catalogue."
}

cb_catalogue_add_file() {
    local source="${1:-}" name="${2:-}" id dest
    [[ -n "$source" && -f "$source" && -r "$source" ]] || { cb_die 'Usage: cbapp add-file /path/to/Application.AppImage [Name]'; return 1; }
    case "$source" in *.AppImage|*.appimage) ;; *) cb_die 'Currently, local catalogue files must be AppImage files.'; return 1 ;; esac
    name="${name:-$(basename "$source")}"
    name="${name%.*}"
    id="$(cb_catalogue_id "$name")" || { cb_die 'Invalid application name.'; return 1; }
    mkdir -p -- "$(cb_catalogue_downloads)"
    dest="$(cb_catalogue_downloads)/$id.AppImage"
    cp -- "$source" "$dest"
    chmod 755 "$dest"
    cb_catalogue_add_record "$id" "$name" appimage "$dest" "" "Local AppImage package"
}

cb_catalogue_add_url() {
    local name="${1:-}" url="${2:-}" checksum="${3:-}" id
    [[ -n "$name" && -n "$url" ]] || { cb_die 'Usage: cbapp add-url "Application Name" https://example.com/App.AppImage [SHA256]'; return 1; }
    [[ "$url" == https://* ]] || { cb_die 'Download URLs must use HTTPS.'; return 1; }
    [[ "$url" =~ \.([Aa][Pp][Pp][Ii][Mm][Aa][Gg][Ee])([?#].*)?$ ]] || { cb_die 'The URL must point directly to an .AppImage file.'; return 1; }
    if [[ -n "$checksum" && ! "$checksum" =~ ^[A-Fa-f0-9]{64}$ ]]; then
        cb_die 'SHA-256 must contain exactly 64 hexadecimal characters.'; return 1
    fi
    id="$(cb_catalogue_id "$name")" || { cb_die 'Invalid application name.'; return 1; }
    cb_catalogue_add_record "$id" "$name" url "$url" "${checksum,,}" "HTTPS AppImage download"
}

cb_catalogue_add_brew() {
    local name="${1:-}" formula="${2:-}" id
    [[ -n "$name" && -n "$formula" ]] || { cb_die 'Usage: cbapp add-brew "Application Name" homebrew/formula'; return 1; }
    [[ "$formula" =~ ^[A-Za-z0-9@._+-]+(/[A-Za-z0-9@._+-]+)?$ ]] || { cb_die 'Invalid Homebrew formula or cask name.'; return 1; }
    id="$(cb_catalogue_id "$name")" || { cb_die 'Invalid application name.'; return 1; }
    cb_catalogue_add_record "$id" "$name" brew "$formula" "" "Homebrew formula or cask"
}

cb_catalogue_list() {
    local db file id name kind source checksum description
    db="$(cb_catalogue_db)"
    printf '\n%-20s %-22s %s\n' 'APPLICATION' 'SOURCE' 'DETAIL'
    if [[ -r "$db" ]]; then
        while IFS=$'\t' read -r id name kind source checksum description; do
            [[ -n "$id" ]] || continue
            printf '%-20s %-22s %s\n' "$id" "$kind" "$description"
        done < "$db"
    fi
    local scan_dir
    for scan_dir in "$CB_ROOT/downloads" "$(cb_catalogue_downloads)"; do
        [[ -d "$scan_dir" ]] || continue
        shopt -s nullglob
        for file in "$scan_dir"/*.AppImage "$scan_dir"/*.appimage; do
            id="$(basename "$file")"
            printf '%-20s %-22s %s\n' "${id%.*}" 'local AppImage' 'Discovered local package'
        done
        shopt -u nullglob
    done
    printf '\nAdd packages with: cbapp add-file FILE [NAME], cbapp add-url NAME HTTPS_URL [SHA256], or cbapp add-brew NAME FORMULA\n\n'
}

cb_catalogue_install() {
    local id="$1" db row name kind source checksum description downloaded
    db="$(cb_catalogue_db)"
    row=""
    [[ ! -r "$db" ]] || row="$(awk -F '\t' -v id="$id" '$1 == id {print; exit}' "$db")"
    if [[ -z "$row" ]]; then
        local candidate
        for candidate in "$CB_ROOT/downloads/$id.AppImage" "$CB_ROOT/downloads/$id.appimage"; do
            if [[ -f "$candidate" ]]; then
                cb_install_generic_appimage "$candidate" "$id"
                return
            fi
        done
        cb_die "No catalogue entry for '$id'. Add one with cbapp add-file, add-url, or add-brew."
        return 1
    fi
    IFS=$'\t' read -r id name kind source checksum description <<< "$row"
    case "$kind" in
        appimage)
            [[ -f "$source" ]] || { cb_die "Catalogue package is missing: $source"; return 1; }
            cb_install_generic_appimage "$source" "$name"
            ;;
        url)
            downloaded="$CB_CACHE/catalogue-$id.AppImage"
            cb_download "$source" "$downloaded"
            cb_check_min_size "$downloaded" 1000000
            if [[ -n "$checksum" ]]; then
                local actual
                actual="$(cb_sha256 "$downloaded")"
                [[ "$actual" == "$checksum" ]] || { rm -f -- "$downloaded"; cb_die "SHA-256 mismatch for '$name'; file discarded."; return 1; }
            else
                cb_warn "No SHA-256 was supplied for '$name'. The HTTPS download will be installed without checksum verification."
            fi
            chmod 755 "$downloaded"
            cb_install_generic_appimage "$downloaded" "$name"
            ;;
        brew)
            command -v brew >/dev/null 2>&1 || { cb_die 'Homebrew is required for this catalogue entry. Install Homebrew first.'; return 1; }
            if [[ "$(uname -s)" != Darwin ]]; then
                cb_die 'Homebrew formula entries can only be installed on macOS.'
                return 1
            fi
            brew install --cask "$source"
            cb_state_write "$id" homebrew managed "$source"
            cb_ok "$name installed with Homebrew."
            ;;
        *) cb_die "Unsupported catalogue type: $kind"; return 1 ;;
    esac
}
