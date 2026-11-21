# Cloudberry Pi AppPilot

**One command. Your applications. Your control.**

Cloudberry Pi AppPilot is a user-local Bash application manager for Raspberry Pi OS and other Linux systems. It installs, updates, checks and removes supported desktop applications without `sudo`, root access, or system-wide package changes.

- **Product:** Cloudberry Pi AppPilot
- **Command:** `cbapp`
- **Compatibility commands:** `app-install`, `app-uninstall`
- **Version:** 1.0.0
- **Primary target:** Raspberry Pi 5 / 64-bit ARM Linux
- **Repository:** `https://github.com/cloudberrypitech/cloudberry-app-pilot`

## What it manages

| Application | ARM64 support | Installation method |
|---|---|---|
| GIMP | Yes | Official ARM64 AppImage on Debian 13+/glibc 2.41+, or per-user Flatpak when Flatpak is already installed |
| JetBrains Toolbox | Yes | JetBrains official Linux ARM64 release API |
| TurboWarp Desktop | Yes | Official Linux ARM64 AppImage from the latest GitHub release |
| Generic AppImage | Depends on the AppImage | Copies a local AppImage into the user's `~/.local/opt` directory |
| Android Studio | Not officially supported on Linux ARM | AppPilot explains the limitation and does not attempt installation |

Application release information is resolved at installation/update time where the vendor provides a stable release API. GIMP's AppImage is checked against the SHA-256 value published on the official GIMP downloads page. TurboWarp's GitHub release digest is checked when GitHub publishes one for the asset.

## Requirements

- Bash 4.4 or newer
- 64-bit ARM (`aarch64`) for the curated Raspberry Pi applications
- `curl` or `wget` for downloads
- `python3` for parsing vendor release metadata
- `tar` for JetBrains Toolbox archives
- `sha256sum` or `shasum` for checksum verification
- A writable home directory

AppPilot does not install these requirements. It never calls `sudo`, `apt`, `apt-get`, `dpkg`, `snap install`, or a system-wide Flatpak installation command.

## Install AppPilot

### From the GitHub repository

```bash
git clone https://github.com/cloudberrypitech/cloudberry-app-pilot.git
cd cloudberry-app-pilot
bash install.sh
```

The installer must run from a complete repository checkout (it copies the `bin/` and `lib/` runtime files); piping only `install.sh` to Bash is not supported.

The installer copies the runtime to `~/.local/opt/cbapp` and creates these user commands:

```text
~/.local/bin/cbapp
~/.local/bin/app-install
~/.local/bin/app-uninstall
```

It refuses to overwrite unrelated files with those names. It does not edit `.bashrc`; add `~/.local/bin` to `PATH` only if your shell does not already include it.

## Commands

```bash
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

GIMP's official download page currently publishes an ARM64 AppImage and describes Debian 13 or newer as its supported Linux baseline. AppPilot obtains the current version and SHA-256 checksum directly from that official page, then verifies the download before replacing an installed AppImage.

On systems below the vendor's AppImage baseline, AppPilot can use Flatpak **only when the `flatpak` command is already installed**. It installs GIMP using Flatpak's `--user` mode. If Flatpak is not installed, AppPilot stops with an explanation; it will not install Flatpak system-wide or request root access.

The AppImage launcher uses `APPIMAGE_EXTRACT_AND_RUN=1` to avoid a FUSE mount dependency. The first launch can require substantial free temporary space; the launcher checks for approximately 1 GiB of free space before starting.

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
- **No GIMP AppImage support:** use Debian 13/Raspberry Pi OS based on Debian 13, or have Flatpak installed by an administrator once; AppPilot will then install GIMP per-user.
- **Checksum failure:** the downloaded file is discarded and is not installed. Retry later and inspect the official vendor download page.
- **AppImage extraction space:** free space in the home filesystem; AppImage extraction uses a user-local cache directory.
- **Desktop menu not refreshed:** log out and back in, or restart the desktop shell. AppPilot writes a `.desktop` entry under `~/.local/share/applications`.

## Development

```bash
git clone https://github.com/cloudberrypitech/cloudberry-app-pilot.git
cd cloudberry-app-pilot
make check
```

Bash syntax checks are included. CI also runs ShellCheck on the shell source files.

## Security model

- No root execution; running as root is rejected.
- No `sudo` calls or system package installation.
- Downloads use HTTPS.
- GIMP AppImage downloads are verified against the SHA-256 published on GIMP's official download page.
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
