# Operations

## Plan, check, apply

`plan` loads the inventory, deployment, and local artifacts; reads remote
facts; and prints ordered actions. It does not write to a host.

`check` performs the same comparison and exits `1` when any action is needed.
It does not write to a host.

`apply` recomputes the plan, then applies each action in dependency order. A
changed file or package notifies its declared services after the change. A
second apply compares digests and modes and is a no-op.

Exit codes:

| Code | Meaning |
|---|---|
| `0` | Success, or no drift for `check`. |
| `1` | Drift, or any failed, blocked, unknown, or partial apply result. |
| `2` | Usage, validation, transport, or stale-plan failure before or during computation. |
| `130` | Interrupted. |

## Failure policy

`--on-error` selects what happens after an action fails:

| Policy | Behaviour |
|---|---|
| `isolate` | The failed host stops its later mutations. Independent hosts continue. This is the default. |
| `abort` | No new actions start after the first failure. In-flight work is not cancelled. |
| `continue` | Independent actions and hosts continue. Dependents of the failed resource are blocked. |

A resource whose `requires` target failed is `blocked`. A host stopped by
`isolate` reports later actions as `skipped`. A disconnect after submission is
`unknown` and is never retried automatically.

## Partial outcomes and recovery

An apply result is one of `unchanged`, `changed`, `skipped`, `blocked`,
`failed`, `unknown`, or `partial`.

`partial` means the intended state was not reached after a mutation started.
`unknown` means the result could not be observed. Staging files are removed by
the scope that owns them; the live destination is preserved until promotion.
A validation failure leaves the live file and does not restart the service.

To recover, inspect the reported host and resource, repair the cause, and run
`apply` again. Re-running is safe when the action is `unchanged` or `changed`.
An `unknown` action requires an out-of-band state check before retrying,
because the first mutation may have reached the host.

## Saved plans

`plan --save-plan PATH` writes schema-version-1 JSON containing the deployment
path and digest, inventory path and digest, xinfra version, each prepared
source digest, each observed precondition, and the ordered action IDs, hosts,
and operations. Secrets and secret values are absent.

`apply --plan PATH` recomputes the deployment, inventory, facts, and actions,
then rejects a changed source, observation, version, or action with exit `2`
before mutation. A plan with an `unknown` action cannot be saved. Replan by
running `plan --save-plan` again; an approval never widens silently.

## Locks

The lock module stores an owner record below a lock directory:

```
token=...
pid=...
boot=...
start=...
host=...
```

Acquire creates the directory with `mkdir` and writes the owner. A competing
apply sees the existing owner and fails. Release removes the directory only
when the caller's token matches.

A stale lock is reclaimed only with the boot-id proof: the recorded boot ID
must differ from the current `/proc/sys/kernel/random/boot_id`. Without that
proof, reclaim requires an explicit forced unlock. The `lock` integration case
covers one holder, boot-id reclamation, and forced release.

`apply` acquires one lock per selected host before recomputing facts and
releases it after the run. The privileged path is `/run/xinfra.lock`; without a
passwordless elevator the lock is `$HOME/.cache/xinfra/lock`. Contention fails
the apply with the owner details and exit `1`.

`xinfra unlock --inventory PATH --host NAME --force` connects to the host and
removes that lock directory regardless of its owner. A removal failure exits
`1`.

## Report schema

`--format json` writes one object:

```json
{
  "schema_version": 1,
  "kind": "report",
  "run_id": "run-...",
  "results": [
    {
      "schema_version": 1,
      "kind": "result",
      "run_id": "run-...",
      "host": "web-1",
      "resource": "nginx-config",
      "phase": "apply",
      "outcome": "changed",
      "verified": true,
      "cause": "",
      "duration_ms": 12
    }
  ],
  "summary": {
    "schema_version": 1,
    "kind": "summary",
    "run_id": "run-...",
    "hosts": ["web-1"],
    "unchanged": 0,
    "changed": 1,
    "skipped": 0,
    "blocked": 0,
    "failed": 0,
    "unknown": 0,
    "partial": 0,
    "exit": 0
  }
}
```

`--format jsonl` writes one `kind: "result"` object per line and a final
`kind: "summary"` object. Human output uses the same fields, sanitizes terminal
control sequences, and redacts known secret values.

## Concurrency

`--jobs` accepts `1` through `64` with a default of `8`. The multi-host
scheduler in `lib/xinfra/scheduler.xsh` runs independent hosts concurrently and
honours barriers between stages. The current CLI apply path is sequential; it
validates `--jobs` but does not yet dispatch hosts in parallel.
