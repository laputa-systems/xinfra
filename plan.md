# xinfra campaign

## Status

- **Goal:** a small, inspectable configuration-management tool for Alpine/Laputa-style hosts, written in XSH, with typed resources, `doctor`/`plan`/`apply`/`check`, safe file staging, per-host failure data, and a native SSH transport.
- **Accepted:** G0 at `4f78312`; C1 at `459312f`; C2 at `2b2a52e`; C3 at `da8e175`; C4 at `a5d5a68`; W1–W6 in `../xsh` through `c4c4da20d`. W6 records the macOS lane, the unexecuted Linux/Docker lanes, and the passing size gate in `../xsh/docs/ssh.md`. R1 passes `dev/integration.xsh --case transport` on both fixtures.
- **Next:** R3b (remote files, staging, validation, and large transfers); R3a passes `dev/integration.xsh --case dirs,symlinks`.
- **Worktree rule:** `../xsh` is clean at `a7772ce05`; W and R both work there directly when needed. The `xinfra-ssh` worktree was not needed. Never include another writer's uncommitted changes.
- **Hard gate:** every R item waits for W6. If W2 cannot pass within three attempts, park W and the R items; do not substitute an external SSH client.
- **Resume prompt:** `Run G0 in /Users/josh/d/xinfra from plan.md. Then start W1 in the xinfra-ssh worktree at ef924bf63 if ../xsh is dirty, or in ../xsh if it is clean; run C1-C4 in parallel only if staffed.`
- **First command:** `make check`.

## Charter

- Decide and keep going. Record a decision only when a later slice depends on it. Do not ask for approval for methods this document already settles.
- Verify every XSH syntax or API assumption with `xsht api`, the current SPEC, and a checked probe before coding. Do not treat an illustrative API as implemented.
- A narrow generic XSH substrate defect that blocks the application is reproduced with a minimal test, repaired in `../xsh`, and re-pinned. Never move configuration policy into Rust to evade an XSH limitation. Every language or runtime defect found gets a minimal reproducer and regression test in `../xsh`.
- The owner's grant is this repository, the W items in `../xsh`, and `.work` in both. Anything else is outside the grant and parks the item.
- Hard stops are few and each one parks its item: an irreversible or outside-repository action, a boundary this document forbids, a missing prerequisite that cannot be repaired locally, or a loop that cannot check anything.
- Fix egregious problems met on the way, in their own commit, to these thresholds: a unit loop over 30 seconds, an acceptance command over 15 minutes excluding fixture boot, a fact query that opens a new SSH handshake, unbounded memory in file transfer, a panic, or a test that touches the network in the unit suite. Record anything else in `TODO.md` with a P1–P4 priority and leave it.
- Parity before optimization. W and C make the tool work; R makes it work remotely; Q proves it against the reference; O measures and polishes only after Q2.
- One writer by default. W and C are the only parallel pair: W owns `../xsh`, C owns this repository, and their files are disjoint. Never run two lanes in the same repository. A second xinfra lane, if ever added, uses `.work/wt/<lane>` under this repository, never `/tmp`.
- W works in `../xsh` when its tree is clean at the pin; otherwise it works in a detached worktree at the pin under `../xsh/.work/wt/xinfra-ssh` on a local `xinfra-ssh` branch. The branch exists only because main is dirty: it is not a PR, and the owner merges it directly. The campaign never rewrites or settles the other writer's main-tree changes.
- Every commit is a Conventional Commit with the workstream as its scope (`ssh`, `inventory`, `model`, `remote`, `files`, `packages`, `users`, `services`, `scheduling`, `secrets`, `plans`, `docs`, `perf`, `fixtures`). Put the item ID in the body. Code comments never cite this document.
- One item ends on its acceptance command plus the narrowest affected suite on the integrated tree. Run the full suite at W6, R8, Q2, and Z1. After each accepted slice, run the parent steering checkpoint from `orchestrate`; rewrite **Status** only when the ruling changes.
- Time-box a failing item at three attempts, then park it with the cause, the branch or worktree, and the exact retry condition. A shared fixture blocker gets one owner.
- Do not run formatters, edit CI, tag releases, or push. Pushing is always forbidden.
- Use the pinned release binaries from `../xsh` for every xinfra run. Never use `cargo run` for the product loop. Rebuild and re-pin after an accepted W change.
- Fixtures are disposable Lima guests named `xinfra-*` and nothing else. Never use production inventory, real hosts, the operator's SSH configuration, or an ungated Docker daemon.

## Decisions

### Owner

- **D1 — Native SSH first (owner, 2026-10-30).** Build the minimal XSH-55 client in `../xsh` before any xinfra remote execution. Required subset: connect, pinned host key, Ed25519 key-file authentication, raw exec with bounded capture, streaming binary stdin/stdout/stderr, connection reuse, remote exit status/signal distinct from transport failure, execution certainty, deadlines/cancellation, cleanup, and rekey. ssh-agent, `known_hosts`, passwords, keyboard-interactive, PTY, forwarding, SFTP, certificate host keys, and non-Ed25519 algorithms are deferred with explicit unsupported errors; the full XSH-55 contract remains open upstream. No external `ssh`/`scp`/`sftp` in the product. Reverse only by an explicit owner change to the transport contract.
- **D2 — Pinned release binaries (owner, 2026-10-30).** Run release binaries from the active XSH checkout (`../xsh`, or the W worktree) at `target/<triple>/release/`; set `XSH_ROOT` to that checkout. Do not build xinfra against a debug runner. After a W change, rebuild both `xsh` and `xsht`, update the pin, and use the new pair everywhere. The owner merges the W branch into xsh main at W6 or records the unmerged branch as a limitation.

### Prescribed

- **D3 — Fixtures are local Lima Alpine guests.** Use `LIMA_HOME=$PWD/.work/fixtures/lima`, Alpine 3.23.4, a pinned image digest, no host home mount, and users/keys created by the fixture script. Docker/OrbStack is broken here and `ubuntu@oracle` was unreachable at preflight; neither is a dependency. Reverse if the owner supplies a working Linux host and wants a second controller lane; that lane then goes on **Needs environment**, not the critical path.
- **D4 — pyinfra 3.10.0 is an oracle only.** Install it in `.work/oracle/venv` with `uv` and Python 3.13, run it with an isolated `HOME`, never ship it, never install it on a product fixture. Preserve its MIT license and record the version. Reverse only for a newer 3.x with the same overlapping operations, which requires re-pinning and re-running Q1.
- **D5 — One transport boundary.** All remote I/O goes through one xinfra adapter over XSH's `ssh` module. Every remote command is `/bin/sh -c <script>`; the script begins with `LC_ALL=C` and `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`, and each argv item is rendered with `shlex.quote`/`shlex.join`. The adapter is the only place request values become shell source. Reject NUL, non-UTF-8 managed paths, and malformed host keys before connecting. A POSIX login shell is probed; a shell that cannot run the probe is a host error, not a fallback. Host trust is a mandatory `SHA256:` fingerprint; there is no TOFU, `known_hosts` read/write, password, agent, PTY, forwarding, or SFTP path in v1.
- **D6 — Resource contract.** Resources are an ordered `List[Resource]` with stable explicit IDs and optional `requires` IDs. The closed set is:
  - `Directory`: `path`, `state` (`present`/`absent`), `owner?`, `group?`, `mode=0o755`, `notify=[]`; one level, never recursive deletion.
  - `File`: `path`, exactly one of `source`/`content`/`secret`/`template` for `present`, `owner?`, `group?`, `mode` (default `0o644`), `validate?`, `state`, `notify=[]`. `absent` forbids a source variant. `template` is `{path: Path, vars: Map[Str, Str]}` rendered locally with `template.render`; rendered content is bounded at 16 MiB, and `vars` never carry secrets. `validate` is `{argv: List[Str]}`; the staged path is appended as one argument, and a validator that cannot read a staged path is unsupported.
  - `Symlink`: `path`, `target`, `state`, `replace=false`, `notify=[]`; never treated as a file or directory.
  - `Package`: `name`, `state` (`present`/`absent`), `constraint?`, `refresh_index=false`, `notify=[]`; apk semantics only.
  - `User`: `name`, `state`, `uid?`, `gid?`, `groups=[]`, `home?`, `shell?`, `system=false`, `create_home=false`, `update=false`, `notify=[]`; `update` never changes a UID or GID.
  - `Group`: `name`, `state`, `gid?`, `system=false`, `notify=[]`.
  - `Command`: exactly one of `argv`/`shell`, `creates?`, `unless?`, `env={}`, `stdin_secret?`, `always_run=false`, `timeout?`, `notify=[]`; no guard and no `always_run` is a validation error. `stdin_secret` is the only way a command receives a secret.
  - `Service`: `name`, `state` (`started`/`stopped`), `enabled?`, `on_change` (`reload`/`restart`, default `restart`).
  `source` and `template.path` resolve relative to the deployment program's directory and must stay under the repository root; an absolute path is rejected.
  Null `owner`/`group` preserves an existing object's ownership; a new object uses the applying identity. A path whose current or intended owner is root requires `privilege=root`.
  Common fields: `id`, `requires=[]`, `hosts` (names or groups; empty means all), `privilege` (`user` or `root`; package, user, group, and service default to `root`). `notify` names service resource IDs and is coalesced per host after all resources succeed. A resource whose prerequisite failed, was blocked, or has an unknown outcome is `blocked`; one skipped because it was already satisfied counts as satisfied. Package and service adapters stay in XSH; an unsupported platform or capability is an explicit error, never a guessed implementation.
- **D7 — File safety.** Stage in the destination's existing parent with a private unpredictable `mktemp` object; stream bytes as SSH channel data, never as argv, base64 text, or command substitution; digest the local source before and after transfer; set ownership and mode; validate the staged path with the declared argv plus the staged path; promote with `mv -T` when the capability probe proves it (otherwise a type-checked same-directory `mv`); verify digest/type/mode/owner; and remove the staging object. Never replace the live file before validation; if a validator cannot read the staged path, reject the resource as unsupported. Reject a group- or world-writable parent (except a sticky directory owned by the target user). State the trusted-parent/local-attacker model in `docs/trust.md`. Atomic visibility is not crash durability or whole-deployment rollback.
- **D8 — Failures and exit codes.** Default `--on-error=isolate`: a failed host stops its later mutations, independent hosts finish, and the run exits 1. `abort` stops scheduling new work after the first failure but does not cancel in-flight hosts; `continue` allows independent work and still blocks dependents. Never retry a mutation after submission; use the transport's certainty. Outcomes are `unchanged`, `changed`, `skipped`, `blocked`, `failed`, `unknown`, `partial`. Exit codes: `check` 0 compliant / 1 drift / 2 unknown or error; `plan` 0 computed / 2 validation or transport error; `apply` 0 success / 1 any failed, blocked, unknown, or partial / 2 usage, validation, or stale plan / 130 interrupted; `doctor` 0 healthy / 1 unhealthy / 2 usage.
- **D9 — Remote lock.** Apply takes one lock per host before gathering mutable facts: `/run/xinfra.lock` when privileged, otherwise `$HOME/.cache/xinfra/lock`. `mkdir` is the atomic claim; the owner file holds token, pid, boot id, start time, and host. A changed boot id is the only automatic stale proof; age or a reused pid never justifies stealing. Otherwise fail with the owner details and require explicit `xinfra unlock --host NAME --force`. Plan and check never lock. Release in `defer`; a controller crash may require the operator command.
- **D10 — Saved plans are in scope.** `plan --save PATH` writes a versioned JSON artifact with deployment and source digests, inventory digest, the observed facts each action depends on, and the XSH/xinfra pin; no secrets. `apply --plan PATH` recomputes facts, requires the same digests and preconditions, and refuses a mismatch with exit 2 before mutation. A plan containing `conditional` or `unknown` actions cannot be saved. Replan by running `plan --save` again; never silently widen an approval.
- **D11 — Secrets are references at rest.** `SecretRef` is `env(NAME)` or `file(PATH)`; deployments and inventory store references, never values. Resolve only at apply for file content or command stdin; do not pass secrets as argv or environment. Staging files are `0600`. Redact exact secret bytes from human output, diffs, JSON/JSONL, errors, and traces; tests use canaries. No secrets in examples, fixtures, saved plans, or packages.
- **D12 — Packaging.** Ship a source tarball plus `install.sh`: `bin/`, `lib/`, `xsht-config.ini`, `docs/`, `examples/`, and a wrapper that runs `${XSH:-xsh} <libexec>/bin/xinfra.xsh "$@"`. No compiled xinfra binary, Python, pyinfra, toolchain, test server, key, or build cache. `make install PREFIX=...` installs under `$PREFIX/libexec/xinfra`; `xinfra --version` and `doctor` probe the required `ssh` module rather than assuming a version string.
- **D13 — Performance is measured, not promised.** O1 runs only after Q2. Measure startup, peak RSS, connection count, and representative first/no-op deployments against pinned pyinfra on equivalent fresh guests; separate handshake/network from controller time. Do not promise that native code is faster. Time-based gates follow `perf-gate-ready` (`-s` before adding width, `-1` immediately after the measurement); if the host is busy, record "perf gate deferred: host busy" and do not claim a pass. W6 also records the xsh build time, startup change, and the 5% binary-size gate result against the recorded baseline.

### Delegated

- **D14 — Exact XSH API spellings, record field names, and error payloads** in W5. Bound by D5 and the W2–W4 behavior; the xinfra adapter adapts, and W6 records the final surface in `../xsh/docs/`. A spelling that cannot satisfy D5 parks W5; do not add a second transport.
- **D15 — Fact command text and parser details** in R2. Bound by the Alpine 3.23/BusyBox baseline, `LC_ALL=C`, machine-readable line protocols, and the absent/denied/malformed distinction. Any parser that needs human-formatted `ls` is wrong.
- **D16 — JSON/JSONL field names beyond the required schema** in C4. Bound by schema version 1, the outcome vocabulary, and no-secret output.
- **D17 — Fixture VM sizing, provisioning details, and pyinfra inventory wiring** in G0/Q1. Bound by `LIMA_HOME` under `.work`, `xinfra-*` names, no host home mount, and no operator SSH writes.

## Baseline

- **xinfra:** campaign document committed on `master`; no product commits; no remote.
- **XSH pin:** `ef924bf63f9ee138d99ac299a37e234555622e23` (2026-10-30), release `xsh` `e4b7e094…c3412fa6`, release `xsht` `ad1b779d…a2d235d`. The main working tree is dirty with another writer's uncommitted source, docs, and stdlib-test changes; the set changed during preflight. They are not part of this campaign. W uses a clean detached worktree at the pin; the owner merges the W branch.
- **Native SSH:** absent. `../xsh` has 41 standard modules and no `ssh`; `../xsh/src/modules/mod.rs` lists no `ssh`; XSH-55 is still `planned`; `crates/xsh-ssh` does not exist; ssh-build ships an OpenSSH client, not a reusable Rust client.
- **Loop:** release `xsht check` on a two-file probe took 0.04s; `xsht test` on two tests took 0.03s. `xsh` and `xsht` are at `target/aarch64-apple-darwin/release/`. A fresh Alpine fixture boot took about 65s including the image download and about 17s from the cached image under `LIMA_HOME`; reuse guests for acceptance runs.
- **Verified on a disposable Alpine 3.23.4 Lima guest:** OpenRC start/stop/status (`stopped` exits 3), `apk version -t`, `stat -c`, `mv -T`, passwordless `sudo`, OpenSSH, and a real pyinfra 3.10.0 file operation. The probe guest was deleted; fixture state must live under `.work/fixtures/lima`.
- **Verified XSH behavior:** typed `module.load(...).require(ModuleContract)` for deployment programs, TOML `[[hosts]]` records, `par-map` returning per-host `Result` data with `try`, and `shlex.quote` on empty values, quotes, newlines, leading hyphens, and substitution text. NUL is not shell-representable and is rejected by the transport.
- **pyinfra:** 3.10.0 works from `.work/tmp/venv` against the Lima guest with `HOME` isolated; it writes `known_hosts` under that HOME. Q1 must always isolate `HOME`; never touch `~/.ssh`.
- **Known red:** OrbStack Docker fails with `rw layer snapshot not found` and container runs hang; do not use it. `Tailscale ping` for `oracle` timed out and plain SSH timed out; the Linux controller lane is unverified.
- **Gap:** no native SSH means no W6, no R item, and no remote completion. C items are local-only until W6.

## Sequence

Sizes are relative implementation effort, not acceptance time. Every command runs from `/Users/josh/d/xinfra` unless it names another directory.

### Phase 0 — Ground

- **G0 — Scaffold, pins, and disposable fixtures** (M). Prereq: none. Owns `Makefile`, `xsht-config.ini`, `.git/info/exclude` (`.work/`), `dev/pins.env`, `dev/fixtures.xsh`, `dev/fixtures/alpine.yaml`, `.work/fixtures/`. Creates no product test yet.
  Acceptance: `make check`; then `make fixtures` starts `xinfra-a` and `xinfra-b` under `LIMA_HOME=$PWD/.work/fixtures/lima`, and `dev/fixtures.xsh verify` checks Alpine 3.23.4, OpenRC, apk, OpenSSH, passwordless `sudo` on `xinfra-a`, passwordless `doas` on `xinfra-b`, `stat -c`, and `mv -T` through the fixture's own SSH invocation. `dev/fixtures.xsh down` removes only `xinfra-*`.

### Phase 1 — Native SSH substrate in ../xsh

- **W1 — Vendor and pin the SSH substrate** (M). Prereq: G0. Owns `../xsh/crates/xsh-ssh/**`, `../xsh/Cargo.toml`, `../xsh/Cargo.lock`, `../xsh/scripts/check-ssh-crypto.sh` in the active W checkout.
  If `git -C ../xsh status --porcelain` is empty and HEAD is at or after `ef924bf63`, work in `../xsh` and set `XSH_ROOT=$PWD/../xsh`. Otherwise run `mkdir -p ../xsh/.work/wt`, `git -C ../xsh worktree add --detach .work/wt/xinfra-ssh ef924bf63`, and `git -C ../xsh/.work/wt/xinfra-ssh switch -c xinfra-ssh`; set `XSH_ROOT=$PWD/../xsh/.work/wt/xinfra-ssh`. Never include the main tree's dirty files.
  Vendor `oxish-proto` and `oxish-graviola` from ssh-build `bc2a9fb418ac48c9e00b5138fa800e4a7c724315`, with licenses, origin manifest, and no sibling checkout. Graviola is the only cryptographic provider; no OpenSSL, ring, or aws-lc.
  Acceptance: `cd "$XSH_ROOT" && cargo build --release --target aarch64-apple-darwin -p xsh-ssh`; `scripts/check-ssh-crypto.sh`.

- **W2 — Connect and pinned host key** (L). Prereq: W1. Owns `../xsh/crates/xsh-ssh/src/{client,kex,host_key,wire}.rs` and its tests.
  Acceptance: `dev/fixtures.xsh exec --cwd "$XSH_ROOT" -- cargo test --release --target aarch64-apple-darwin -p xsh-ssh --test connect`. Cases: correct pin succeeds; wrong, missing, malformed, and changed pins fail closed before authentication; no pin means no connection. Load the `security` and `review` skills before merging.

- **W3 — Authentication, exec, and outcomes** (L). Prereq: W2. Owns `../xsh/crates/xsh-ssh/src/{auth,channel,exec,error}.rs` and its tests.
  Acceptance: `dev/fixtures.xsh exec --cwd "$XSH_ROOT" -- cargo test --release --target aarch64-apple-darwin -p xsh-ssh --test exec`. Cases: Ed25519 key-file auth; wrong key and unknown user; encrypted key rejected explicitly; exact stdout and stderr; remote nonzero status and signal as outcomes; transport failure before vs after submission carries certainty; missing completion is never status zero; timeout before and after submission.

- **W4 — Streaming, large binary, rekey, cancellation** (L). Prereq: W3. Owns `../xsh/crates/xsh-ssh/src/{stream,rekey,limits,cancel}.rs` and its tests.
  Acceptance: `dev/fixtures.xsh exec --cwd "$XSH_ROOT" -- cargo test --release --target aarch64-apple-darwin -p xsh-ssh --test stream`. Cases: 128 MiB stdin and stdout digest equality; simultaneous input/output beyond the SSH window; saturated stderr without deadlock; server rekey at `RekeyLimit 1M`; deadline and disconnect cleanup; no leaked descriptors or threads; bounded memory.
- **W5 — Typed XSH `ssh` adapter** (M). Prereq: W4. Owns `../xsh/src/modules/ssh.rs`, `../xsh/src/modules/mod.rs`, `../xsh/crates/xsh-registry/src/signature/modules.rs`, `../xsh/crates/xsh-registry/src/runtime_op.rs`, `../xsh/src/runtime/eval/lowered_run/module_ssh.rs`, `../xsh/tests/xsh/ssh-*.xsh`, `../xsh/examples/ssh/`, `../xsh/docs/`.
  Acceptance: rebuild the release pair, then `cd "$XSH_ROOT" && target/aarch64-apple-darwin/release/xsht api module:ssh` lists the surface; `dev/fixtures.xsh exec --cwd "$XSH_ROOT" -- target/aarch64-apple-darwin/release/xsht test tests/xsh/ssh-` passes; examples run against the fixture; session scope cleanup, deterministic rejection of concurrent use of one handle, and no key or payload material in Debug/errors.

- **W6 — Qualify and pin** (M, gate). Prereq: W5. Owns `../xsh/docs/`, `dev/pins.env`.
  Acceptance: full W suite on macOS arm64; the Linux lane if **Needs environment** allows; `"$XSH_ROOT"/scripts/check-ssh-crypto.sh`; `cargo dev gate crates/xsh-ssh` if Docker is available, otherwise record the unexecuted gate; record build time, startup, and the 5% binary-size result from D13; rebuild `xsh` and `xsht` at the accepted commit, write the worktree/branch commit and both SHA-256 digests to `dev/pins.env`, and run `make check` here. The owner merges `xinfra-ssh` into xsh main; if the merge is not available, keep `XSH_ROOT` on the worktree and record the unmerged branch as a limitation. R1 does not start until this passes.

### Phase 2 — xinfra core (local)

- **C1 — Inventory and local configuration** (M). Prereq: G0. Owns `lib/xinfra/inventory.xsh`, `lib/xinfra/error.xsh`, `tests/test-inventory.xsh`, `examples/alpine-web/inventory.toml`.
  Acceptance: `xsht test tests/test-inventory.xsh`. Rejects duplicate names, unknown fields, bad ports, missing keys, missing or malformed host-key pins, group references that do not resolve, relative key paths that escape the inventory root, non-UTF-8 paths, and keys readable by group or world. Resolves inventory-relative key paths.

- **C2 — Typed resources, deployment loader, validation, pure planner** (L). Prereq: C1. Owns `lib/xinfra/model.xsh`, `lib/xinfra/deploy.xsh`, `lib/xinfra/validate.xsh`, `lib/xinfra/plan.xsh`, `lib/xinfra/order.xsh`, `tests/test-model.xsh`, `tests/test-validate.xsh`, `tests/test-plan.xsh`, `examples/alpine-web/deploy.xsh`.
  The Alpine example is nginx: package `nginx`, group/user `webapp`, `/etc/motd`, `/etc/nginx/nginx.conf` rendered from a template, OpenRC service `nginx`, and validation `nginx -t -c <staged>`.
  Acceptance: `xsht test tests/test-model.xsh tests/test-validate.xsh tests/test-plan.xsh`. Separates observed facts, desired state, pure comparison, intended actions, observed results, and post-apply verification. Deployment modules are declaration-only and mutation-free; they construct resources, never touch a host or perform local writes. Rejects duplicate IDs, unknown/cyclic dependencies, unsupported variants, conflicting options, missing local source or template artifacts, template syntax/render errors, non-UTF-8 paths, and invalid host selectors before any host call. Loads a deployment only through the documented `module.load` contract. Pure comparison returns ordered `Action` values and never calls a transport.

- **C3 — HostOps boundary and local directory/file/symlink logic** (L). Prereq: C2. Owns `lib/xinfra/host.xsh`, `lib/xinfra/resources/{dir,file,symlink}.xsh`, `tests/support/fake_host.xsh`, `tests/test-dir.xsh`, `tests/test-file.xsh`, `tests/test-symlink.xsh`.
  Acceptance: `xsht test tests/test-dir.xsh tests/test-file.xsh tests/test-symlink.xsh`. With the fake HostOps: first apply reaches the intended state; second reports unchanged; drift is detected and repaired; plan/check perform no write; a file no-op leaves mtime alone; validation failure leaves the live object; a partial transfer leaves the destination and removes owned staging; directory absence is one level; symlink/file/directory conflicts are explicit.
  The fake is test-only; production never selects it.

- **C4 — CLI, selection, jobs, failure policy, reporting** (M). Prereq: C3. Owns `bin/xinfra.xsh`, `lib/xinfra/cli.xsh`, `lib/xinfra/report.xsh`, `lib/xinfra/redact.xsh`, `lib/xinfra/outcome.xsh`, `tests/test-cli.xsh`, `tests/test-report.xsh`.
  Acceptance: `xsht test tests/test-cli.xsh tests/test-report.xsh`. Covers `doctor`/`plan`/`apply`/`check` help, `--inventory`, `--deploy`, `--limit`, `--exclude`, `--jobs` (default 8, max 64), `--on-error`, `--format human|json|jsonl`, `--save-plan`, `--plan`, and `unlock --host NAME --force`; golden JSON/JSONL schema; exit codes from D8; control-sequence sanitization; per-host failures as data through the fake transport.

### Phase 3 — Remote parity

- **R1 — SSH transport adapter, shell contract, and doctor** (M). Prereq: W6, C4. Owns `lib/xinfra/transport.xsh`, `lib/xinfra/remote.xsh`, `lib/xinfra/doctor.xsh`, `dev/integration.xsh` (dispatcher), `dev/integration/transport.xsh`.
  Acceptance: `dev/integration.xsh --case transport`. Against `xinfra-a` and `xinfra-b`: doctor probes `/bin/sh`, `LC_ALL=C`, `PATH`, `stat`, `sha256sum`, `mktemp`, `mv -T`, `apk`, `rc-service`, passwordless `sudo`, and passwordless `doas`; exec preserves stdout/stderr and exit status; wrong host key and denied key fail before mutation; hostile argv values round-trip; NUL is rejected; timeout/cancellation reports certainty; connection reuse keeps one handshake for a batch of facts.

- **R2 — Remote facts, cache, and absent/denied distinctions** (L). Prereq: R1. Owns `lib/xinfra/facts.xsh`, `lib/xinfra/parse.xsh`, `lib/xinfra/cache.xsh`, `dev/integration/facts.xsh`.
  Acceptance: `dev/integration.xsh --case facts`. Matrix: file present, absent, permission-denied, and malformed; user/group present and absent; package present/absent/version; service started/stopped/enabled; unreadable fact is `unknown`, never `absent`; no mutation; batch queries; cache scoped by host, privilege, query, and generation and invalidated after a mutation.

- **R3a — Remote directories and symlinks** (M). Prereq: R2. Owns `lib/xinfra/resources/dir.xsh`, `lib/xinfra/resources/symlink.xsh`, `dev/integration/dirs.xsh`.
  Acceptance: `dev/integration.xsh --case dirs,symlinks`. First apply, second unchanged, drift repair, plan/check no mutation, one-level absence, explicit type conflicts, symlink replacement policy, no traversal, hostile path quoting.

- **R3b — Remote files, staging, validation, and large transfers** (L). Prereq: R3a. Owns `lib/xinfra/resources/file.xsh`, `lib/xinfra/staging.xsh`, `dev/integration/files.xsh`.
  Acceptance: `dev/integration.xsh --case files`. Validation failure preserves the live config and does not activate; failed/partial transfer preserves the destination and cleans owned staging; 128 MiB binary artifact by digest; no-op leaves mtime; ownership/mode/type verification; hostile paths; trusted-parent rejection; promotion is same-filesystem and type-checked.

- **R4a — Alpine packages** (M). Prereq: R2. Owns `lib/xinfra/resources/package.xsh`, `dev/integration/packages.xsh`.
  Acceptance: `dev/integration.xsh --case packages`. Present/absent, exact and constrained versions through `apk` semantics, `apk version -t` for comparisons, metadata refresh only on apply and reported separately, plan performs no refresh or install, unsupported constraint fails before mutation. If the guest cannot reach the Alpine CDN, build a local apk repository under `.work/fixtures/apk` and point the guest at it; do not weaken the package test.

- **R4b — Users and groups** (M). Prereq: R2. Owns `lib/xinfra/resources/user.xsh`, `lib/xinfra/resources/group.xsh`, `dev/integration/users.xsh`.
  Acceptance: `dev/integration.xsh --case users`. Presence, IDs, groups, home, shell; existing conflicts conservative; `absent` never deletes a non-empty home; UID/GID changes are rejected; failed privilege escalation is reported as failed or partial with the observed account state, never as success; second apply unchanged.

- **R5 — Commands, OpenRC services, and change notifications** (M). Prereq: R3b, R4b. Owns `lib/xinfra/resources/command.xsh`, `lib/xinfra/resources/service.xsh`, `lib/xinfra/notify.xsh`, `dev/integration/commands.xsh`, `dev/integration/services.xsh`.
  Acceptance: `dev/integration.xsh --case commands,services`. Covers explicit argv and shell modes, `creates`/`unless`/`always_run`, plan refuses to run guards, timeout, change triggers, OpenRC start/stop/enable/disable, one coalesced restart for several changed files, and no activation after a failed validation or dependency. Inspect Laputa's public service contract at `064ad8c6100a087b1b2c67d6910f9b4e814ff67f` before adding the adapter; do not modify Laputa.

- **R6 — Multi-host barriers, failure policy, locks, cancellation** (L). Prereq: R3b, R4b, R5. Owns `lib/xinfra/scheduler.xsh`, `lib/xinfra/lock.xsh`, `dev/integration/multi_host.xsh`, `dev/integration/lock.xsh`.
  Acceptance: `dev/integration.xsh --case multi-host,ordering,lock,cancel`. Operation N completes or fails on every participating host before N+1; hosts run concurrently up to `--jobs`; one failed host does not cancel healthy independent hosts; default, abort, and continue policies match D8; dependent/global stages abort; competing applies produce one lock holder; stale locks need the boot-id proof or explicit unlock; disconnect at a mutation boundary is `unknown`, not success, and is never retried automatically.

- **R7 — Secrets and reporting hardening** (M). Prereq: R3b, R5. Owns `lib/xinfra/secret.xsh`, `lib/xinfra/redact.xsh`, `dev/integration/secrets.xsh`, `dev/integration/reporting.xsh`.
  Acceptance: `dev/integration.xsh --case secrets,reporting`. Canary secrets never appear in human/JSON/JSONL/error/trace output; secret staging is `0600`; secrets work only through file content and command stdin; an unchanged secret file is a no-op; terminal control sequences and overlong fields are sanitized; primary failures survive cleanup failures.

- **R8 — Saved plans and stale observations** (M). Prereq: R2, R6. Owns `lib/xinfra/plan_artifact.xsh`, `dev/integration/plans.xsh`.
  Acceptance: `dev/integration.xsh --case stale-plan`. Plan save/load round-trip; a changed source, deployment, inventory, or precondition rejects with exit 2 before mutation; conditional/unknown actions cannot be saved; no secrets in the artifact; a stale approval never becomes a larger change.

### Phase 4 — Differential, scenarios, documentation

- **Q1 — pyinfra differential oracle** (M). Prereq: R5. Owns `dev/differential.xsh`, `dev/oracle/`, `docs/compatibility.md`.
  Inspect pyinfra's current facts, operations, execution semantics, and selected tests before porting behavior. Acceptance: `make differential`. Two fresh `xinfra-*` guests; pinned pyinfra 3.10.0 in `.work/oracle/venv` with isolated `HOME`; equivalent files, directories, packages, users/groups, commands, and OpenRC services; compare resulting state, changed/no-op behavior, and failures, not command text. pyinfra is a reference, not an oracle: investigate every disagreement and test intended semantics independently. Update the compatibility/deviation table; install no Python or pyinfra on a product guest or in a package.

- **Q2 — Full integration scenario suite** (L). Prereq: R1–R8, Q1. Owns `dev/integration.xsh` and `dev/integration/`.
  Acceptance: `make integration` runs every case in **Acceptance** green on the integrated tree, plus `make check` and `make test`. Individual cases are the slice loop; the full Q2 run is a milestone and may exceed the 15-minute acceptance threshold, so record per-case timings and bisect by case. This is the parity gate; do not start O1 before it passes.

- **Q3 — Docs, capability matrix, packaging** (M). Prereq: Q2. Owns `README.md`, `docs/`, `examples/`, `install.sh`, `dev/package.xsh`, `Makefile` (install/package targets).
  Acceptance: `make package` builds the tarball; `make install PREFIX=$PWD/.work/tmp/install` installs it; the installed `xinfra --help` and `xinfra --version` run without the source tree; the tarball contains no Python, pyinfra, toolchain, test server, key, or build cache. Docs cover trust setup, secrets, doas/sudo, planning, failures, locks, partial outcomes, recovery, the resource table, the report schema, the remote POSIX/BusyBox baseline, a controller/remote capability matrix, and an architecture note listing deliberate omissions. Include a `NOTICE` for any adapted pyinfra material; otherwise record the reference version only.

### Phase 5 — Measure and polish

- **O1 — Performance and resource measurements** (M). Prereq: Q3. Owns `dev/perf.xsh`, `docs/performance.md`.
  Acceptance: `make perf` records startup, peak RSS, connection count, and first/no-op deployment costs against pinned pyinfra on equivalent fresh guests; separates handshake/network from controller time; reports the xsh binary-size change from W6; follows the `perf-gate-ready` protocol and records a deferral when the host is busy. No optimization lands unless a measured cost exceeds the observed spread and the item is explicitly re-opened.

### Phase 6 — Close

- **Z1 — Review, delete, and report** (M). Prereq: all local items. Owns `docs/qualification.md`, `TODO.md`, **Status**.
  Acceptance: `make check && make test && make integration && make differential && make package` on the integrated tree; run `/ultrareview`, fix P1 and P2 findings, record P3/P4 in `TODO.md`; delete dead code and fixtures that no check uses; write exact commits, commands, results, platform coverage, measured costs, and remaining limitations in `docs/qualification.md`; update **Status** in place. No push.

### Parallel lanes

- W and C may run together only after G0 and while `perf-gate-ready -s` reports headroom. W owns its XSH checkout (main if clean, otherwise the `xinfra-ssh` worktree); C owns this repository. No other pair is parallel.
- The default serial order is G0 → W1–W6 → C1–C4 → R1–R8 → Q1–Q3 → O1 → Z1. Local C work may start before W6 because it uses only fake HostOps.
- If W is parked on an unavailable checkout, continue C1–C4; do not start R. If W2 fails three attempts, park W and R, finish C/Q local proof, and report the transport blocker.

## Acceptance

### Deliverable proof

| Deliverable | Item | Command |
| --- | --- | --- |
| Pinned native SSH client subset | W6 | `dev/fixtures.xsh exec --cwd "$XSH_ROOT" -- cargo test --release --target aarch64-apple-darwin -p xsh-ssh` plus `xsht api module:ssh` |
| Inventory and deployment model | C2 | `xsht test tests/test-model.xsh tests/test-validate.xsh tests/test-plan.xsh` |
| Local resource semantics | C3 | `xsht test tests/test-dir.xsh tests/test-file.xsh tests/test-symlink.xsh` |
| CLI and report schema | C4 | `xsht test tests/test-cli.xsh tests/test-report.xsh` |
| Remote transport and facts | R1, R2 | `dev/integration.xsh --case transport,facts` |
| All resources and failure policy | R3a–R6 | `dev/integration.xsh --case dirs,symlinks,files,packages,users,commands,services,multi-host,ordering,lock,cancel` |
| Secrets and saved plans | R7, R8 | `dev/integration.xsh --case secrets,reporting,stale-plan` |
| Differential parity | Q1 | `make differential` |
| Full scenarios | Q2 | `make integration` |
| Installable package | Q3 | `make package && make install PREFIX=$PWD/.work/tmp/install` |
| Measured costs | O1 | `make perf` |
| Final qualification | Z1 | `make check && make test && make integration && make differential && make package` |

### Integration scenarios

`make integration` runs these named cases; each starts from a clean guest state and asserts both the resulting state and the reported outcome.

| Scenario | Case | Item |
| --- | --- | --- |
| Complete Alpine example with packages, users/groups, files, and service | `example` | Q2 |
| First apply, second no-op, drift detection/repair, plan/check no mutation | `example` | R3, R4, R5 |
| Validation failure preserves the live config and skips activation | `files`, `services` | R3b, R5 |
| Failed/partial transfer preserves the destination and staging is safe | `files` | R3b |
| Hostile paths, quotes, newlines, empty values, leading hyphens | `hostile` | R1, R3 |
| Binary artifact larger than capture limits | `large-binary` | W4, R3b |
| Failed privilege escalation | `privilege` | R1, R4b |
| Unknown or changed host key rejected before mutation | `transport` | W2, R1 |
| One failed host among healthy hosts | `multi-host` | R6 |
| Bounded concurrency and operation ordering | `ordering` | R6 |
| Cancellation and disconnect at mutation boundaries | `cancel` | W4, R6 |
| Competing apply processes | `lock` | R6 |
| Stale observations and saved plans | `stale-plan` | R8 |
| Secret redaction in logs, errors, JSON, and traces | `secrets` | R7 |
| Package index refresh apply-only and separately reported | `packages` | R4a |
| User/group conflicts and no destructive home or UID change | `users` | R4b |
| Coalesced service notification, one reload/restart | `services` | R5 |

### Report schema and exit codes

Structured output is schema version 1. `--format json` emits one object with a `results` array; `--format jsonl` emits one `kind: "result"` object per line and a final `kind: "summary"`. Required result fields: `schema_version`, `kind`, `run_id`, `host`, `resource`, `phase`, `outcome`, `verified`, `cause`, `duration_ms`. Required summary fields: `schema_version`, `kind`, `run_id`, `hosts`, `unchanged`, `changed`, `skipped`, `blocked`, `failed`, `unknown`, `partial`, `exit`. Exit codes are D8. Human output sanitizes control sequences.

## Needs environment

- **Linux x86_64 controller lane.** `ubuntu@oracle` via Tailscale SSH was unverified at preflight: tailnet ping and port 22 timed out. The owner can run the macOS-identical `make check test integration` with a Linux `xsh`/`xsht` release pair after copying the tree to a disposable directory under the owner's home there and removing it afterward. This does not block macOS local completion; record the unexecuted lane as unqualified.
- **OpenSSH variants other than Alpine 3.23/OpenSSH 10.x.** Only the Alpine guest is qualified. Dropbear, BSD, and older OpenSSH are unqualified and must fail clearly rather than select a guessed adapter.
- **Busy host during perf measurement.** If `perf-gate-ready` reports no headroom, record `perf gate deferred: host busy`; do not claim a pass.

## Execution boundary and non-goals

### Authorized

- Write roots: `/Users/josh/d/xinfra`, `/Users/josh/d/xsh` for W items only (including the `xinfra-ssh` worktree under `../xsh/.work/wt/`), and `.work` in both. No other repository or home directory.
- Read-only network: GitHub, PyPI, Alpine CDN, and Lima downloads. Fixture VMs may reach the Alpine package repository; if that fails, build a local apk repository under `.work` rather than weakening a package test.
- Disposable Lima guests named `xinfra-*`; fixture users, keys, host keys, and service files exist only there.
- Fixture provisioning and the pyinfra oracle may use the host's `ssh` and `limactl`; the product path and every xinfra transport test use the native client only.
- `gh`/`git` reads for the pinned pyinfra, ssh-build, and Laputa sources; no pushes.

### Forbidden

- Production inventory, real hosts, the operator's `~/.ssh/config`, `known_hosts`, or agent; any change to host trust outside a disposable guest. Never rewrite doas or sudo policy or SSH access to obtain permission.
- External `ssh`/`scp`/`sftp` in the product; pyinfra or Python on a product guest or in a package; a remote XSH runtime, persistent deployment daemon, remote `jq`, systemd assumption, or hidden package-manager bootstrap.
- ssh-build's Git-only OxiSH server as a provisioning endpoint, or broadening that server's permissions. Fixtures use an ordinary OpenSSH server.
- Docker/OrbStack repair or reliance; `/tmp`, `$TMPDIR`, or `/var/folders` for worktrees, fixtures, or scratch.
- Pushing, release tags, CI edits, formatters, rewriting xsh history, changing the pinned Rust nightly, or cleaning another writer's `../xsh` changes.
- Secrets in inventory examples, fixtures, saved plans, test logs, or packages.
- Fleet-wide transactions, general rollback, exact dry-run predictions for unmodeled commands, or a claim that a plan leaves the host untouched. Deployment programs are trusted operator code; `plan` does not sandbox arbitrary XSH.
- Source-line hashing, a hidden global host context, metaprogramming, or a plugin framework.

### Contract changes to surface

- W5 adds a public `ssh` module to XSH (new records, errors, and session handles). D1 authorizes the subset; W5 documents it and W6 qualifies it. The W commits live on local branch `xinfra-ssh` when the main tree is dirty; the owner merges them.
- xinfra introduces the inventory schema, deployment `module.load` contract, resource table, report schema, saved-plan schema, and the `unlock --force` operator command.
- The v1 trust contract is a pinned `SHA256:` host key plus an unencrypted Ed25519 key file. `known_hosts`, agent, password, PTY, forwarding, SFTP, and certificate trust are explicit unsupported errors, not silent fallbacks.

### Supersessions and deliberate omissions

- **Full XSH-55 is not delivered here.** Agent authentication, `known_hosts` modes, password/keyboard-interactive, PTY, forwarding, SFTP, and non-Ed25519 algorithms are deferred and fail explicitly. Reason: D1's minimal subset is what xinfra consumes; the full RFC remains open upstream. This supersedes the draft's implication that the whole native contract is available.
- **Docker-based Linux verification is replaced by Lima/macOS plus a Needs-environment Linux lane.** Reason: the local Docker daemon is broken at preflight; no Docker repair is in scope.
- **The draft's "property tests" become deterministic generated corpora** for quoting, paths, IDs, and validation. Reason: XSH has no property framework, and the same failure classes are covered by table-driven cases.
- **Packaging follows D12, not an unstated prerelease convention.** No owner convention was found for a new repository; the source tarball plus install script is the smallest reproducible artifact.
- **The Laputa service contract is read, not integrated.** No OpenRC changes go into Laputa; the adapter stays in xinfra.
- **No full pyinfra port, plugin framework, remote XSH runtime, daemon, systemd, remote jq, source-line hashing, global host context, or fleet transaction/rollback claim.**

## Reference

### Pins

| Item | Pin |
| --- | --- |
| XSH | `ef924bf63f9ee138d99ac299a37e234555622e23`; release `xsh` `e4b7e0946b51b97722f396f51e539214c0ca72ea7667deab77b96547c3412fa6`, `xsht` `ad1b779d5686599764efeed1f895aaef6dce9bc8aa1c724bed421c94aa2d235d` |
| ssh-build | `bc2a9fb418ac48c9e00b5138fa800e4a7c724315`; licenses in `vendor/oxish`, Graviola `0.4.1` |
| Laputa service contract | `064ad8c6100a087b1b2c67d6910f9b4e814ff67f` (read-only reference) |
| pyinfra | `3.10.0` (MIT), Python 3.13, isolated venv |
| Alpine fixture | Alpine 3.23.4 Lima template; image digest recorded by G0 in `dev/fixtures/alpine.yaml` |
| Lima | 2.2.1 |

### Code map

- `../xsh/Cargo.toml:10-33` — workspace members; add `crates/xsh-ssh` here.
- `../xsh/src/modules/mod.rs:1-31` — standard module registration; add `ssh` here.
- `../xsh/crates/xsh-net/Cargo.toml`, `../xsh/crates/xsh-net/src/lib.rs` — the native transport boundary pattern the SSH crate follows.
- `../xsh/src/modules/README.md` — routing for signatures, runtime operations, records, and adapters.
- `../xsh/docs/rfc/XSH-55-native-ssh-client.md` — native client architecture, trust, cryptography, and test contract.
- `../xsh/docs/rfc/XSH-56-xsh-infra.md` — source xinfra RFC.
- `../xsh/docs/ROADMAP.md` — sequence and prerequisite ordering.
- `../xsh/docs/TESTING.md` — gates, native tests, and Linux profiles.
- `../xsh/docs/RELENG.md` — release profiles, size record, and the 5% binary-size gate.
- `../xsh/docs/user-tour.md` — module layout, `cli main`, `xsht test`, `par-map`, `defer`, and effects.
- `../xsh/docs/XSHT.md` — module resolution, `module_path`, `test_roots`, and check semantics.
- `../xsh/docs/SPEC.md` §4.9 — module contracts used by the deployment loader.
- `dev/fixtures.xsh`, `dev/integration.xsh`, `dev/differential.xsh`, `dev/perf.xsh` — the local proof loop.
- `lib/xinfra/model.xsh`, `lib/xinfra/remote.xsh`, `lib/xinfra/facts.xsh`, `lib/xinfra/resources/` — the product split; W owns only `../xsh`, C/R own this tree.
