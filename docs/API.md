# Public API

The generated source of truth for exported names and signatures is
[`pkg.generated.mbti`](../pkg.generated.mbti). This page groups the stable
entry points by workflow; MoonHermetic remains pre-1.0, so additions may occur in
minor releases.

## Single-file scanning

- `scan_source(path, source)` applies the default rule policy.
- `scan_source_with_options(path, source, options)` applies rule overrides.
- `scan_source_with_options_and_date(...)` additionally evaluates expiring
  scoped suppressions.

These functions scan every source line. Use them for legacy integrations or
files that intentionally do not use test reachability.

## Test-reachability scanning

- `scan_source_semantically(path, source)` builds a one-file semantic graph.
- `scan_source_semantically_with_options_and_date(...)` adds policy and
  suppression dates.
- `scan_sources_semantically(sources)` accepts `(path, source)` pairs and
  resolves calls across `.mbt` files in the same package directory.
- `scan_sources_semantically_with_options_and_date(...)` is the CLI path for
  package-aware scans, rule overrides, and expiry evaluation.

Findings expose `test_name` and a `call_path` from the owning test to the effect.

## Reports

- `make_report`, `make_filtered_report`, and `make_baseline_report` construct an
  aggregate `ScanReport`.
- `render_text`, `render_json`, `render_markdown`, and `render_sarif` produce the
  supported output formats.
- `render_ci_summary` produces the compact GitHub job summary.
- `should_fail` and `count_by_severity` implement CI policy decisions.

## Baselines

- `finding_fingerprint` creates a stable SHA-256 fingerprint.
- `create_baseline`, `render_baseline_json`, and `parse_baseline` create and
  validate the baseline document.
- `filter_with_baseline` returns current, suppressed, and stale counts.

## Suppressions

- `audit_suppressions` reports active, expiring, expired, legacy, and invalid
  directives.
- `has_suppression_errors` supports the governance gate.
- Text, JSON, and Markdown audit renderers are exported for automation.

## Rules and types

`RuleKind` exposes stable IDs, titles, messages, remediation guidance, and
severity mapping. `Finding`, `ScanOptions`, `ScanReport`, `Baseline`, and
`SuppressionAudit` are public record types so integrations can consume results
without parsing terminal text.
