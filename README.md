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
- Suppression governance reports for active, expiring, expired, legacy, and
  invalid directives.
- A reusable GitHub Action with cross-platform smoke coverage.
- Checksum-verified native binaries for Linux, macOS, and Windows releases.
- Validated Mooncakes package assets and a guarded publication workflow.
- GitHub job summaries and an optional managed pull-request comment.
- Saved baseline mode for adopting MoonHermetic in existing projects.
- A one-command `init` flow that creates configuration and a safe first
  baseline.
- Project configuration for rule disabling, severity overrides, exclusions, and
  the default CI failure threshold.
- Unified-diff mode that reports only findings introduced on changed lines.
- A pinned ten-repository precision baseline for detecting heuristic drift.
- A 19-case reviewed sample for precision, recall, and specificity checks.
- Deterministic stratified sampling with a 20-case reviewed precision sample.
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

Published Mooncakes releases can be added without cloning the repository:

```bash
moon add kobe108/moonhermetic
```

Initialize an existing project with the default configuration and baseline:

```bash
moon run cmd/main -- init
```

This creates `.moonhermetic.json` and `.moonhermetic-baseline.json`. Existing
files are never overwritten unless `--force` is supplied. Use
`--no-baseline` when only configuration is wanted, or provide a target and
custom paths:

```bash
moon run cmd/main -- init subproject \
  --config config/moonhermetic.json \
  --baseline config/moonhermetic-baseline.json
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
moonhermetic init [path] [options]

  -f, --format <text|json|markdown|sarif>
      --fail-on <never|warning|error>
      --config <path>
      --no-config
      --diff <path>
      --audit-suppressions
      --fail-on-suppression
      --baseline <path>
      --write-baseline <path>
      --summary-file <path>
      --exclude <text>
      --rules
  -h, --help
  -V, --version
```

Run `moonhermetic init --help` for initialization options.

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

## Baseline mode

Freeze the current findings when first adopting MoonHermetic:

```bash
moon run cmd/main -- . --write-baseline .moonhermetic-baseline.json
```

Later scans accept those recorded findings and fail only for new risks:

```bash
moon run cmd/main -- . \
  --baseline .moonhermetic-baseline.json \
  --fail-on warning
```

Baseline fingerprints use the rule, repository-relative path, and normalized
evidence. Moving a known finding to another line or changing whitespace keeps
it accepted. Repeated occurrences are counted, so adding a new duplicate still
creates a finding. Reports expose both accepted and stale counts; regenerate
the baseline to remove stale entries. See
[`docs/BASELINE.md`](docs/BASELINE.md) for the schema and review policy.

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

## Suppression governance

Use `--audit-suppressions` to review every directive without changing the
normal finding behavior:

```bash
moon run cmd/main -- . --audit-suppressions
moon run cmd/main -- . --audit-suppressions --format json
```

The report groups directives as:

- `active`: expires more than 30 days after the scan date.
- `expiring-soon`: expires within the next 30 days, including today.
- `expired`: the expiry date is already in the past.
- `legacy`: a blanket `hermetic:ignore: ...` directive without governance
  metadata.
- `invalid`: a scoped directive with a missing, unknown, or malformed field.

An ordinary audit exits successfully even when it finds expired or invalid
directives. For a CI gate, use:

```bash
moon run cmd/main -- . --fail-on-suppression
```

This enables the audit and exits with code 1 when any scoped directive is
expired or invalid. Legacy directives remain visible but do not fail this
optional gate. Strings, block comments, and snapshot content are ignored when
collecting directives.

## GitHub Actions

The repository is also a composite Action. On release tags it downloads the
checksum-verified binary for the runner platform; local or branch checkouts
fall back to installing MoonBit. It scans the caller's workspace, respects
`.moonhermetic.json`, and exposes the generated report path:

```yaml
permissions:
  contents: read
  security-events: write

steps:
  - uses: actions/checkout@v5

  - name: MoonHermetic
    id: hermetic
    uses: kobe108/moonhermetic@v0.13.0
    with:
      path: .
      format: sarif
      fail-on: error

  - name: Upload SARIF
    if: always()
    uses: github/codeql-action/upload-sarif@v4
    with:
      sarif_file: ${{ steps.hermetic.outputs.report-path }}
```

The Action defaults to SARIF for scans and JSON for suppression audits. It
generates a conventional report filename when `output-file` is omitted. See
[`docs/ACTION.md`](docs/ACTION.md) for all inputs, PR diff examples, the
governance gate, and artifact uploads.

For a non-Action CI runner, the same compact Markdown can be generated with:

```bash
moon run cmd/main -- . --summary-file moonhermetic-summary.md
```

Direct native binaries and their checksums are available from
[GitHub Releases](https://github.com/kobe108/moonhermetic/releases). Release
asset names include the version, platform, and architecture, for example
`moonhermetic-v0.13.0-linux-x86_64`. Each release also includes a validated
Mooncakes ZIP and checksum.

The equivalent manual workflow is:

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

- name: Suppression governance
  run: moon run cmd/main -- . --exclude examples --fail-on-suppression
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

let audits = @moonhermetic.audit_suppressions(
  "billing_test.mbt",
  source,
  "2026-11-05",
)
let governance = @moonhermetic.make_suppression_audit_report(
  1,
  "2026-11-05",
  audits,
)
println(@moonhermetic.render_suppression_audit_json(governance))
```

## Roadmap

- Add precision fixtures from real MoonBit projects.
- Add code signing and notarization for native binaries.

## Development

```bash
moon fmt
moon check
moon test
moon info
node --test tests/action-runner.test.mjs
```

Run the network-backed real-project benchmark with:

```powershell
pwsh scripts/run-precision.ps1
```

See [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md) for the one-month delivery
plan, [docs/RULES.md](docs/RULES.md) for rule semantics and false-positive
guidance, [docs/PRECISION.md](docs/PRECISION.md) for the pinned corpus, and
[docs/RELEASES.md](docs/RELEASES.md) for native binary publishing,
[docs/BASELINE.md](docs/BASELINE.md) for incremental adoption,
[docs/MOONCAKES.md](docs/MOONCAKES.md) for package publication, and
[docs/HACKATHON_PITCH.zh.md](docs/HACKATHON_PITCH.zh.md) for the Chinese
proposal and demo script.

The repository uses the commit identity `kobe108 <3360944005@qq.com>`.
When Git is installed, `scripts/init-git.ps1 -RemoteUrl <url>` initializes the
local repository with that identity and configures the remote.

## License

Apache-2.0.
