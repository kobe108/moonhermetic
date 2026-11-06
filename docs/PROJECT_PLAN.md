# MoonHermetic project plan

## Product statement

Help MoonBit maintainers find hidden machine dependencies in tests before a
cross-platform CI run becomes nondeterministic.

The first release targets one job: produce a precise, explainable list of
likely hermeticity violations and integrate that list into CI through stable
JSON and SARIF formats.

## Why it is not a duplicate

The project was selected after querying Mooncakes for `hermetic`,
`test-pollution`, `nondeterminism-lint`, `flaky-test`, `csp`, `sbom`, `api`,
and related terms.

- API compatibility tools compare package interfaces.
- `mizchi/flaker` analyzes flake computation and affected-test behavior.
- Mutation-testing tools assess test strength.
- Supply-chain tools inspect dependencies and artifacts.

MoonHermetic focuses on ambient effect boundaries inside test source. Its
output is a source location and a boundary-injection remediation, not a
history-based flake score.

## One-month delivery plan

### Week 1: trustworthy scanner

- [x] Comment, string, character, block-comment, and snapshot masking.
- [x] Seven high-signal rule categories.
- [x] Precise line and column reporting.
- [x] Same-line and next-line suppression.
- [x] Unit tests for masking, locations, and suppression.

### Week 2: automation surfaces

- [x] Text, JSON, Markdown, and SARIF renderers.
- [x] CI exit thresholds.
- [x] Recursive `_test.mbt` and `_wbtest.mbt` discovery.
- [x] Example vulnerable and safe files.
- [x] Add configurable rule severity and project exclusions.
- [x] Add rule-specific suppressions with owner and expiry metadata.
- [x] Add governance audits and an optional expired-suppression CI gate.
- [x] Add GitHub job summaries and managed pull-request comments.
- [x] Add stable finding baselines for incremental project adoption.

### Week 3: ecosystem validation

- [x] Add diff-aware filtering for pull requests.
- [x] Run against at least ten public MoonBit repositories.
- [ ] Review every false positive and document the boundary.
- [x] Add reviewed positive and negative cases from public projects.
- [x] Add deterministic stratified sampling and a reviewed precision sample.
- [x] Establish a pinned regression baseline across the initial corpus.

### Week 4: release quality

- [x] Add release binaries for Windows, Linux, and macOS.
- [x] Publish a reusable GitHub Action.
- [x] Add Mooncakes package validation and a guarded publication workflow.
- [ ] Publish the library to Mooncakes.
- [ ] Complete API docs, changelog, and demo recording.

## Acceptance criteria

- `moon check` and `moon test` pass with zero warnings.
- The CLI returns 0 for clean input and the configured non-zero code for a
  matching finding.
- Every output format parses or renders according to its specification.
- Ignore directives do not hide unrelated lines.
- Governance reports distinguish active, expiring, expired, legacy, and
  invalid directives.
- Documentation does not claim complete detection; rules are explicitly
  heuristic and review-oriented.

## Release identity

Git author for this repository:

```text
kobe108 <3360944005@qq.com>
```
