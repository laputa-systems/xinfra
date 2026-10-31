# Qualification

## Identity

| Item | Value |
|---|---|
| Product | xinfra 0.1.0 |
| XSH pin | `4c41d762e44b01fdac4d5c8986a47ee02908adcc` |
| XSH release SHA-256 | `991e76183b95873f20f9af964dd7df1b193c747d6c894446906d9df96dc48592` |
| xsht release SHA-256 | `b48f1e3b024e6977bf99662bff11b0f19df29dc265b48c0ed8db909ce8a67d42` |
| pyinfra oracle | 3.10.0, MIT, Python 3.13, unshipped |
| Qualified controller | macOS arm64 |
| Qualified guest | Alpine 3.23.4, OpenSSH 10.x, BusyBox 1.37 |

## Commit ledger

| Item | Commit |
|---|---|
| G0 fixtures | `4f78312` |
| W1 vendor SSH substrate | `1158295f1` in `../xsh` |
| W2 pinned connect | `e79e4c9f6` in `../xsh` |
| W3 auth and exec | `431e4d4b7` in `../xsh` |
| W4 streaming and rekey | `9acc8b9fe` in `../xsh` |
| W5 typed adapter | `de0ed2606` in `../xsh` |
| W6 qualification | `c4c4da20d` in `../xsh` |
| Worker session fix | `4c41d762e` in `../xsh` |
| C1 inventory | `459312f` |
| C2 model and planner | `2b2a52e` |
| C3 local resources | `da8e175` |
| C4 CLI and reports | `a5d5a68` |
| R1 transport and doctor | `c6b8fc0` |
| R2 facts and cache | `f5d6f0e` |
| R3a directories and symlinks | `45b06e5` |
| R3b files and staging | `1292d4e` |
| R4a packages | `c8e7373` |
| R4b users and groups | `d7ba30a` |
| R5 commands and services | `09c97d3` |
| R6 multi-host and locks | `e79e906` |
| R7 secrets and reporting | `9c6bfd8` |
| R8 saved plans | `0c16be7` |
| Q1 differential | `d8401e7` |
| Q2 scenarios | `3f0f250` |
| Q3 CLI remote apply | `1ad511f` |
| Q3 docs | `0254657` |
| Q3 packaging | `4ad0160` |
| O1 measurements | `5a5f1c1` |
| Z1 hardening | `457e875` |

The final acceptance below ran against `457e875` plus the documentation,
`TODO.md`, and status changes in the Z1 commit.

## Acceptance

| Command | Result |
|---|---|
| `make check` | 67 files checked, no diagnostics. |
| `make test` | 102 passed, 0 failed, 0 skipped. |
| `make integration` | Every scenario green, including example, hostile, large binary, failed privilege, transport, facts, directories, files, packages, users, commands, services, multi-host, ordering, cancellation, locks, secrets, and stale plans. |
| `make differential` | `differential: pyinfra and xinfra agree`. |
| `make package` | Built `.work/dist/xinfra-0.1.0.tar.gz`; no Python, pyinfra, toolchain, test, key, or build-cache entry. |
| `make install PREFIX=$PWD/.work/tmp/install` | Installed under `libexec/xinfra` with a `bin/xinfra` wrapper. |
| installed `xinfra --version` | `xinfra 0.1.0` from outside the source tree. |
| installed `xinfra --help` | Printed usage from outside the source tree. |
| `make perf` | Recorded below; time gate deferred because the host was constrained. |

Additional manual checks in the Z1 pass:

- A production apply acquired `/run/xinfra.lock`, released it, and left no lock directory.
- A competing lock produced exit `1` with the owner details and no mutation.
- `xinfra unlock --inventory ... --host xinfra-a --force` removed the lock.
- A source changed after `plan --save-plan` made `apply --plan` exit `2` before mutation.
- A root-owned secret file staged through elevation and finished mode `0600` with the expected content.
- A production secret validator that printed its staged file produced `[redacted]` in JSON, not the canary.
- A command timeout after submission reported `unknown`, not `failed`.
- A root-owned path was planned, checked, and applied through the CLI with `privilege: root`.

## Measured costs

Measured at the O1 tree on a constrained host. Values are indicative and the
time gate was deferred, not passed. Full method is in
[performance](performance.md).

| Metric | xinfra | pyinfra 3.10.0 |
|---|---:|---:|
| Startup, median wall | 361 ms | 229 ms |
| Startup, peak RSS | 85 MiB | 55 MiB |
| First apply, wall | 1116 ms | 654 ms |
| First apply, peak RSS | 86 MiB | 58 MiB |
| First apply, SSH connections | 24 | 2 |
| Second apply, wall | 830 ms | 368 ms |
| Second apply, peak RSS | 88 MiB | 58 MiB |
| Second apply, SSH connections | 24 | 2 |

| Supporting measurement | Value |
|---|---:|
| SSH handshake and authentication | 14 ms |
| Remote `true` round trip | 1 ms |
| Local module load, validation, and plan | 3 ms |
| Stripped `dist` xsh size | 23,704,272 bytes |
| Size change from W6 | 0 bytes, 0.0% |

## Coverage and limits

- **macOS arm64 controller:** qualified.
- **Linux x86_64 controller:** unqualified. `ubuntu@oracle` was unreachable at
  preflight, and OrbStack Docker hangs on `docker run --rm alpine:3.23 true`.
  The Linux lane and `cargo dev gate crates/xsh-ssh` were not executed.
- **Docker crypto gate:** unexecuted for the same Docker reason. The macOS
  crypto graph check passed: vendored Graviola is the only provider.
- **Guest variants:** only Alpine 3.23/OpenSSH 10.x is qualified. Dropbear,
  BSD SSH, older OpenSSH, systemd, and non-Alpine package managers are
  deliberate omissions and fail rather than guessing.
- **CLI concurrency:** apply is sequential; `--jobs` is validated but unused.
- **Saved-plan pin:** records the xinfra version, not the XSH commit.
- **Notifications:** a restart/reload appends a second report row with the
  service resource ID.
- **Remaining work:** P3 and P4 tickets are in [TODO](../TODO.md). No P1 or P2
  finding from the Z1 review remains open.

No push or tag was made. Fixtures remain disposable under `.work`; nothing in
the product package depends on them.
