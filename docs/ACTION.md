# Reusable GitHub Action

MoonHermetic can run as a composite GitHub Action. The caller does not need to
copy an executable or MoonHermetic source into the repository.

For version tags such as `v0.11.0`, the Action downloads the matching Linux,
macOS, or Windows binary and verifies its SHA-256 checksum before execution.
Branch refs, local `uses: ./` checks, and unsupported runner architectures
fall back to installing MoonBit and running the pinned source.

Pin the action to a release tag or commit SHA:

```yaml
- uses: kobe108/moonhermetic@v0.11.0
```

## Scan and upload SARIF

```yaml
name: Hermetic tests

on: [push, pull_request]

permissions:
  contents: read
  security-events: write

jobs:
  hermetic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: MoonHermetic
        id: hermetic
        uses: kobe108/moonhermetic@v0.11.0
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

The caller's `.moonhermetic.json` is discovered automatically. No MoonBit setup
step is required. Release Actions use a verified native binary; development
refs transparently use the source fallback.

The Action appends a compact Markdown report to the GitHub job summary by
default. Set `summary: false` to disable it.

## Pull-request comments

Enable one managed MoonHermetic comment with:

```yaml
on: pull_request

permissions:
  contents: read
  pull-requests: write

# ...
- uses: kobe108/moonhermetic@v0.11.0
  with:
    format: markdown
    pr-comment: true
```

The comment contains a hidden marker. Later runs update the same comment
instead of creating duplicates. The setting is ignored with a notice on
non-pull-request events.

GitHub normally gives fork pull requests a read-only token. Organizations that
need comments from fork PRs should use a maintainer-controlled follow-up
workflow. Do not execute untrusted fork code with `pull_request_target`.

## Scan only changed lines

Generate a unified diff before invoking the Action:

```yaml
- name: Build pull-request diff
  env:
    BASE_SHA: ${{ github.event.pull_request.base.sha }}
    HEAD_SHA: ${{ github.event.pull_request.head.sha }}
  run: |
    git diff --unified=0 "$BASE_SHA" "$HEAD_SHA" -- '*.mbt' \
      > "$RUNNER_TEMP/moonhermetic.diff"

- name: MoonHermetic changed lines
  uses: kobe108/moonhermetic@v0.11.0
  with:
    diff: ${{ runner.temp }}/moonhermetic.diff
    format: markdown
```

The Action resolves `path`, `config`, `diff`, and `output-file` relative to
`GITHUB_WORKSPACE` unless they are already absolute.

## Suppression governance

Audit ownership and expiry without failing:

```yaml
- name: Suppression audit
  uses: kobe108/moonhermetic@v0.11.0
  with:
    audit-suppressions: true
    output-file: moonhermetic-suppressions.json
```

Enable the CI gate:

```yaml
- name: Reject expired suppressions
  uses: kobe108/moonhermetic@v0.11.0
  with:
    fail-on-suppression: true
```

`fail-on-suppression` implies audit mode. It fails for expired or invalid
scoped directives, while legacy directives remain visible and non-fatal.

## Inputs

| Input | Default | Purpose |
|---|---|---|
| `path` | `.` | File or directory to scan |
| `format` | Automatic | `text`, `json`, `markdown`, or `sarif`; scans default to SARIF and audits to JSON |
| `fail-on` | `error` | Scan threshold: `never`, `warning`, or `error` |
| `config` | Auto-discover | Config path relative to the caller's workspace |
| `exclude` | Empty | Newline-separated path fragments to skip |
| `diff` | Empty | Unified diff path for changed-line filtering |
| `audit-suppressions` | `false` | Produce a suppression governance report |
| `fail-on-suppression` | `false` | Fail for expired or invalid scoped directives |
| `output-file` | Automatic | Report path relative to the workspace, or `-` for stdout |
| `summary` | `true` | Append compact Markdown to `GITHUB_STEP_SUMMARY` |
| `pr-comment` | `false` | Create or update one managed pull-request comment |

## Outputs and artifacts

The `report-path` output contains the absolute path of the generated report.
The `execution-mode` output is `binary` when a verified release executable was
used, or `source` when the MoonBit fallback was required. `summary-path`
contains the generated Markdown summary when summary or comment output is
enabled:

```yaml
- name: Upload report
  if: always()
  uses: actions/upload-artifact@v5
  with:
    name: moonhermetic-report
    path: ${{ steps.hermetic.outputs.report-path }}
```

When `output-file` is `-`, no file is created and `report-path` is empty.

## Verification

The `Reusable Action` workflow exercises the local action on Ubuntu, macOS, and
Windows. It verifies the report output and confirms that an expired scoped
suppression fails the governance gate as expected. Node tests also validate
input normalization before any command is executed.
