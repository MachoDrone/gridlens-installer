# GridLens installer

GridLens is a self-hosted dashboard for Nosana operators. Host PCs collect and
replicate observations; phones and laptops are viewing devices.

## Start on your Nosana PC

Run this single command in an interactive Ubuntu/Debian host terminal, or through
an SSH session with a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/MachoDrone/gridlens-installer/main/start.sh | bash
```

The bootstrap downloads and verifies the matching release automatically. You do
not need Git, Go, a GitHub account, or a manual package download. Bash, curl,
Python 3 and standard Linux utilities must be available. Linux amd64 and arm64
packages are provided.

If sudo asks, enter the host administrator password in the terminal. Nothing
appears while you type. Interactive prompts use the terminal independently of the
script pipe. The webapp never asks for your operating-system password.

Keep the terminal open. It prints a private setup link and a QR code you can scan
with your phone camera. The browser also offers **Open setup on my phone**.
The QR opens a page on your home PC; it does not connect the phone to your home network.
Before opening or scanning it:

- At home, connect your viewing device to the hosts' network.
- Away, turn on a VPN that already reaches your home LAN **on the phone itself** before opening the link. An SSH session on your laptop does not connect a separate phone.
- Away without that connection, first setup requires local access.

Setup-page QR codes use the phone camera. A separately labeled WireGuard profile
QR is scanned inside WireGuard. All QR encoding is local and bundled; there is no
QR package to install or online QR service. Keep these temporary codes private.

Follow the setup screen. Existing installations open device setup without being
reinstalled. Fresh installation previews changes, asks approval for missing access
packages, verifies browser access and starts monitoring on this host. Save a new
VPN profile and GridLens login before switching the VPN on.

## Current scope

This is an early release. It preserves the existing Monitor/Fleet interface.
First-host setup initializes one PC; joining further PCs and shared accounts or
settings remain separate administrator work. Existing VPN, SSH and Nosana
workloads are outside GridLens's ownership. Direct WireGuard access from outside
home requires a reachable endpoint and any necessary router forwarding.

The pipeline/terminal paths, archive checks, guided UI, activation receipts and
existing-hub setup have automated and lab coverage. A complete fresh-OS wizard
installation, physical phone import and direct outside-network access remain
unverified. Arm64 is cross-compiled; hardware execution is not yet validated.
Details are included in the installer documentation.

## Release contents

Each version provides `gridlens-linux-amd64.tar.gz`,
`gridlens-linux-arm64.tar.gz`, and `SHA256SUMS`. The bootstrap pins all downloads
to one release and validates the checksum, metadata and architecture before
starting the installer. SHA256SUMS is an integrity check from this repository,
not an independently signed maintainer identity.

This repository hosts only the bootstrap, operator instructions, license and
release assets. Application source history remains in the private development
repository. The packages contain the executable and required Python helpers.
GitHub is used for distribution, not runtime monitoring or replication.
