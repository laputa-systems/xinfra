# TODO

Prefix: XIN
Next: 8

### XIN-2 · P3 · Package index refresh is not visible in reports

- **Area:** Operability
- **Where:** `lib/xinfra/driver.xsh:147`, `lib/xinfra/resources/package.xsh:10`, `docs/resources.md:25`
- **Problem:** `PackageApply.refreshed` records whether `apk update` ran, but `driver.apply` returns only `PackageApply.result`. The CLI report has no refresh field or row, so an operator cannot see that apply refreshed the index, despite the resource documentation saying it is reported.
- **Recommendation:** Surface refresh as a result field or a separate apply phase row, or remove the reporting claim.
- **Fix with:** `none`
- **Effort:** S

### XIN-3 · P3 · Rendered templates are not size-bounded

- **Area:** Security
- **Where:** `lib/xinfra/validate.xsh:159`, `lib/xinfra/validate.xsh:184`
- **Problem:** `MAX_TEMPLATE_BYTES` checks the template source size, not the rendered output. A small template with a large variable or repeated expansion can render far beyond 16 MiB, then be hashed and streamed.
- **Recommendation:** Reject a rendered string over `MAX_TEMPLATE_BYTES` before hashing or preparing it.
- **Fix with:** `none`
- **Effort:** S

### XIN-4 · P3 · Package and symlink name validation reject or defer supported inputs

- **Area:** Types
- **Where:** `lib/xinfra/model.xsh:425`, `lib/xinfra/model.xsh:413`, `lib/xinfra/remote.xsh:37`
- **Problem:** Package names use `valid_identifier`, which rejects common Alpine names such as `libstdc++` and repository tags such as `foo@edge`. A symlink target such as `../current` validates but `remote_path` rejects any `..` component at apply, so the failure arrives after planning. `remote.symlink` also does not pass `--` before the target.
- **Recommendation:** Add a package-name rule that permits Alpine syntax, add a symlink-target rule that permits relative parents, and pass `--` to `ln`.
- **Fix with:** `make-invalid-states-unrepresentable`
- **Effort:** S

### XIN-5 · P3 · A service notification adds a second row with the service resource ID

- **Area:** Data
- **Where:** `lib/xinfra/cli.xsh:1130`
- **Problem:** A notification restart appends an `Applied` row with the same `resource` ID as the service action. JSON and JSONL consumers see two rows with the same `(run_id, host, resource)` key, and the summary counts both changes.
- **Recommendation:** Fold the notification result into the service row, or give it a distinct phase and identifier.
- **Fix with:** `none`
- **Effort:** S

### XIN-6 · P3 · Saved plans pin the xinfra version but not the XSH build

- **Area:** Data
- **Where:** `lib/xinfra/cli.xsh:819`
- **Problem:** The saved plan stores `xinfra` `0.1.0` but not the XSH commit. A controller using a different XSH build can accept the same artifact even though parser or runtime behavior changed.
- **Recommendation:** Record the XSH commit from the build or an explicit `XSH_PIN` value and compare it like the version.
- **Fix with:** `none`
- **Effort:** S

### XIN-7 · P4 · The repository has no project license

- **Area:** Build
- **Where:** `README.md:1`, `NOTICE:1`
- **Problem:** The tarball carries a `NOTICE` and third-party attribution but no license for xinfra itself. Redistribution terms are undefined.
- **Recommendation:** The owner chooses a license and adds its text and a matching README/NOTICE reference.
- **Fix with:** `none`
- **Effort:** S
