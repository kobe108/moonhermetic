# Changelog

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
