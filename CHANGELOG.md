# Changelog

## 0.7.0

- Add a suppression governance audit for active, expiring, expired, legacy,
  and invalid directives.
- Add deterministic text and JSON audit reports with owner, expiry, reason,
  rule, and source location metadata.
- Add `--audit-suppressions` to inspect governance state without changing scan
  behavior.
- Add `--fail-on-suppression` for CI gates that reject expired or malformed
  scoped suppressions.
- Keep expired suppressions fail-open for findings unless the separate
  governance gate is enabled.
- Ignore directive-like text in strings, block comments, and snapshot content.

## 0.6.0

- Add deterministic SHA-256 stratified sampling across corpus rules.
- Add a 20-case stratified reviewed sample.
- Report reviewed and stratified precision/recall metrics separately.
- Keep specificity explicit as `n/a` when a sample contains no negatives.

## 0.5.0

- Add a pinned ten-repository precision benchmark and baseline.
- Add a repeatable snapshot runner and manual benchmark workflow.
- Add 19 manually reviewed positive and negative cases with precision metrics.
- Add identifier boundaries for generic call patterns.
- Remove async `spawn()` and `prefetch()` false-positive matches.
- Tighten random, HTTP, filesystem, socket, and process API patterns.
- Detect environment variable writes and removals.

## 0.4.0

- Add unified-diff parsing for pull-request incremental scans.
- Filter findings to added lines while reporting how many were filtered.
- Match absolute scanner paths against repository-relative diff paths.
- Add an end-to-end incremental scan example.

## 0.3.0

- Add rule-specific same-line and next-line suppression.
- Require owner and UTC expiry date for scoped suppressions.
- Let expired or malformed suppressions fail open so risks are reported.
- Expose a date-aware scanner API for deterministic policy evaluation.

## 0.2.0

- Add `.moonhermetic.json` configuration for rule severity and disabling.
- Add configurable exclusions and default fail threshold.
- Scan inline function bodies while excluding declaration names.
- Track visited directories and cap traversal depth during discovery.
- Escape backticks and backslashes in Markdown output.

## 0.1.0

- Initial static scanner for seven test hermeticity rules.
- Text, JSON, Markdown, and SARIF output.
- Inline suppression and CI thresholds.
- Cross-platform native CLI smoke coverage.
