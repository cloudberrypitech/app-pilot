#!/usr/bin/env bash
# Optional Zenity interface for Cloudberry Pi AppPilot.
# Loaded by bin/cbapp; all actions use the same catalogue and installers.

cb_gui_error() {
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="AppPilot" --text="$*" 2>/dev/null || true
    else
        printf '[FAIL] %s\n' "$*" >&2
    fi
}

cb_gui_info() {
    zenity --info --title="AppPilot" --width=420 --text="$*" 2>/dev/null || true
}

cb_gui_output() {
    local title="$1" output="$2" tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/app-pilot-gui.XXXXXX")" || return 1
    printf '%s\n' "$output" > "$tmp"
    zenity --text-info --title="$title" --width=760 --height=520 --filename="$tmp" 2>/dev/null || true
    rm -f -- "$tmp"
}

cb_gui_capture() {
    local title="$1" text="$2"
    zenity --entry --title="AppPilot — $title" --text="$text" --width=520 2>/dev/null
}

cb_gui_installed_ids() {
    local file id
    printf '%s\n' gimp jetbrains turbowarp
    if [[ -r "$(cb_catalogue_db)" ]]; then
        cut -f1 "$(cb_catalogue_db)"
    fi
    if [[ -d "$CB_ROOT/downloads" ]]; then
        find "$CB_ROOT/downloads" -maxdepth 1 -type f \( -iname '*.AppImage' \) -printf '%f\n' 2>/dev/null |
            sed -E 's/\.[Aa][Pp][Pp][Ii][Mm][Aa][Gg][Ee]$//'
    fi
}

cb_gui_install() {
    local selected
    local -a rows=(gimp "GIMP (official ARM64 AppImage)" jetbrains "JetBrains Toolbox" turbowarp "TurboWarp Desktop" appimage "Choose a local AppImage file")
    if [[ -r "$(cb_catalogue_db)" ]]; then
        while IFS=
    [[ -n "$selected" ]] || return 0
    if [[ "$selected" == appimage ]]; then
        local file name
        file="$(zenity --file-selection --title="Choose an AppImage" --file-filter="AppImage | *.AppImage *.appimage" 2>/dev/null)" || return 0
        name="$(basename "$file")"
        name="${name%.*}"
        cb_catalogue_add_file "$file" "$name" || { cb_gui_error "Could not add $name. See the AppPilot log."; return 1; }
        selected="$(cb_catalogue_id "$name")"
    fi
    if cb_install "$selected"; then
        cb_gui_info "$selected was installed successfully."
    else
        cb_gui_error "Installation of $selected failed. See $CB_LOG for details."
    fi
}

cb_gui_remove() {
    local selected file
    local -a rows=(gimp jetbrains turbowarp)
    if [[ -d "$CB_STATE/apps" ]]; then
        for file in "$CB_STATE"/apps/*.conf; do
            [[ -e "$file" ]] || continue
            rows+=("$(basename "$file" .conf)")
        done
    fi
    selected="$(zenity --list --title="AppPilot — Remove application" \
        --text="Choose an application managed by AppPilot" --width=560 --height=360 \
        --column="Application" "${rows[@]}" 2>/dev/null)" || return 0
    [[ -n "$selected" ]] || return 0
    if zenity --question --title="Confirm removal" --text="Remove $selected using AppPilot?" 2>/dev/null; then
        if cb_remove "$selected"; then cb_gui_info "$selected was removed."
        else cb_gui_error "Could not remove $selected. See $CB_LOG."; fi
    fi
}

cb_gui_add_url() {
    local values name url checksum
    values="$(zenity --forms --title="AppPilot — Add download URL" --text="Register a direct HTTPS AppImage URL" \
        --add-entry="Application name" --add-entry="HTTPS download URL" --add-entry="SHA-256 (optional)" --width=620 2>/dev/null)" || return 0
    IFS='|' read -r name url checksum <<< "$values"
    [[ -n "$name" && -n "$url" ]] || { cb_gui_error "Application name and URL are required."; return 1; }
    if cb_catalogue_add_url "$name" "$url" "$checksum"; then cb_gui_info "$name was added to the catalogue."
    else cb_gui_error "Could not add $name. Check the URL and optional SHA-256."; fi
}

cb_gui_add_file() {
    local file name
    file="$(zenity --file-selection --title="Choose an AppImage to add" --file-filter="AppImage | *.AppImage *.appimage" 2>/dev/null)" || return 0
    name="$(basename "$file")"
    name="${name%.*}"
    if cb_catalogue_add_file "$file" "$name"; then cb_gui_info "$name was added to the catalogue."
    else cb_gui_error "Could not add this file. Only readable .AppImage files can be added."; fi
}

cb_gui_main() {
    command -v zenity >/dev/null 2>&1 || {
        cb_die "Zenity is not installed. Install Zenity using your operating system's package manager, then run: alp --gui"
        return 1
    }
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || {
        cb_gui_error "No graphical display session was detected. Run alp --gui from your desktop session."
        return 1
    }
    cb_require_user || return 1
    cb_setup_logging
    cb_acquire_lock || return 1
    while true; do
        local choice
        choice="$(zenity --list --title="Cloudberry Pi AppPilot" \
            --text="One command. Your applications. Your control." \
            --width=520 --height=420 --column="Action" \
            "Install application" \
            "Remove application" \
            "Add local AppImage" \
            "Add download URL" \
            "View application catalogue" \
            "Installation status" \
            "Run system diagnostics" \
            "Exit" 2>/dev/null)" || return 0
        case "$choice" in
            "Install application") cb_gui_install ;;
            "Remove application") cb_gui_remove ;;
            "Add local AppImage") cb_gui_add_file ;;
            "Add download URL") cb_gui_add_url ;;
            "View application catalogue") cb_gui_output "AppPilot catalogue" "$(cb_list)" ;;
            "Installation status") cb_gui_output "AppPilot status" "$(cb_status)" ;;
            "Run system diagnostics") cb_gui_output "AppPilot diagnostics" "$(cb_doctor 2>&1)" ;;
            "Exit"|"") return 0 ;;
        esac
    done
}
\t' read -r id name rest; do
            [[ -n "$id" ]] || continue
            rows+=("$id" "$name")
        done < "$(cb_catalogue_db)"
    fi
    selected="$(zenity --list --title="AppPilot — Install application" \
        --text="Choose an application to install" --width=620 --height=420 \
        --column="Application" --column="Description" "${rows[@]}" 2>/dev/null)" || return 0
    [[ -n "$selected" ]] || return 0
    if [[ "$selected" == appimage ]]; then
        local file name
        file="$(zenity --file-selection --title="Choose an AppImage" --file-filter="AppImage | *.AppImage *.appimage" 2>/dev/null)" || return 0
        name="$(basename "$file")"
        name="${name%.*}"
        cb_catalogue_add_file "$file" "$name" || { cb_gui_error "Could not add $name. See the AppPilot log."; return 1; }
        selected="$(cb_catalogue_id "$name")"
    fi
    if cb_install "$selected"; then
        cb_gui_info "$selected was installed successfully."
    else
        cb_gui_error "Installation of $selected failed. See $CB_LOG for details."
    fi
}

cb_gui_remove() {
    local selected
    selected="$(zenity --list --title="AppPilot — Remove application" \
        --text="Choose an application managed by AppPilot" --width=560 --height=360 \
        --column="Application" gimp jetbrains turbowarp \
        $(if [[ -d "$CB_STATE/apps" ]]; then find "$CB_STATE/apps" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' | sed 's/\.conf$//'; fi) \
        2>/dev/null)" || return 0
    [[ -n "$selected" ]] || return 0
    if zenity --question --title="Confirm removal" --text="Remove $selected using AppPilot?" 2>/dev/null; then
        if cb_remove "$selected"; then cb_gui_info "$selected was removed."
        else cb_gui_error "Could not remove $selected. See $CB_LOG."; fi
    fi
}

cb_gui_add_url() {
    local values name url checksum
    values="$(zenity --forms --title="AppPilot — Add download URL" --text="Register a direct HTTPS AppImage URL" \
        --add-entry="Application name" --add-entry="HTTPS download URL" --add-entry="SHA-256 (optional)" --width=620 2>/dev/null)" || return 0
    IFS='|' read -r name url checksum <<< "$values"
    [[ -n "$name" && -n "$url" ]] || { cb_gui_error "Application name and URL are required."; return 1; }
    if cb_catalogue_add_url "$name" "$url" "$checksum"; then cb_gui_info "$name was added to the catalogue."
    else cb_gui_error "Could not add $name. Check the URL and optional SHA-256."; fi
}

cb_gui_add_file() {
    local file name
    file="$(zenity --file-selection --title="Choose an AppImage to add" --file-filter="AppImage | *.AppImage *.appimage" 2>/dev/null)" || return 0
    name="$(basename "$file")"
    name="${name%.*}"
    if cb_catalogue_add_file "$file" "$name"; then cb_gui_info "$name was added to the catalogue."
    else cb_gui_error "Could not add this file. Only readable .AppImage files can be added."; fi
}

cb_gui_main() {
    command -v zenity >/dev/null 2>&1 || {
        cb_die "Zenity is not installed. Install Zenity using your operating system's package manager, then run: alp --gui"
        return 1
    }
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || {
        cb_gui_error "No graphical display session was detected. Run alp --gui from your desktop session."
        return 1
    }
    cb_require_user || return 1
    cb_setup_logging
    while true; do
        local choice
        choice="$(zenity --list --title="Cloudberry Pi AppPilot" \
            --text="One command. Your applications. Your control." \
            --width=520 --height=420 --column="Action" \
            "Install application" \
            "Remove application" \
            "Add local AppImage" \
            "Add download URL" \
            "View application catalogue" \
            "Installation status" \
            "Run system diagnostics" \
            "Exit" 2>/dev/null)" || return 0
        case "$choice" in
            "Install application") cb_gui_install ;;
            "Remove application") cb_gui_remove ;;
            "Add local AppImage") cb_gui_add_file ;;
            "Add download URL") cb_gui_add_url ;;
            "View application catalogue") cb_gui_output "AppPilot catalogue" "$(cb_list)" ;;
            "Installation status") cb_gui_output "AppPilot status" "$(cb_status)" ;;
            "Run system diagnostics") cb_gui_output "AppPilot diagnostics" "$(cb_doctor 2>&1)" ;;
            "Exit"|"") return 0 ;;
        esac
    done
}
