# Changelog

## 0.10.0

- Add a Mooncakes publication workflow with a token-free package preflight.
- Validate package archives without requiring an external ZIP or tar command.
- Reject incomplete packages, path traversal, build directories, and secret
  filenames before publication.
- Publish the validated Mooncakes ZIP and its SHA-256 checksum as release
  assets.
- Require an isolated `kobe108` Mooncakes identity and reject credentials from
  other usernames.
- Expand Mooncakes discovery metadata.

## 0.9.0

- Build and publish native MoonHermetic executables for Linux, macOS, and
  Windows.
- Publish a SHA-256 checksum beside every release binary.
- Make release-tagged GitHub Actions download and verify the matching binary
  instead of installing the full MoonBit toolchain.
- Keep a source-build fallback for branch refs, local action checkouts, and
  runners without a matching binary.
- Add deterministic release packaging and platform/checksum unit tests.

## 0.8.0

- Add a reusable composite GitHub Action that installs MoonBit and runs the
  scanner from the caller's repository.
- Support scan, diff, SARIF, configuration, exclusion, and suppression audit
  inputs without shell interpolation.
- Output a stable `report-path` for artifact and code-scanning upload steps.
- Add Node unit tests for action input planning and validation.
- Add Linux, macOS, and Windows Action smoke coverage, including an expected
  governance-gate failure.

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
