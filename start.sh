#!/usr/bin/env bash
# Standalone GitHub bootstrap. No checkout, compiler, or manual download required.
# Keep all work inside this function and the final compound invocation: bash must
# finish parsing it before any installer work can run from a downloaded stream.
gridlens_bootstrap() (
 set -euo pipefail
 umask 077

 fail() { printf 'GridLens: %s\n' "$*" >&2; exit 1; }
 if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  printf '%s\n' 'GridLens Docker installer from GitHub' \
   'Run in a host terminal, or an SSH session with a terminal.' \
   'The installer downloads and checks a Docker-only release automatically.' \
   'A separately verified terminal coordinator preserves newer installed builds.' \
   'An existing local Docker daemon is required; no host packages or services are installed.' \
   'Administrator prompts use your terminal, never the downloaded script input.' \
   'Optional: GRIDLENS_VERSION=vX.Y.Z pins a release; GRIDLENS_REPOSITORY=owner/repo selects its GitHub repository.' \
   'Arguments are passed to guided setup, for example: --bind 192.168.1.20'
  exit 0
 fi

 # stdin may be the curl stream or a process-substitution script. Obtain a
 # distinct controlling terminal before downloads or any privileged operation.
 if ! { exec {gridlens_tty}<>/dev/tty; } 2>/dev/null || [[ ! -t "$gridlens_tty" ]]; then
  fail 'No interactive terminal is available. Run this command in the host terminal, or use SSH with -t.'
 fi
 for tool in curl python3 mktemp uname; do
  command -v "$tool" >/dev/null || fail "Required tool is missing: $tool. Install it on this host and run setup again."
 done
 [[ $(uname -s) == Linux ]] || fail 'The Docker installer currently supports Linux (Ubuntu/Debian) with Docker already installed.'
 case $(uname -m) in
  x86_64|amd64) gridlens_arch=amd64 ;;
  aarch64|arm64) gridlens_arch=arm64 ;;
  *) fail 'This host architecture is unsupported. Supported builds are Linux amd64 and arm64.' ;;
 esac
 gridlens_repository=${GRIDLENS_REPOSITORY:-MachoDrone/gridlens-installer}
 [[ "$gridlens_repository" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,99}/[A-Za-z0-9][A-Za-z0-9._-]{0,99}$ ]] || fail 'Invalid GitHub repository; use owner/repository.'
 gridlens_version=${GRIDLENS_VERSION:-}
 gridlens_coordinator_flags=(--bootstrap-selected)
 if [[ -n "$gridlens_version" ]]; then
  gridlens_coordinator_flags+=(--bootstrap-explicit-version)
 fi
 gridlens_curl=(--fail --location --silent --show-error --proto '=https' --proto-redir '=https' --max-redirs 5 --connect-timeout 15 --max-time 180)
 if [[ -z "$gridlens_version" ]]; then
  printf '%s\n' 'Finding the published GridLens installer…' >&"$gridlens_tty"
  gridlens_latest=$(curl "${gridlens_curl[@]}" --head --output /dev/null --write-out '%{url_effective}' \
   "https://github.com/$gridlens_repository/releases/latest") || fail 'The GitHub installer release is unavailable. The repository must have publicly downloadable releases.'
  gridlens_prefix="https://github.com/$gridlens_repository/releases/tag/"
  [[ "$gridlens_latest" == "$gridlens_prefix"* ]] || fail 'GitHub did not resolve a release in the selected repository.'
  gridlens_version=${gridlens_latest#"$gridlens_prefix"}
 fi
 [[ "$gridlens_version" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] || fail 'Invalid release tag.'
 gridlens_asset="gridlens-linux-$gridlens_arch.tar.gz"
 gridlens_base="https://github.com/$gridlens_repository/releases/download/$gridlens_version"
 gridlens_scratch=$(mktemp -d "${TMPDIR:-/tmp}/gridlens-bootstrap.XXXXXXXX")
 cleanup() { rm -rf -- "$gridlens_scratch"; }
 trap cleanup EXIT
 trap 'exit 129' HUP
 trap 'exit 130' INT
 trap 'exit 143' TERM

 download() {
  # A bounded reader also enforces the limit when older curl versions receive a
  # response without Content-Length. Both pipeline exit statuses must succeed.
  if ! curl "${gridlens_curl[@]}" --max-filesize "$3" "$1" | python3 -c '
import os, sys
path, maximum = sys.argv[1], int(sys.argv[2])
total = 0
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
with os.fdopen(fd, "wb") as output:
    while True:
        data = sys.stdin.buffer.read(min(65536, maximum + 1 - total))
        if not data:
            break
        total += len(data)
        if total > maximum:
            raise SystemExit("GridLens download exceeded its size limit.")
        output.write(data)
    if total == 0:
        raise SystemExit("GridLens download was empty.")
' "$2" "$3"; then
   fail 'The release download failed or was incomplete. Check the published GitHub release and try again.'
  fi
 }

 printf 'Downloading GridLens %s for Linux %s…\n' "$gridlens_version" "$gridlens_arch" >&"$gridlens_tty"
 download "$gridlens_base/SHA256SUMS" "$gridlens_scratch/SHA256SUMS" 65536
 download "$gridlens_base/$gridlens_asset" "$gridlens_scratch/$gridlens_asset" 134217728

 python3 - "$gridlens_scratch" "$gridlens_asset" "$gridlens_version" "$gridlens_arch" <<'PY'
import gzip, hashlib, json, os, pathlib, re, shutil, sys, tarfile

root, asset, version, architecture = pathlib.Path(sys.argv[1]), *sys.argv[2:]
try:
    sums = {}
    for line in (root / 'SHA256SUMS').read_text(encoding='ascii').splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'([a-fA-F0-9]{64}) [ *](gridlens-linux-(?:amd64|arm64)\.tar\.gz)', line)
        if not match or match[2] in sums:
            raise ValueError('invalid checksum list')
        sums[match[2]] = match[1].lower()
    if asset not in sums:
        raise ValueError('selected archive has no checksum')
    digest = hashlib.sha256()
    with (root / asset).open('rb') as source:
        for chunk in iter(lambda: source.read(65536), b''):
            digest.update(chunk)
    if digest.hexdigest() != sums[asset]:
        raise ValueError('installer checksum did not match')

    # Bound the entire decompressed stream before tarfile parses PAX/long-name
    # headers. Those headers are consumed internally before yielding a member.
    plain = root / 'installer.tar'
    expanded = 0
    with gzip.open(root / asset, 'rb') as source, plain.open('xb') as output:
        while True:
            chunk = source.read(65536)
            if not chunk:
                break
            expanded += len(chunk)
            if expanded > 268435456:
                raise ValueError('expanded archive limit exceeded')
            output.write(chunk)

    class BoundedTarReader:
        def __init__(self, stream):
            self.stream = stream
        def read(self, size=-1):
            # Normal headers are 512 bytes and file copying uses 64 KiB. Refuse
            # a claimed giant PAX header before it requests a large allocation.
            if size < 0 or size > 1048576:
                raise ValueError('oversized archive metadata')
            return self.stream.read(size)
        def seek(self, *args):
            return self.stream.seek(*args)
        def tell(self):
            return self.stream.tell()

    seen, members, total = set(), [], 0
    with plain.open('rb') as raw, tarfile.open(fileobj=BoundedTarReader(raw), mode='r:') as archive:
        for member in archive:
            if len(members) >= 512 or member.size < 0 or member.size > 134217728:
                raise ValueError('archive member limit exceeded')
            total += member.size
            if total > 268435456:
                raise ValueError('expanded archive limit exceeded')
            name = member.name.rstrip('/')
            parts = name.split('/')
            if (not name or parts[0] != 'gridlens' or any(p in ('', '.', '..') for p in parts)
                    or '\\' in name or any(ord(c) < 32 or ord(c) == 127 for c in name)
                    or name in seen or not (member.isdir() or member.isreg())
                    or member.sparse is not None):
                raise ValueError('unsafe installer archive entry')
            seen.add(name)
            members.append((member, root.joinpath(*parts)))
        regular = {m.name.rstrip('/') for m, _ in members if m.isreg()}
        metadata_entry = next((m for m, _ in members if m.name == 'gridlens/RELEASE.json' and m.isreg()), None)
        if metadata_entry is None or metadata_entry.size > 16384:
            raise ValueError('release metadata is missing or too large')
        metadata = json.loads(archive.extractfile(metadata_entry).read(16385))
        if not isinstance(metadata, dict) or metadata.get('schema') != 2 or metadata.get('installation') != 'docker':
            raise ValueError('this is a legacy host-service release, not a schema-2 Docker installer; choose a Docker release such as v0.3.0 or newer')
        if metadata.get('version') != version or metadata.get('target') != 'linux/' + architecture:
            raise ValueError('release version or architecture did not match')
        required = {'gridlens/install.sh', 'gridlens/bin/gridlens', 'gridlens/RELEASE.json',
                    'gridlens/container/Dockerfile',
                    *('gridlens/scripts/' + name for name in ('docker_setup.py', 'dockerctl.py',
                      'container_runtime.py', 'container_probe.py', 'container_onboarding.py', 'legacy_import.py'))}
        if not required <= regular:
            raise ValueError('Docker installer package is incomplete')
        allowed = required | {'gridlens/scripts/container_enrichment.py', 'gridlens/scripts/rewards_reader.cjs',
                              'gridlens/scripts/container_updates.py', 'gridlens/scripts/container_update_control.py',
                              'gridlens/docs/AUTOMATIC_UPDATES.md', 'gridlens/docs/ENRICHMENT.md', 'gridlens/scripts/container_upgrade.py', 'gridlens/scripts/container_access.py',
                              'gridlens/docs/TROUBLESHOOTING.md', 'gridlens/docs/COORDINATOR.md', 'gridlens/scripts/container_telemetry.py', 'gridlens/scripts/docker_telemetry_setup.py',
                              'gridlens/start.sh', 'gridlens/README.md', 'gridlens/LICENSE', 'gridlens/THIRD_PARTY_NOTICES.txt', 'gridlens/container/README.md',
                              *('gridlens/docs/' + name for name in ('ACCESS.md', 'CLUSTER_PROTOCOL.md', 'HUB_MONITOR.md',
                                                                   'SECURITY.md', 'VALIDATION.md'))}
        allowed_directories = {'gridlens', 'gridlens/bin', 'gridlens/scripts', 'gridlens/container', 'gridlens/docs'}
        if regular - allowed or any(m.isdir() and m.name.rstrip('/') not in allowed_directories for m, _ in members):
            raise ValueError('Docker installer contains an unapproved file; legacy host-service helpers are not allowed')
        for member, target in members:
            if member.isdir():
                target.mkdir(mode=0o700, parents=True, exist_ok=True)
                continue
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, 'wb') as output, archive.extractfile(member) as source:
                shutil.copyfileobj(source, output, 65536)
            if target.stat().st_size != member.size:
                raise ValueError('truncated installer archive entry')
        for name in ('gridlens/install.sh', 'gridlens/bin/gridlens'):
            os.chmod(root / name, 0o700)
    with (root / 'gridlens/bin/gridlens').open('rb') as program:
        header = program.read(64)
    if (len(header) < 64 or header[:6] != b'\x7fELF\x02\x01'
            or int.from_bytes(header[18:20], 'little') != {'amd64': 62, 'arm64': 183}[architecture]):
        raise ValueError('installer binary does not match the selected Linux architecture')
except (OSError, ValueError, tarfile.TarError, EOFError, UnicodeError, OverflowError, RecursionError) as error:
    raise SystemExit('GridLens installer verification failed: ' + str(error))
PY

 # Terminal coordination has its own reviewed, immutable delivery. Its code
 # reads supported saved formats without changing the selected runtime release.
 # These pins are updated together only after the standalone support archive
 # has been published and verified; environment variables cannot override them.
 gridlens_coordinator_commit='d624fd9905fb2ef378c0d7ba0d3ca5e7690c4623'
 gridlens_coordinator_sha256='1d66d4968c91b822e0dab13141b58dcd57e0dafc89398a1b7e2b312eacfd9bb3'
 gridlens_coordinator_url="https://raw.githubusercontent.com/MachoDrone/gridlens-installer/$gridlens_coordinator_commit/support/gridlens-coordinator.zip"
 download "$gridlens_coordinator_url" "$gridlens_scratch/gridlens-coordinator.zip" 4194304
 gridlens_coordinator_version=$(python3 - "$gridlens_scratch" "$gridlens_coordinator_sha256" <<'PY'
import hashlib, json, os, pathlib, re, stat, sys, zipfile

root, expected = pathlib.Path(sys.argv[1]), sys.argv[2]
helpers = {'docker_setup.py', 'dockerctl.py', 'container_onboarding.py',
           'container_access.py', 'container_upgrade.py', 'docker_telemetry_setup.py',
           'container_updates.py', 'container_update_control.py'}
try:
    payload = (root / 'gridlens-coordinator.zip').read_bytes()
    if not re.fullmatch(r'[a-f0-9]{64}', expected) or hashlib.sha256(payload).hexdigest() != expected:
        raise ValueError('terminal coordinator checksum did not match')
    with zipfile.ZipFile(root / 'gridlens-coordinator.zip') as archive:
        entries = archive.infolist()
        if len(entries) != len(helpers) + 1 or {item.filename for item in entries} != helpers | {'COORDINATOR.json'}:
            raise ValueError('terminal coordinator contains missing, duplicate or unapproved files')
        total = 0
        for item in entries:
            total += item.file_size
            if (item.is_dir() or item.create_system != 3 or
                    not stat.S_ISREG(item.external_attr >> 16) or item.flag_bits & 1 or
                    item.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED) or
                    item.file_size < 0 or item.file_size > 1048576 or total > 4194304):
                raise ValueError('unsafe terminal coordinator archive entry')
        manifest = archive.getinfo('COORDINATOR.json')
        if manifest.file_size > 16384:
            raise ValueError('oversized terminal coordinator metadata')
        metadata = json.loads(archive.read(manifest))
        if (not isinstance(metadata, dict) or metadata.get('schema') != 1 or
                metadata.get('kind') != 'gridlens-terminal-coordinator' or
                not isinstance(metadata.get('version'), str) or
                not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,127}', metadata['version']) or
                not isinstance(metadata.get('files'), dict) or set(metadata['files']) != helpers or
                not isinstance(metadata.get('sourceCommit'), str) or
                not re.fullmatch(r'[a-f0-9]{40}', metadata['sourceCommit']) or
                metadata.get('sourceDirty') is not False):
            raise ValueError('invalid terminal coordinator metadata')
        contents = {}
        for name in sorted(helpers):
            data = archive.read(name)
            if hashlib.sha256(data).hexdigest() != metadata['files'][name]:
                raise ValueError('terminal coordinator file digest did not match')
            contents[name] = data
        destination = root / 'coordinator'
        destination.mkdir(mode=0o700)
        for name, data in contents.items():
            fd = os.open(destination / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, 'wb') as output:
                output.write(data)
        print(metadata['version'])
except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, RuntimeError, UnicodeError, OverflowError, RecursionError) as error:
    raise SystemExit('GridLens coordinator verification failed: ' + str(error))
PY
 )

 printf '%s\n' 'Docker release and terminal coordinator verified. Starting terminal setup.' >&"$gridlens_tty"
 # No exec here: the parent must retain its cleanup trap until setup finishes.
 # Passwords/interactive reads have a terminal; stdin is never the curl script.
 # Keep the download directory private; let the Docker coordinator apply the
 # file modes required by its temporary build context and owned volumes.
 (umask 022; python3 -B "$gridlens_scratch/coordinator/docker_setup.py" \
  --package-dir "$gridlens_scratch/gridlens" "${gridlens_coordinator_flags[@]}" \
  --coordinator-version "$gridlens_coordinator_version" "$@" <&"$gridlens_tty")
)

# The final compound command must parse completely before the function runs.
# An incomplete function/call/block from a broken bootstrap transfer does no work.
if true; then
 gridlens_bootstrap "$@"
fi
