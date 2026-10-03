# GridLens installer

GridLens is a self-hosted dashboard for Nosana operators. Monitoring runs on host
PCs; phones and laptops are viewing devices. **v0.3.6 supports your existing VPN or guided WireGuard setup,
with familiar LAN dashboard addresses and browser sign-in links.**

Choose **Use my existing VPN or home Wi-Fi** to skip VPN setup for that device.
Users without an existing connection can follow guided GridLens WireGuard setup.
Existing-network browsers receive a one-time sign-in link, so no generated
password needs to be typed. The link expires after ten minutes; the browser stays
signed in for thirty days and device revocation still applies.

The managed connection can open the dashboard using the PC's private LAN address
and dashboard port. It remains limited to this dashboard, not the rest of the LAN.
Old profiles and their original links keep working; setup explains the one-time
AllowedIPs addition for eligible existing profiles without replacing their keys.
Local endpoints using that same LAN address and uncertain hostname routes retain
the original tunnel address to avoid a routing loop.

New installations beside an older dashboard prefer free four-digit ports. To move
an existing Docker dashboard explicitly, add `--http-port 8789` to the upgrade
command below. The installer checks availability and preserves the old port in its
rollback backup. Ordinary reruns and upgrades without that option keep saved ports.

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

1. Name the PC in GridLens, choose remote or local-only use, and select home or managed-network guidance.
2. Install or open the official WireGuard client using the displayed app link/QR.
3. Scan and save the **VPN profile QR inside WireGuard**. No additional phone password is needed.
4. Turn on one saved connection and follow its authenticated dashboard connection test.

The PC name labels it in GridLens; accepting the detected name does not rename
your computer. For remote home use, the address question asks for the router's
public IPv4 address under WAN/Internet IP, or its hostname. Setup explains the
exact UDP forwarding rule separately, using the PC's private address as its target.

When no public IPv4 is assigned to the PC, remote setup checks `api.ipify.org`
over HTTPS and says **"Your public Internet IPv4 address may be ..."**. A VPN or
upstream NAT can make the observed address differ from the router's WAN address.
The question is **Home Public Internet IPv4 address (or hostname)**; press Enter
to accept the suggestion or replace it. Failed lookups allow manual entry.
Local-only setup, saved-installation reruns and ordinary monitoring do not make
this lookup, and no credentials or fleet data are sent to the address service.

The phone does not need an existing VPN or a private setup page to begin. Use its
ordinary camera for the app/dashboard links, and WireGuard's scanner for the VPN
profile. QR encoding is local. Keep the profile and login private.

Setup uses spaced sections, bold prompts and color on compatible terminals.
Detailed router troubleshooting is available through `help`, and an app-install
QR is skipped when WireGuard is already installed. A recovery login for access
without WireGuard is optional. LAN access uses a normal sign-in page with
**Show/Hide password**, clear retry messages and a remembered browser session.
Older saved Docker installations need the explicit upgrade below to enable
automatic WireGuard sign-in; the same saved phone profile continues to work.
The dashboard opens directly, with device help available on demand. Copy link
also attempts copying on private HTTP connections; if the browser blocks it,
the selected address remains available for manual copying.

At home, the phone can test a private address on the hosts' Wi-Fi. Away access
requires reachable UDP through public IPv4 forwarding or a global IPv6 address
with inbound permission. Setup supplies home-router guidance or a copyable
request for the network administrator. Router changes are manual; CGNAT/provider
filtering can prevent access. There is no hosted relay or automatic VPN failover.

Where configured, a device can save separate IPv4 and IPv6 profiles under one
GridLens login, using distinct peer keys. Keep only one profile active at a time.
Removing a lost device revokes both profiles; cancelling an added profile keeps
the existing one. Save the switching instructions before leaving setup. Prefer
IPv4 when both tests pass; an untested alternate is not a working backup.

The connection test reports authenticated dashboard access, VPN activity,
server-observed transport family and user-confirmed mobile-data use separately.
Turn off phone Wi-Fi for a remote test. Detecting IPv6 on the PC does not prove
that the phone can connect, and a successful test covers its current network only.

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

Existing Docker installations retain their saved image on ordinary reruns.
To explicitly upgrade the owned containers with a consistent volume backup:

```bash
curl -fsSL https://raw.githubusercontent.com/MachoDrone/gridlens-installer/main/start.sh | bash -s -- --upgrade
```

v0.3.5 reports **already up to date** if the installed image and requested network
settings already match. It does not restart GridLens or create another backup in
that case. Updates show a short result and your dashboard link.

Use `--rollback` instead to restore the retained pre-upgrade state and image;
post-backup account/settings changes are reverted. Supply the same `--prefix` if
the installation used a custom prefix. Only owned Docker resources participate.

Each participating PC can optionally provide its own VPN entry. Save a separate
profile for each and switch manually if needed. First-PC setup starts with
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
not hardware-tested. The v0.3.1 update also passed isolated Docker IPv4 connection
proof, spoofed-LAN rejection, native IPv6 transport inside a Docker bridge,
restart, and an actual v0.3.0-to-v0.3.1 upgrade and rollback using the same saved
profile/login. Public IPv6 and Android mobile-data acceptance remain pending;
the existing lab has no global IPv6 route. Detailed validation is bundled with
the installer.

Releases contain `gridlens-linux-amd64.tar.gz`, `gridlens-linux-arm64.tar.gz` and
`SHA256SUMS`. The bootstrap pins downloads to one release and verifies checksum,
Docker metadata, archive layout and native architecture before execution. The new
bootstrap refuses old host-service packages. Checksums provide repository integrity,
not an independently signed maintainer identity.

This public repository contains only the bootstrap, instructions, license and
release assets. Application source history remains private. The package contains
the executable, reviewed installer helpers and image recipe. GitHub is used for
distribution; runtime collection and replication do not depend on GitHub or a laptop.
