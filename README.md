# MoonHermetic

MoonHermetic is a static hermeticity auditor for MoonBit tests. It finds tests
that silently depend on the machine, clock, network, filesystem, random state,
or timing before those tests become flaky in CI.

It is intentionally narrower than a general static-analysis framework and
different from runtime flake classifiers: MoonHermetic does not rerun failed
tests or infer a root cause from historical results. It makes likely
non-hermetic code visible during review and fails a release gate early.

## Why this project

MoonBit's structured concurrency and cross-target toolchain make it practical
to run the same tests in many environments. Tests that read `@env.now()`, an
ambient environment variable, a live endpoint, or an unseeded random source
defeat that portability.

The initial Mooncakes keyword audit found adjacent runtime flake and test
tooling, including `mizchi/flaker`, but no direct static "test hermeticity"
scanner. MoonHermetic complements those tools by reporting the risky source
location and a concrete remediation before the test is executed.

## Features

- Seven rules: wall clock, randomness, environment, network, subprocess,
  filesystem, and sleep/timing dependencies.
- Comment- and literal-aware scanning with precise file, line, and column
  locations.
- Rule-specific inline suppression with owners, expiry dates, and
  `// hermetic:ignore-next`.
- Project configuration for rule disabling, severity overrides, exclusions, and
  the default CI failure threshold.
- Unified-diff mode that reports only findings introduced on changed lines.
- Text, JSON, Markdown, and SARIF 2.1.0 output.
- CI-friendly exit codes and deterministic file traversal.
- No opinionated test-replacement framework: it points to the boundary that
  should be injected or faked.

## Quick start

Requirements: a current MoonBit toolchain and MoonBit 0.1.20260920 or newer.

```bash
git clone https://github.com/kobe108/moonhermetic
cd moonhermetic
moon check
moon test
moon run cmd/main -- . --fail-on warning
```

Example output:

```text
examples/risky/checkout_test.mbt:20:18: error [HERM-NET] External network dependency
  evidence: let response = fetch(endpoint)
  fix: Use a fake transport or a deterministic local fixture instead of a live service.

MoonHermetic scanned 2 test file(s): 3 finding(s), 2 error(s), 1 warning(s).
```

## CLI

```text
moonhermetic [options] [file-or-directory ...]

  -f, --format <text|json|markdown|sarif>
      --fail-on <never|warning|error>
      --config <path>
      --no-config
      --diff <path>
      --exclude <text>
      --rules
  -h, --help
  -V, --version
```

Without a path, MoonHermetic scans the current directory. It only selects
files ending in `_test.mbt` or `_wbtest.mbt`, and skips `_build`, `.git`,
`.mooncakes`, `.moonagent`, `target`, and `node_modules`.

## Configuration

MoonHermetic reads `.moonhermetic.json` from the current working directory when
it exists. Use `--config <path>` to select another file or `--no-config` to
disable discovery entirely.

```json
{
  "version": 1,
  "failOn": "error",
  "exclude": ["vendor"],
  "rules": {
    "HERM-NET": "warning",
    "HERM-FS": "off",
    "HERM-SLEEP": "error"
  }
}
```

Each rule accepts `off`, `warning`, or `error`. CLI `--fail-on` and
`--exclude` values override or extend the corresponding config values for one
run. Unknown rule IDs and misspelled top-level keys are rejected so a broken
policy cannot silently pass CI.

A complete example is available at
[`examples/moonhermetic.example.json`](examples/moonhermetic.example.json).

## Pull-request diff mode

Generate a unified diff in CI and pass it with `--diff`. MoonHermetic still
scans the complete test files so it can resolve findings correctly, but only
reports findings whose source line appears as an added line in the patch.

```bash
git diff --unified=0 "$BASE_SHA...HEAD" -- '*.mbt' > moonhermetic.diff
moon run cmd/main -- . --diff moonhermetic.diff --fail-on warning
```

Findings outside the patch are counted in `summary.filteredOut` and omitted
from text, Markdown, and SARIF output. Deleted lines do not count as changed
lines. A demo patch is available at
[`examples/changes.diff`](examples/changes.diff).

## Rules

| Rule | Default severity | Detects |
|---|---|---|
| `HERM-CLOCK` | warning | Wall-clock or local-time reads |
| `HERM-RAND` | warning | Randomness without an explicit seed |
| `HERM-ENV` | warning | Ambient process environment reads |
| `HERM-NET` | error | Live network or socket dependencies |
| `HERM-PROC` | warning | Child processes and shell execution |
| `HERM-FS` | warning | Files outside a managed fixture |
| `HERM-SLEEP` | error | Sleep- or elapsed-time-based synchronization |

Run `moon run cmd/main -- --rules` for the current catalog.

## Suppression

The legacy blanket directive remains available:

```moonbit
sleep(20) // hermetic:ignore: timing service must expire the lease
```

For reviewed exceptions, name only the affected rules and attach an owner and
UTC expiry date:

```moonbit
fetch("https://example.test") // hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-31
sleep(10) // hermetic:ignore HERM-SLEEP,HERM-CLOCK owner=kobe108 expires=2026-12-31
```

Use `// hermetic:ignore-next` to target the following line instead. A scoped
directive must include `owner=` and `expires=YYYY-MM-DD`. Once the UTC date is
past the expiry date, or when the directive is malformed, it stops suppressing
and the original finding reappears.

Inline suppression stays local. Rule disabling is explicit in the versioned
config file, so policy changes remain reviewable.

## GitHub Actions

```yaml
- name: Hermeticity audit
  env:
    BASE_SHA: ${{ github.event.pull_request.base.sha || github.event.before }}
  run: |
    git diff --unified=0 "$BASE_SHA" "$GITHUB_SHA" -- '*.mbt' > moonhermetic.diff
    moon run cmd/main -- . --diff moonhermetic.diff \
      --format sarif \
      --fail-on error > moonhermetic.sarif

- name: Upload SARIF
  if: always()
  uses: github/codeql-action/upload-sarif@v4
  with:
    sarif_file: moonhermetic.sarif
```

The repository's own workflow runs `moon check`, `moon test`, the scanner, and
a packaging smoke test.

## Library API

The analyzer is also usable without the CLI:

```moonbit
let findings = @moonhermetic.scan_source_with_options_and_date(
  "billing_test.mbt",
  source,
  @moonhermetic.default_scan_options(),
  "2026-11-05",
)
let report = @moonhermetic.make_report(1, findings)
println(@moonhermetic.render_markdown(report))
```

## Roadmap

- Add precision fixtures from real MoonBit projects.
- Ship signed native binaries and a reusable GitHub Action.

## Development

```bash
moon fmt
moon check
moon test
moon info
```

See [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) for the one-month delivery
plan, [docs/RULES.md](docs/RULES.md) for rule semantics and false-positive
guidance, and [docs/HACKATHON_PITCH.zh.md](docs/HACKATHON_PITCH.zh.md) for the
Chinese proposal and demo script.

The repository uses the commit identity `kobe108 <3360944005@qq.com>`.
When Git is installed, `scripts/init-git.ps1 -RemoteUrl <url>` initializes the
local repository with that identity and configures the remote.

## License

Apache-2.0.
