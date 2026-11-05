# Changelog

## 0.5.0

- Add a pinned ten-repository precision benchmark and baseline.
- Add a repeatable snapshot runner and manual benchmark workflow.
- Add identifier boundaries for generic call patterns.
- Remove async `spawn()` and `prefetch()` false-positive matches.
- Tighten random, filesystem, socket, and process API patterns.

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
