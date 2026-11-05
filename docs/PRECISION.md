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
| `moonbitlang/x` | 75 | 84 |
| `moonbitlang/async` | 169 | 1106 |
| `moonbit-community/serde.mbt` | 14 | 0 |
| `moonbit-community/moondiff` | 159 | 16 |
| `moonbit-community/prettyprinter` | 3 | 0 |
| `bobzhang/difflib.mbt` | 7 | 0 |
| `moonbit-community/cmark.mbt` | 52 | 0 |
| `moonbit-community/rabbita` | 43 | 27 |
| `moonbitlang/quickcheck` | 4 | 0 |
| `moonbit-community/json` | 5 | 0 |
| **Total** | **531** | **1233** |

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
This removed another 125 findings, leaving the current baseline of 1233.

## Limitations

- Baseline counts verify stability, not ground-truth correctness.
- Intentionally non-hermetic tests count as valid boundary findings.
- Extraction currently scans MoonBit source files only; module resolution is
  not part of the benchmark.
- The corpus should grow to include community libraries, CLI tools, and
  applications rather than only infrastructure repositories.
