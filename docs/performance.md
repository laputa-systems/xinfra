# Performance measurements

These numbers describe the implementation at the Q3 tree. They are
measurements, not promises. The host was constrained during the run, so the
time gate was deferred and no optimization was accepted from this pass.

## Environment

| Item | Value |
|---|---|
| Date | 2026-10-31 |
| Controller | macOS arm64 |
| XSH product | `target/aarch64-apple-darwin/release/xsh` |
| Guest | Alpine 3.23.4, OpenSSH 10.x, BusyBox 1.37 |
| xinfra guest | `xinfra-b` |
| pyinfra guest | `xinfra-a` |
| pyinfra | 3.10.0, Python 3.13, isolated `HOME` |

`perf-gate-ready -s` reported a constrained host: 18 cores, load 6.86
(0.38/core), 90% memory free, swap 5109 of 6144 MiB used. The run printed
`perf gate deferred: host busy`. `perf-gate-ready -1` was called after the
measurement.

## Method

Both guests started from the same reset: no `tree` package, no
`xinfra-q1-group`, no `xinfra-q1-user`, no performance base, and `crond`
stopped and disabled. The deployment creates one directory, one file, the
`tree` package, a group, a user with a home, one unconditional command, and
the `crond` service.

- Wall time is `time.monotonic()` around the controller process, including
  process launch and captured output.
- Peak RSS is `/usr/bin/time -l` maximum resident set size.
- SSH connections are the delta of `Accepted publickey` lines in the guest
  `/var/log/messages`. A persistent controller session used for reset and log
  reads was open before and after each run, so it cancels out.
- Startup is the median of five `--version` runs.
- Handshake is the median of five connect, authenticate, and close runs.
- Round trip is the median of five `true` commands on one session.
- Local plan is the median of five module-load, validation, and
  empty-fact planning runs on the controller.

## Results

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

Supporting measurements:

| Measurement | Value |
|---|---:|
| SSH handshake and authentication | 14 ms |
| Remote `true` round trip | 1 ms |
| Local module load, validation, and plan | 3 ms |

## Interpretation

xinfra startup and no-op cost more than pyinfra on this run. The controller
opens one short-lived SSH session for each observation and each action. A
seven-resource deployment makes 24 connections: seven for the initial fact
collection, one to acquire the host lock, seven to re-read facts under the
lock, seven during apply, one coalesced service restart, and one to release the
lock. pyinfra made two connections. Each handshake measured about 14 ms, and
the local plan measured about 3 ms, so the connection count, not XSH
evaluation, accounts for most of the gap.

The first apply is slower than the second in both tools because it installs a
package and creates an account. The native client is not claimed to be faster
than pyinfra.

## Binary size

The stripped `dist` `xsh` binary is 23,704,272 bytes. W6 recorded the same
23,704,272 bytes, so the change is 0 bytes (0.0%). The 5% size gate passes.

## Limitations

- One run on a constrained host. Treat these values as indicative.
- The time gate was deferred, not passed.
- Only the macOS arm64 controller was measured.
- RSS is the controller process, not a sum over remote commands.
- The current apply path is sequential; `--jobs` is not used.
- A session-reuse optimization could remove most handshakes, but it is not
  opened or landed from this deferred gate.
