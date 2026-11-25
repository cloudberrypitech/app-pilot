# Cloudberry Pi AppPilot

**One command. Your applications. Your control.**

Cloudberry Pi AppPilot is a user-local Bash application manager for Raspberry Pi OS and other Linux systems. It installs, updates, checks and removes supported desktop applications without `sudo`, root access, or system-wide package changes.

- **Product:** Cloudberry Pi AppPilot
- **Commands:** `alp` (short command), `cbapp` (compatibility alias)
- **Graphical interface:** `alp --gui` (Zenity)
- **Compatibility commands:** `app-install`, `app-uninstall`
- **Version:** 1.1.0
- **Primary target:** Raspberry Pi 5 / 64-bit ARM Linux
- **Repository:** `https://github.com/cloudberrypitech/app-pilot`

## What it manages

| Application | ARM64 support | Installation method |
|---|---|---|
| GIMP | Yes | Pinned official GIMP 3.2.8 ARM64 AppImage on Debian 13+/glibc 2.41+; no Flatpak or root required |
| JetBrains Toolbox | Yes | JetBrains official Linux ARM64 release API |
| TurboWarp Desktop | Yes | Official Linux ARM64 AppImage from the latest GitHub release |
| Generic AppImage | Depends on the AppImage | Copies a local AppImage into the user's `~/.local/opt` directory |
| Android Studio | Not officially supported on Linux ARM | AppPilot explains the limitation and does not attempt installation |

JetBrains and TurboWarp release information is resolved at installation/update time where the vendor provides a stable release API. GIMP uses a pinned official ARM64 AppImage release and verifies its SHA-256 before installing. TurboWarp's GitHub release digest is checked when GitHub publishes one for the asset.

## Requirements

- Bash 4.4 or newer
- 64-bit ARM (`aarch64`) for the curated Raspberry Pi applications
- `curl` or `wget` for downloads
- `python3` for parsing vendor release metadata
- `tar` for JetBrains Toolbox archives
- `sha256sum` or `shasum` for checksum verification
- A writable home directory
- Optional: Zenity for the graphical interface (`alp --gui`)

AppPilot does not install these requirements. It never calls `sudo`, `apt`, `apt-get`, `dpkg`, `snap install`, or a system-wide Flatpak installation command.

## Install AppPilot

### From the GitHub repository

```bash
git clone https://github.com/cloudberrypitech/app-pilot.git
cd app-pilot
bash install.sh
```

The installer must run from a complete repository checkout (it copies the `bin/` and `lib/` runtime files); piping only `install.sh` to Bash is not supported.

The installer copies the runtime to `~/.local/opt/cbapp` and creates these user commands:

```text
~/.local/bin/cbapp
~/.local/bin/alp
~/.local/bin/app-install
~/.local/bin/app-uninstall
```

It refuses to overwrite unrelated files with those names. It does not edit `.bashrc`; add `~/.local/bin` to `PATH` only if your shell does not already include it.

## Graphical interface

Run `alp --gui` from your desktop session to open the optional Zenity interface. It provides graphical actions to install and remove applications, add local AppImages, register HTTPS download URLs, view the catalogue, inspect installation status, and run diagnostics. `cbapp --gui` opens the same interface. Zenity is an optional dependency and is not installed automatically; install it using your Linux distribution package manager. The GUI requires an active X11 or Wayland desktop session.

## Dynamic application catalogue

AppPilot can register new AppImages without editing its Bash source.

### Add a local download file

```bash
cbapp add-file ~/Downloads/MyApp.AppImage MyApp
cbapp list
cbapp install myapp
```

You can also place an `.AppImage` file in the repository's `downloads/` directory. The CLI discovers those files automatically; use the filename without its extension as the application ID. Files added with `add-file` are copied into `~/.local/state/cbapp/downloads/` and registered in the persistent user catalogue.

### Add a direct download URL

```bash
cbapp add-url MyApp https://downloads.example.org/MyApp.AppImage SHA256
cbapp install myapp
```

Only HTTPS direct links ending in `.AppImage` are accepted. SHA-256 is optional but recommended. If omitted, AppPilot warns that it cannot verify the downloaded file against a publisher checksum. The user catalogue is stored at `~/.local/state/cbapp/catalogue.tsv`.

### Add a Homebrew cask (macOS)

```bash
cbapp add-brew Firefox firefox
cbapp install firefox
cbapp remove firefox
```

Homebrew catalogue entries use `brew install --cask` and require macOS plus an existing Homebrew installation. The AppPilot CLI itself can be installed using the formula in `Formula/app-pilot.rb`:

```bash
brew install --formula https://raw.githubusercontent.com/cloudberrypitech/app-pilot/main/Formula/app-pilot.rb
```

## Commands

```bash
alp --gui
alp help
alp version
cbapp --gui  # compatibility alias
cbapp help
cbapp version
cbapp list
cbapp doctor
cbapp status
```

Install and update applications:

```bash
cbapp install gimp
cbapp install jetbrains
cbapp install turbowarp

cbapp update gimp
cbapp update jetbrains
cbapp update turbowarp
```

Install a local AppImage:

```bash
cbapp install appimage ~/Downloads/MyApp.AppImage MyApp
```

Remove an application installed by AppPilot:

```bash
cbapp remove gimp
cbapp remove jetbrains
cbapp remove turbowarp
cbapp remove MyApp
```

Remove AppPilot itself, without uninstalling the applications it manages:

```bash
cbapp self-uninstall
```

### Compatibility with the previous app manager

```bash
app-install gimp
app-install jetbrains
app-install turbowarp
app-uninstall gimp
```

## Where files are stored

| Purpose | Location |
|---|---|
| AppPilot runtime | `~/.local/opt/cbapp` |
| Commands and launchers | `~/.local/bin` |
| Installed application files | `~/.local/opt/<application>` |
| Desktop menu entries | `~/.local/share/applications` |
| Download cache | `~/.cache/cbapp` |
| Logs and installation state | `~/.local/state/cbapp` |

Uninstalling an application removes its AppPilot-managed program files, command launcher and desktop entry. It does not intentionally delete personal documents, GIMP brushes, plug-ins, settings, or project files. For Flatpak GIMP, shared runtimes and the Flathub remote are left in place because other user-installed Flatpak applications may need them.

## GIMP compatibility details

GIMP is installed from the official, pinned GIMP 3.2.8 ARM64 AppImage. The installer verifies the exact SHA-256 checksum and ELF executable header before placing it in a dedicated directory:

`~/.local/opt/gimp-appimage-pi-3.2.8-arm64/`

It creates the command `~/.local/bin/gimp-appimage-pi` and the desktop menu entry `~/.local/share/applications/gimp-appimage-pi.desktop`. The menu entry appears as GIMP. The launcher sets `APPIMAGE_EXTRACT_AND_RUN=1` so a FUSE mount is not required, and checks for approximately 1 GiB of free temporary space before starting.

The GIMP path requires 64-bit ARM and Debian 13+/glibc 2.41+. On an unsupported system it stops with an explanation; it does not install Flatpak, system packages, dependencies, or request root access.

**Non-destructive behaviour:** this feature uses dedicated, versioned paths and refuses to overwrite an existing application directory, launcher, desktop entry, or AppPilot state. It does not edit `.bashrc`, remove an older GIMP installation, or modify GIMP preferences, brushes, plug-ins, scripts, palettes, or project files. Re-running `cbapp install gimp` verifies an existing AppPilot-managed installation and leaves it unchanged. `cbapp remove gimp` removes only the exact AppPilot-managed GIMP 3.2.8 application directory, launcher, desktop entry and state file.

## Android Studio note

Google's official Linux installation requirements currently say Linux machines with ARM-based CPUs are not supported. AppPilot therefore does not download or install an unofficial build under the Android Studio name. See [Android Studio installation requirements](https://developer.android.com/studio/install.html).

## Diagnostics and troubleshooting

Run:

```bash
cbapp doctor
cbapp status
```

The installer and mutating app commands write a per-user log to:

```text
~/.local/state/cbapp/cbapp.log
```

Common issues:

- **`cbapp: command not found`:** check `printf '%s\\n' "$PATH"` and confirm `~/.local/bin` is included.
- **Not ARM64:** the curated applications are built for 64-bit ARM. Check `uname -m` and `getconf LONG_BIT`.
- **GIMP platform requirement:** the pinned GIMP 3.2.8 AppImage requires 64-bit ARM and Debian 13+/glibc 2.41+. AppPilot stops without making system changes when these requirements are not met.
- **Checksum failure:** the downloaded file is discarded and is not installed. Retry later and inspect the official vendor download page.
- **AppImage extraction space:** free space in the home filesystem; AppImage extraction uses a user-local cache directory.
- **Desktop menu not refreshed:** log out and back in, or restart the desktop shell. AppPilot writes a `.desktop` entry under `~/.local/share/applications`.

## Development

```bash
git clone https://github.com/cloudberrypitech/app-pilot.git
cd app-pilot
make check
```

Bash syntax checks are included. CI also runs ShellCheck on the shell source files.

## Security model

- No root execution; running as root is rejected.
- No `sudo` calls or system package installation.
- Downloads use HTTPS.
- GIMP 3.2.8 AppImage downloads are verified against the pinned official SHA-256 before installation.
- TurboWarp's asset SHA-256 is verified when the GitHub API provides an asset digest.
- Release APIs are parsed as data; downloaded executables are not sourced as shell scripts.
- User-provided AppImages are executable code. Only install files from sources you trust.
- State files are data files and are not sourced into the shell.

## Official sources

- [GIMP downloads](https://www.gimp.org/downloads/)
- [JetBrains Toolbox](https://www.jetbrains.com/toolbox-app/)
- [JetBrains release metadata API](https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release)
- [TurboWarp Desktop releases](https://github.com/TurboWarp/desktop/releases)
- [Android Studio Linux installation requirements](https://developer.android.com/studio/install.html)

## License

MIT. See [LICENSE](LICENSE).
