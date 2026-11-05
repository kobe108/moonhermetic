# Precision benchmark

MoonHermetic uses a pinned corpus of public MoonBit repositories as a
regression benchmark for its heuristic rules.

The benchmark answers two questions:

1. Does a rule change unexpectedly increase or reduce findings on real code?
2. Does the scanner stay stable across a representative mix of small utility
   libraries, large runtimes, async I/O, serialization, parsing, and UI code?

It is not an accuracy percentage. A finding means that a test directly exposes
an environment boundary. Projects such as `moonbitlang/async` intentionally
test clocks, sockets, processes, files, and sleep behavior, so those findings
are expected review signals rather than confirmed defects.

## Pinned corpus

The repositories and exact commits are recorded in
[`benchmarks/precision-corpus.json`](../benchmarks/precision-corpus.json).
Only `.mbt` files are extracted into a temporary work directory; third-party
repositories are not copied into this repository.

| Repository | Test files | Baseline findings |
|---|---:|---:|
| `moonbitlang/x` | 75 | 77 |
| `moonbitlang/async` | 169 | 1065 |
| `moonbit-community/serde.mbt` | 14 | 0 |
| `moonbit-community/moondiff` | 159 | 13 |
| `moonbit-community/prettyprinter` | 3 | 0 |
| `bobzhang/difflib.mbt` | 7 | 0 |
| `moonbit-community/cmark.mbt` | 52 | 0 |
| `moonbit-community/rabbita` | 43 | 23 |
| `moonbitlang/quickcheck` | 4 | 0 |
| `moonbit-community/json` | 5 | 0 |
| **Total** | **531** | **1178** |

## Running

Requirements: MoonBit, GitHub CLI, and `tar`.

```powershell
gh auth status
pwsh scripts/run-precision.ps1
```

The script downloads each pinned tarball, extracts only `.mbt` files, runs
MoonHermetic with `--no-config --fail-on never`, stores JSON reports under
`work/precision-benchmark/reports`, and compares every repository and rule
count with [`benchmarks/precision-baseline.json`](../benchmarks/precision-baseline.json).

Use `-WorkDir <path>` to choose a different scratch directory. Archives are
cached by repository ID and short commit.

After an intentional scanner change, review the report diff and update the
baseline:

```powershell
pwsh scripts/run-precision.ps1 -UpdateBaseline
```

The GitHub Actions workflow `Precision benchmark` exposes the same check as a
manual workflow so network-heavy corpus updates do not slow every push.

## Reviewed cases

[`benchmarks/reviewed-cases.json`](../benchmarks/reviewed-cases.json) contains
19 manually reviewed cases from the pinned snapshots:

- 14 positive cases that should produce a finding.
- 5 negative cases that previously produced clear false positives.

Each case records the repository, relative path, line, rule ID, expectation,
and review reason. The runner reports:

- Precision: true positives / (true positives + false positives).
- Recall: true positives / (true positives + false negatives).
- Specificity: true negatives / (true negatives + false positives).

The current reviewed sample scores 100% on all three measures. This is a
regression gate for reviewed examples, not an estimate of corpus-wide accuracy.
Larger conclusions require labeling a random or stratified sample of findings.

## Stratified sample

The sampler selects findings deterministically with SHA-256 over:

```text
seed | repository | path | line | rule ID
```

Generate a review queue after running the benchmark:

```powershell
pwsh scripts/sample-precision.ps1 `
  -WorkDir work/precision-benchmark `
  -PerRule 3 `
  -Output work/stratified-review-queue.json
```

The committed
[`benchmarks/stratified-sample.json`](../benchmarks/stratified-sample.json)
contains the reviewed first queue:

- Seed: `moonhermetic-precision-v1`
- Up to three findings per rule
- 20 reviewed findings
- 20 true positives, 0 false positives

The benchmark reports this sample separately as `STRATIFIED`. Precision and
recall are 100%; specificity is `n/a` because this queue samples only predicted
findings and contains no known negatives. Keeping reviewed and stratified
metrics separate prevents the directed negative cases from inflating the
sample score.

## Initial rule tuning

The first corpus run produced 1430 findings. Reviewing the most frequent
evidence clusters found clear false positives:

- `prefetch()` matched the generic `fetch(` pattern.
- async `group.spawn()` matched the generic child-process `spawn(` pattern.

The scanner now requires identifier boundaries before generic call patterns,
removes generic `spawn(`, and uses more specific random/file API names. This
removed 72 findings.

A second pass narrowed `@socket.` and `@process.` namespace matches to actual
connect, server, resolve, run, and spawn operations. Address parsing, explicit
unimplemented probes, and pure pipe helpers no longer count as live operations.
This removed another 125 findings.

A third pass replaced broad HTTP and filesystem namespaces with explicit
operation names. Type references such as `@http.Request` and `@fs.File`, plus
`@fs.unimplemented`, no longer become findings. Environment variable writes and
removals were added as real process-environment dependencies. The net result
is 1178 findings, 252 fewer than the first run.

## Limitations

- Baseline counts verify stability, not ground-truth correctness.
- Intentionally non-hermetic tests count as valid boundary findings.
- Extraction currently scans MoonBit source files only; module resolution is
  not part of the benchmark.
- The corpus should grow to include community libraries, CLI tools, and
  applications rather than only infrastructure repositories.
