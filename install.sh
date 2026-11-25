#!/usr/bin/env bash
# User-local installer for Cloudberry Pi AppPilot. Never uses sudo.
set -Eeuo pipefail
umask 077

if [[ "$(id -u)" -eq 0 ]]; then
    printf '[FAIL] Do not run this installer as root or with sudo.\n' >&2
    exit 1
fi

HOME_DIR="${HOME:-}"
[[ -n "$HOME_DIR" && "$HOME_DIR" == /* && -d "$HOME_DIR" && -w "$HOME_DIR" ]] || {
    printf '[FAIL] HOME must be an absolute, writable directory.\n' >&2
    exit 1
}

SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOCAL_DIR="$HOME_DIR/.local"
BIN_DIR="$LOCAL_DIR/bin"
OPT_DIR="$LOCAL_DIR/opt"
TARGET="$OPT_DIR/cbapp"
STAGE="$OPT_DIR/.cbapp-stage.$$"
BACKUP="$OPT_DIR/.cbapp-backup.$$"

cleanup() {
    [[ -d "$STAGE" ]] && rm -rf -- "$STAGE"
    if [[ -d "$BACKUP" && ! -e "$TARGET" ]]; then
        mv -- "$BACKUP" "$TARGET" || true
    fi
}
trap cleanup EXIT

for required in bash cp mv mkdir chmod ln readlink; do
    command -v "$required" >/dev/null 2>&1 || {
        printf '[FAIL] Required command not found: %s\n' "$required" >&2
        exit 1
    }
done

for item in bin/cbapp lib/core.sh lib/gimp.sh lib/jetbrains.sh lib/turbowarp.sh lib/appimage.sh lib/catalogue.sh; do
    [[ -r "$SOURCE_ROOT/$item" ]] || {
        printf '[FAIL] Project file is missing: %s\n' "$item" >&2
        exit 1
    }
done

mkdir -p -- "$BIN_DIR" "$OPT_DIR"

# Refuse to overwrite unrelated user commands.
for command_name in cbapp app-install app-uninstall; do
    destination="$BIN_DIR/$command_name"
    expected="$TARGET/bin/cbapp"
    if [[ -e "$destination" || -L "$destination" ]]; then
        if [[ ! -L "$destination" || "$(readlink -- "$destination")" != "$expected" ]]; then
            printf '[FAIL] Refusing to overwrite existing user file: %s\n' "$destination" >&2
            printf 'Move that file aside or remove it yourself, then rerun install.sh.\n' >&2
            exit 1
        fi
    fi
done

rm -rf -- "$STAGE"
mkdir -p -- "$STAGE"
cp -a -- "$SOURCE_ROOT/bin" "$SOURCE_ROOT/lib" "$STAGE/"
[[ ! -d "$SOURCE_ROOT/downloads" ]] || cp -a -- "$SOURCE_ROOT/downloads" "$STAGE/downloads"
[[ ! -f "$SOURCE_ROOT/VERSION" ]] || cp -- "$SOURCE_ROOT/VERSION" "$STAGE/VERSION"
[[ ! -f "$SOURCE_ROOT/LICENSE" ]] || cp -- "$SOURCE_ROOT/LICENSE" "$STAGE/LICENSE"
chmod 755 "$STAGE/bin/cbapp"

bash -n "$STAGE/bin/cbapp"
for file in "$STAGE"/lib/*.sh; do bash -n "$file"; done

if [[ -e "$TARGET" ]]; then
    mv -- "$TARGET" "$BACKUP"
fi
if ! mv -- "$STAGE" "$TARGET"; then
    printf '[FAIL] Could not move AppPilot into place. Restoring previous installation.\n' >&2
    [[ ! -d "$BACKUP" ]] || mv -- "$BACKUP" "$TARGET"
    exit 1
fi

ln -sfn -- "$TARGET/bin/cbapp" "$BIN_DIR/cbapp"
ln -sfn -- "$TARGET/bin/cbapp" "$BIN_DIR/app-install"
ln -sfn -- "$TARGET/bin/cbapp" "$BIN_DIR/app-uninstall"

rm -rf -- "$BACKUP"

printf '\n==============================================\n'
printf ' Cloudberry Pi AppPilot installed successfully\n'
printf '==============================================\n\n'
printf 'Commands:\n'
printf '  cbapp help\n'
printf '  cbapp list\n'
printf '  cbapp doctor\n'
printf '  cbapp install gimp\n'
printf '  app-install gimp       (compatibility alias)\n'
printf '  app-uninstall gimp     (compatibility alias)\n\n'

case ":${PATH}:" in
    *":$BIN_DIR:"*) ;;
    *)
        printf 'Add this line to ~/.bashrc if ~/.local/bin is not already in PATH:\n'
        printf '  export PATH="%s:$PATH"\n\n' "$BIN_DIR"
        ;;
esac

printf 'No sudo was used. AppPilot is installed under %s\n' "$LOCAL_DIR"
