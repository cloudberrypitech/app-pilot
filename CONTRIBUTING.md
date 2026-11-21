# Contributing

Thanks for helping improve Cloudberry Pi AppPilot.

## Before submitting

1. Keep installation operations user-local. Do not add `sudo`, root requirements, `apt install`, or system-wide package changes.
2. Validate every download URL and use a vendor checksum or digest whenever one is published.
3. Do not `source` downloaded files, release metadata, or per-app state files.
4. Quote paths and support home directories containing spaces.
5. Preserve user preferences and data during removal.
6. Add or update smoke tests for new commands and catalogue entries.

## Checks

```bash
make check
```

ShellCheck should also be run on all shell scripts:

```bash
shellcheck bin/cbapp install.sh lib/*.sh tests/*.sh
```

## Pull requests

Describe the Linux distribution and architecture used for testing, the commands tested, and any vendor release/API changes that affect the application backend.
