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
- Inline suppression with `// hermetic:ignore` and
  `// hermetic:ignore-next`.
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
      --exclude <text>
      --rules
  -h, --help
  -V, --version
```

Without a path, MoonHermetic scans the current directory. It only selects
files ending in `_test.mbt` or `_wbtest.mbt`, and skips `_build`, `.git`,
`.mooncakes`, `.moonagent`, `target`, and `node_modules`.

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

Suppress a reviewed exception on the same line:

```moonbit
sleep(20) // hermetic:ignore: timing service must expire the lease
```

Or suppress every finding on the following line:

```moonbit
// hermetic:ignore-next: test intentionally reads the host locale
let locale = @env.get_env_var("LANG")
```

Suppression is deliberately local. There is no project-wide silent bypass.

## GitHub Actions

```yaml
- name: Hermeticity audit
  run: |
    moon run cmd/main -- . --exclude examples \
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
let findings = @moonhermetic.scan_source("billing_test.mbt", source)
let report = @moonhermetic.make_report(1, findings)
println(@moonhermetic.render_markdown(report))
```

## Roadmap

- Add opt-in rule configuration in `.moonhermetic.json`.
- Track suppressions and reject expired exceptions.
- Add diff-aware mode for pull requests.
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
