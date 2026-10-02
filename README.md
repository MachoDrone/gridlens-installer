# GridLens installer

GridLens is a self-hosted dashboard for Nosana operators. Monitoring runs on host
PCs; phones and laptops are viewing devices. **v0.3.0 installs GridLens in Docker
and provides the phone VPN profile directly in the host terminal.**

## Start on your Nosana PC

Run in an interactive Ubuntu/Debian host terminal, or an SSH session with a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/MachoDrone/gridlens-installer/main/start.sh | bash
```

Docker must already be installed and running. Bash, curl and Python 3 must be
available. The command downloads and verifies the matching Linux amd64/arm64
bundle automatically; no Git, Go, GitHub account or manual download is needed.
The first run prepares its image locally. Packages are installed inside the image,
never on the host OS. If sudo asks, enter the PC's password in the terminal.
Prompts use `/dev/tty` independently of the downloaded script.

Keep the terminal open and follow its steps:

1. Choose whether this PC should provide WireGuard access.
2. Install or open the official WireGuard client using the displayed app link/QR.
3. Save the GridLens login and scan the **VPN profile QR inside WireGuard**.
4. Turn the connection on and open the dashboard link or browser QR.

The phone does not need an existing VPN or a private setup page to begin. Use its
ordinary camera for the app/dashboard links, and WireGuard's scanner for the VPN
profile. QR encoding is local. Keep the profile and login private.

At home, the phone can test a private endpoint on the hosts' Wi-Fi. Away access
requires a reachable public IPv4 address or hostname and the router UDP mapping
shown by setup. Router changes are manual; CGNAT/provider filtering can prevent
access. There is no hosted relay or automatic VPN failover. A private home address
will not become reachable from mobile data just because it appears in a QR.

## Existing hubs and saved connections

A fresh PC gets core/probe containers and persistent state/observations volumes.
A confirmed GridLens hub on the same PC instead adds one Docker replica. Setup
reads only verified GridLens-owned hub identity, signed fleet data, settings and
credential hashes. It preserves the existing fleet view and leaves the old hub,
collectors, VPN, SSH and Nosana workloads running. Fresh observations on this
compatibility path still depend on those existing host collectors/fleet services;
this release does not remove or fully migrate them into Docker.

Rerun the same command to add a phone or use an existing connection. The saved
volume, image, server identity, ports and peers are reused. Existing profiles do
not need another QR scan after a container restart. Lost profiles get a distinct
replacement enrollment. Accounts copied from an older hub are independent;
revoking one in Docker does not revoke it on the older hub.

Each participating PC can optionally provide its own VPN entry. Save a separate
profile/login for each and switch manually if needed. First-PC setup starts with
one source; integrated fleet joining and shared accounts/settings remain unfinished.
The product target remains 200+ hosts with any PC eligible to serve the dashboard.

The installer creates only owned Docker resources, not host packages, users or
systemd services. Docker manages its own bridges and published-port networking.
The web container has no Docker socket. In a fresh install, a separate fixed-purpose
probe has daemon access for approved inventory checks; a read-only socket mount
is not a Docker API permission boundary.

## Validation and distribution

The Docker phone flow was exercised on nn05 and password-protected nn06. Actual
terminal profile QRs were independently decoded and used by a test WireGuard client
to open the full six-PC/eight-host dashboard. nn06 reused the same profile/login
after a Docker restart. Physical Android import, a real host reboot and outside-home
UDP access remain separate checks. Arm64 is cross-compiled and package-verified,
not hardware-tested. Detailed validation is bundled with the installer.

Releases contain `gridlens-linux-amd64.tar.gz`, `gridlens-linux-arm64.tar.gz` and
`SHA256SUMS`. The bootstrap pins downloads to one release and verifies checksum,
Docker metadata, archive layout and native architecture before execution. The new
bootstrap refuses old host-service packages. Checksums provide repository integrity,
not an independently signed maintainer identity.

This public repository contains only the bootstrap, instructions, license and
release assets. Application source history remains private. The package contains
the executable, reviewed installer helpers and image recipe. GitHub is used for
distribution; runtime collection and replication do not depend on GitHub or a laptop.
