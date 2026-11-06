# Incremental adoption with baselines

A baseline records findings that a project intentionally accepts for now. This
lets an existing repository adopt MoonHermetic without having to fix or
suppress every historical warning in one change.

## Create a baseline

```bash
moon run cmd/main -- . --write-baseline .moonhermetic-baseline.json
```

The command scans the full project, writes a deterministic JSON snapshot, and
exits successfully. Commit the file and review changes to it like any other
policy file.

## Apply a baseline

```bash
moon run cmd/main -- . \
  --baseline .moonhermetic-baseline.json \
  --fail-on warning
```

Only findings not represented by the baseline reach the severity threshold.
Text, JSON, Markdown, SARIF, GitHub summaries, and Action behavior use this
filtered result.

## Fingerprint semantics

Each finding identity is SHA-256 over:

1. Rule ID.
2. Repository-relative source path.
3. Whitespace-normalized evidence, with string literals preserved.

Line and column are not part of the identity, so moving a known finding does
not make it new. Spacing around operators and punctuation is normalized while
the contents of string literals remain significant.

Identical findings are grouped with a positive `count`. If a baseline records
one occurrence and the project later adds a second identical occurrence, one
finding remains new.

## Stale entries

If a recorded finding disappears, its remaining count is reported as stale.
Stale entries do not fail the scan, but they should be removed by regenerating
the baseline:

```bash
moon run cmd/main -- . --write-baseline .moonhermetic-baseline.json
```

Review and commit the resulting diff so accepting or removing risk remains an
explicit policy change.

## Schema

```json
{
  "schema": "moonhermetic/baseline-v1",
  "createdOn": "2026-11-07",
  "createdWith": "0.12.0",
  "findings": [
    {
      "fingerprint": "<64 lowercase or uppercase hex characters>",
      "ruleId": "HERM-NET",
      "path": "src/checkout_test.mbt",
      "evidence": "fetch(endpoint)",
      "count": 1
    }
  ]
}
```

Unknown fields, unsupported schemas, invalid dates, unknown rules, duplicate
fingerprints, non-positive counts, and absolute or traversal paths are
rejected.

Baseline paths are resolved relative to the directory containing the baseline
file. This keeps fingerprints stable when the repository is checked out on a
different machine or drive.

## Interaction with diff mode

Baseline filtering is applied first, then the optional unified-diff filter.
Using both means: ignore known historical findings, and among the remainder,
only report risks introduced on changed lines.
