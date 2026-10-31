# xinfra

xinfra is a small configuration-management tool for Alpine hosts. It loads a
typed inventory and deployment, compares desired state with observed state,
and applies directories, files, symlinks, `apk` packages, users, groups,
commands, and OpenRC services over a native SSH connection.

The controller runs XSH scripts. The managed guest needs only a POSIX shell,
BusyBox, `apk`, and OpenRC. It does not need Python, an agent, or a daemon.

## Requirements

- XSH with the `ssh` module. Every xinfra command loads the native SSH
  surface, so an XSH build without that module fails at startup.
- Alpine 3.23 or a compatible BusyBox/OpenRC host.
- An unencrypted Ed25519 SSH key for the remote account.
- Passwordless `doas` or `sudo` for resources that run as root.
- A pinned `SHA256:` host-key fingerprint for every inventory host.

## Install

From a source checkout:

```sh
make package
make install PREFIX=$HOME/.local
```

The installed `$PREFIX/bin/xinfra` wrapper runs the library under
`$PREFIX/libexec/xinfra` with `${XSH:-xsh}`. Set `XSH` to choose a specific XSH
binary:

```sh
XSH=/path/to/xsh xinfra --version
```

You can also unpack the tarball and run `./install.sh /usr/local`.

## Quick start

Create an inventory. The key path is relative to the inventory file:

```toml
groups = ["web"]

[[hosts]]
name = "web-1"
groups = ["web"]
address = "203.0.113.10"
port = 22
user = "deploy"
key = "keys/deploy_ed25519"
host_key = "SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
```

Create a deployment module. A deployment only declares resources:

```xsh
##! Web host.
use xinfra.model

## The declared resources.
export pure resources() -> List[model.Resource] {
  [
    model.Package(model.PackageSpec(id: "nginx-pkg", name: "nginx")),
    model.File(model.FileSpec(
      id: "motd",
      path: p"/etc/motd",
      source: model.Content("managed by xinfra\n"),
      owner: "root",
      group: "root",
      privilege: model.AsRoot,
    )),
    model.ServiceResource(model.ServiceSpec(
      id: "nginx",
      name: "nginx",
      state: model.Started,
      enabled: true,
      requires: ["nginx-pkg"],
    )),
  ]
}
```

Then plan, inspect, and apply:

```sh
xinfra plan --inventory inventory.toml --deploy deploy.xsh
xinfra check --inventory inventory.toml --deploy deploy.xsh
xinfra apply --inventory inventory.toml --deploy deploy.xsh
```

`plan` and `check` never mutate the guest. `apply` stages file content beside
the destination, verifies it, and promotes it atomically. A second apply is a
no-op.

See [trust and secrets](docs/security.md), [resources](docs/resources.md),
[operations](docs/operations.md), and [platform support](docs/platform.md).

## Commands

| Command | Purpose |
|---|---|
| `doctor` | Validate the inventory and deployment and list selected hosts. |
| `plan` | Compute ordered actions without touching a host. |
| `check` | Report drift; exit 1 when any action is needed. |
| `apply` | Apply the plan with the selected failure policy. |
| `unlock` | Report an explicit forced lock release for one host. |

Global options include `--inventory`, `--deploy`, `--limit`, `--exclude`,
`--format human|json|jsonl`, `--jobs N`, and `--on-error isolate|abort|continue`.
Run `xinfra --help` or `xinfra <command> --help` for the complete list.

Exit codes follow the operation: `0` success or compliant, `1` drift or a
failed/blocked/unknown/partial result, `2` usage, validation, transport, or
stale-plan failure.

## Development

```sh
make check        # static checks
make test         # 100 unit and goldens
make integration  # every remote scenario on the fixtures
make differential # compare against pyinfra 3.10.0
```

`make fixtures` starts the disposable Lima guests, `make verify` probes them,
and `make down` removes them. Fixture state lives under `.work`.

See [compatibility](docs/compatibility.md) for the reference comparison.
