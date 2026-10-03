# Automatic fleet updates

The update-capable source adds a persistent **Updates → Automatic updates
(entire fleet)** switch to both Monitor and Fleet. It controls one explicitly
approved set of PCs. An operator may change the policy; viewers can inspect
versions, progress and failures. The policy is stored on the PCs, never in browser
storage. Closing the browser does not stop the update service.

The six-PC lab is enrolled and **enabled**. At **2026-10-03 19:47:01 UTC**, all
six PCs automatically completed **[v0.3.8-dev4](https://github.com/MachoDrone/gridlens-installer/releases/tag/v0.3.8-dev4)** from clean source
`3b4e79fc95c98e669ddb35157111bc23f309ef67`. Each updater also replaced itself and confirmed its new
instance. The GUI setting survived reload, and all hubs retained six PCs/eight
current signed hosts, identities, accounts, profiles and ports. Public rollout and test results are recorded in
[the development release](https://github.com/MachoDrone/gridlens-installer/releases/tag/v0.3.8-dev4).

Public stable latest remains **v0.3.6**. The signed development channel is separate;
physical phone/router and full-machine reboot acceptance remain pending.

## Approve the fleet once

Use an update-capable Docker development image and its compatible verified
terminal coordinator. To opt into the current development build on an existing
Docker installation, run the public command with an explicit version:

```sh
curl -fsSL https://raw.githubusercontent.com/MachoDrone/gridlens-installer/main/start.sh | GRIDLENS_VERSION=v0.3.8-dev4 bash -s -- --upgrade
```

For a new PC, omit `--upgrade` to enter guided setup. An older runtime does not acquire a worker merely because the GUI
shows an Updates button. Docker, Bash, curl and Python must already be installed;
all new runtime dependencies belong in the image.

Export a public registration on each participating PC, using that PC's name for
the output file. For nn06:

```sh
./install.sh --updates-public > nn06-update-public.json
```

The record contains `id`, `name`, `dashboard_url`, `control_url` and the public
hub `certificate`. It contains no private key or login credential. Collect these
records into one JSON document with exactly `pcs` and `coordinator_id`. For the
six-PC lab, after collecting the six public files in one directory:

```sh
python3 - <<'PY'
import json
from pathlib import Path

pcs = [json.loads(Path(f"nn{i:02d}-update-public.json").read_text())
       for i in range(1, 7)]
coordinator = next(pc["id"] for pc in pcs if pc["name"] == "nn06")
Path("updates-roster.json").write_text(json.dumps(
    {"pcs": pcs, "coordinator_id": coordinator}, indent=2) + "\n")
PY
```

`pcs` must contain the actual exported objects, including this PC's exact
registration, rather than names or certificate paths. The installer validates
one to 1,024 distinct PC identities, certificate pins and private control
endpoints. The six-PC lab uses nn06's exported ID as its coordinator. PC names
are labels; do not substitute the literal name `nn06` for a different exported ID.

Approve the identical document on every participating PC:

```sh
./install.sh --updates-join updates-roster.json
```

The installer previews the PC addresses, certificate fingerprints and coordinator
before saving approval and provisioning this PC's worker. It uses normal terminal
sudo when needed. A new or changed roster starts disabled. Reusing an unchanged
roster preserves its policy. Update approval is independent of both VPN
administration and telemetry membership: neither of those rosters grants update
rights. An approved PC's operator may change the whole fleet's update policy.

The verified public bootstrap forwards these options too, using the published compatible
coordinator:

```sh
curl -fsSL https://raw.githubusercontent.com/MachoDrone/gridlens-installer/main/start.sh | bash -s -- --updates-join updates-roster.json
```

Open **Updates** on an enrolled dashboard and turn on **Automatic updates
(entire fleet)**. The switch reads back the saved policy. A saved On state means
updates are authorized; it does not mean every PC acknowledged that policy or
finished an update. **Requested: On/Off · awaiting acknowledgment** means the
desired setting is present but the independent worker has not confirmed durable
recovery state. Do not treat that as a confirmed save; refresh and inspect the
reported error. Check every row, including blocked and unreachable PCs.

## Check and rollout behavior

Only the approved coordinator checks the public development channel. The default
schedule is a 120-second base interval plus jitter; the GUI displays the actual
next check. GitHub response headers, throttling and failures can delay it. Other
PCs prepare the coordinator's exact release rather than each polling GitHub for
their own selection. If nn06 is unavailable in the lab, new checks and rollout
coordination wait; ordinary monitoring and other dashboards remain independent.
There is no automatic coordinator election.

GitHub's unauthenticated REST quota is shared by the originating public IP. One
check every two minutes is approximately 30 requests per hour before jitter and
other traffic. This is a base schedule, not a guarantee against throttling. The
worker uses conditional requests, remaining/reset headers, a quota reserve and
failure backoff. An unauthenticated `304` response must not be assumed to be free:
GitHub documents that exemption for correctly authenticated requests. See
[GitHub rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)
and [conditional-request guidance](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api).

Each channel document is an Ed25519-signed manifest verified against the public
key embedded in the installed GridLens program. It binds the development channel,
updater protocol, increasing sequence, exact version, clean source commit and both
architecture-specific archive hashes and sizes. Download locations are fixed to
the public installer repository. Signatures, hashes, architecture, provenance and
bounded archive contents are checked before image preparation. An older release
cannot silently downgrade the installed version.

Every approved PC prepares the same release before any PC starts replacing its
containers. PCs then update one at a time, with the coordinator last. Each local
replacement pairs the image with a consistent state backup and verifies continuing
collection, stable source identity and host coverage before acknowledgment.
Unreachable PCs block progress; they are never silently removed from the cohort.
An update failure initiates recovery of the PCs that attempted that transaction,
using their matching backups. An unresolved rollback remains visible and blocks
another automatic rollout.

Turning the switch off prevents new checks and new rollout selection. Preparation
can be cleaned up before any installation starts. An already applying transaction
must complete or recover safely; disabling the policy is not a forced container
kill. Restart/retry uses the retained transaction, rather than silently selecting
a different release or unrelated backup.

Rollback restores earlier application state as well as its matching image.
Accounts, approvals and revocations made after the backup can be reverted and may
need to be reapplied on every affected PC. Update-policy recovery is handled
separately so an acknowledged later disable is not treated as permission for a
new rollout. Retain legacy services and existing working profiles; automatic
updates do not authorize their retirement.

## Docker ownership and diagnostics

The default installation adds `gridlens-updater` and the persistent
`gridlens-updates` named volume. A short-lived `gridlens-updater-refresh` helper
can replace the worker after a committed release. Custom installation prefixes
replace `gridlens` in these names. Only labeled GridLens resources may be managed.

The updater has Docker socket authority. A read-only socket mount does **not**
make the Docker API read-only; a compromised updater could administer the host
through its daemon. The worker is therefore separate from the web hub, accepts
fixed signed-release operations, publishes no port and mounts no host OS directory
or core identity volume. Its containers use private/isolated Docker networking,
read-only roots, dropped capabilities and named state volumes. The Go hub has no
Docker socket, shell endpoint or arbitrary command/path/download-URL API.
Docker's own networking and volume operations still affect the host.

Docker builds use an empty private client configuration directory on the owned
update volume, outside the image build context. It is removed after the build;
no host Docker credential directory is mounted. Original per-PC failures remain
visible after cleanup, including a separate recovery error where applicable.

The worker bounds its public release cache and checks staging space before
downloading another archive. Matching Docker images and state backups are retained
for recovery; they are not automatically pruned. Operators must monitor Docker
storage as development releases accumulate. Cache limits do not bound total
Docker image, application-state or rollback storage.

Start with the GUI's saved policy, coordinator, next-check time and per-PC errors.
The top-level Last check is the coordinator's release lookup; each PC's Last
report describes its worker status. The following diagnostics are read-only for
the default prefix; prepend ordinary terminal `sudo` if your account needs it:

```sh
docker inspect --format '{{.Name}} {{.State.Status}} {{.Config.Image}}' gridlens-core gridlens-updater
docker logs --tail 80 gridlens-updater
docker volume inspect --format '{{.Name}} {{index .Labels "io.gridlens.owner"}}' gridlens-state gridlens-updates
docker system df
```

| Status | Action |
| --- | --- |
| Update service unavailable | Confirm the installed image supports updates, then use the installer to approve the exact roster and provision the worker. |
| Worker unavailable | Inspect that PC's owned updater container and log. Reusing its approved `--updates-join` document can provision/resume the existing worker without replacing its policy. |
| Coordinator unreachable | Restore the coordinator's existing private connectivity and owned services. Do not approve a competing coordinator to bypass a pending transaction. |
| PC unreachable or policy acknowledgment pending | Restore that PC's existing private control endpoint and matching roster; the remaining PCs wait. Router WireGuard forwarding is a separate access question. |
| Signature, digest, architecture or protocol rejection | Keep the installed version. Publish a correctly built, signed, compatible release through the maintainer process. |
| GitHub pause or delayed next check | Wait until the reported next check. Repeated restarts do not reset the worker's persistent request deadline. |
| Rollback needs attention | Turn off future automatic updates, retain all owned state/journals/backups and inspect the affected PC. Recover its exact recorded transaction; never substitute an unrelated old backup. |
| Docker storage is low | Stop selecting new automatic updates and review the retained artifacts/backups before removing anything. Do not run a broad Docker prune or delete Nosana resources. |

Do not edit the JSON journals, remove a state volume, replace an identity, or
delete the initial image referenced by its launch record to clear an error.
Explicit installer `--rollback` restores a matched backup and has the account and
revocation effects above. Do not race manual maintenance against an applying
automatic transaction; finish or recover that transaction first.

## Publishing and acceptance

The operator has requested tested development updates to be published and used
going forward. This standing instruction covers reviewed development artifacts
and their signed channel entry; it does not authorize publishing private source,
credentials, signing keys, local evidence, or promoting an unaccepted stable
release. Publish only from clean, identifiable source with the relevant tests and
acceptance complete. Keep the signed development channel separate from the
public stable installer selection.

Before any runtime advances state or launch formats, publish and verify compatible
public terminal-coordinator support first. Exercise normal setup and `--upgrade`
through the actual public command against the new candidate and retained older
bundle. A raw old-installer rejection is not proof that the normal entry point
works.

Required verification includes signed-manifest and archive rejection, disabled
policy, interrupted/lost acknowledgments, all-PC preparation, sequential order,
matching transaction recovery, post-backup policy changes and continuing signed
observations. Run Go race/vet, Python, browser and package checks; then use isolated
Docker resources for real image/state update and rollback. Browser fixtures and
synthetic 1,024-PC records are separate from physical six-PC/eight-host acceptance.
Record the observed image IDs, preserved accounts/profiles/ports, rollback
references, GUI enablement and actual channel checks before claiming the lab is
automatically updating. Phone/router/reboot gates remain separately documented.

The private-source developer tool `scripts/publish_development.py` validates both
native archives, clean source provenance, bounded public file layout and publisher
signature. `--publish` creates immutable prerelease assets, checks authenticated
and unauthenticated readback, then atomically advances `channels/development.json`.
Choose a new prerelease version and increasing sequence, provide reviewed public
notes and the existing private signing key, and run the acceptance gates first.
It never uploads private source or the signing key. Document-only acceptance
records can follow the code release without misidentifying its source commit.
