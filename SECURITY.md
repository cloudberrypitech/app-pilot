# Security Policy

## Supported version

Security fixes are applied to the latest AppPilot release on the default branch.

## Reporting a vulnerability

Please do not publish exploitable details in a public issue. Contact Cloudberry Pi Technologies through the security contact listed in the GitHub organization profile, or use GitHub's private vulnerability reporting if enabled for this repository.

## Security expectations

AppPilot is designed to run as an unprivileged user. It should never need `sudo`, write to system directories, or install system packages. Downloaded binaries should be retrieved over HTTPS and verified against vendor-published digests whenever available.
