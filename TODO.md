# TODO

Prefix: XIN
Next: 8

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
