# Project diagnostics

`moonhermetic doctor` checks whether a MoonBit project is ready to use
MoonHermetic locally and in CI.

```bash
moon run cmd/main -- doctor
```

The command inspects:

- The target path and number of `_test.mbt` / `_wbtest.mbt` files.
- `.moonhermetic.json` syntax, known fields, rules, and exclusions.
- Suppression owner/expiry metadata and expired or invalid directives.
- Baseline schema, path safety, accepted findings, and stale counts.
- New findings outside the baseline.

Every check returns `pass`, `warning`, or `error`, with a concrete next action
where possible.

## Options

```text
moonhermetic doctor [path]
  --config <path>
  --no-config
  --baseline <path>
  --no-baseline
  --format <text|json>
  --strict
```

Without `--baseline`, `.moonhermetic-baseline.json` is discovered
automatically when present.

## Exit behavior

- Errors return exit code 1.
- Warnings return 0 in normal mode.
- `--strict` makes warnings return 1.
- Success returns 0.

## Machine-readable output

```bash
moon run cmd/main -- doctor --format json --strict
```

The JSON schema is `moonhermetic/doctor-v1`. It contains stable status values,
summary counts, the current tool version, and optional remediation text.

## Typical remediation

```bash
# Missing configuration
moon run cmd/main -- init --no-baseline

# Missing or stale baseline
moon run cmd/main -- init

# Expired suppression
# Update owner= and expires= on the source directive.

# New findings
# Fix the dependency or intentionally refresh the baseline after review.
```
