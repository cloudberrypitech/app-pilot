# Publishing and maintaining AppPilot

The repository is https://github.com/cloudberrypitech/cloudberry-app-pilot.

## Clone

```bash
git clone https://github.com/cloudberrypitech/cloudberry-app-pilot.git
cd cloudberry-app-pilot
```

## Install for the current user

```bash
bash install.sh
```

No sudo is needed. The installer places the runtime under `~/.local/opt/cbapp` and commands under `~/.local/bin`.

## Validate a change

```bash
make check
```

## Commit and push

```bash
git add .
git commit -m "Describe the change"
git push
```

## Install with Homebrew (macOS)\n\nAfter the formula is merged to main:\n\n```bash\nbrew install --formula https://raw.githubusercontent.com/cloudberrypitech/app-pilot/main/Formula/app-pilot.rb\n```\n\n## Tag a release

```bash
git tag -a v1.0.0 -m "AppPilot 1.0.0"
git push origin v1.0.0
```
