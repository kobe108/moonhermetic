# Acceptance verification

This checklist maps the hackathon acceptance criteria to reproducible evidence.
It is intentionally narrower than "detects every flaky test": MoonHermetic
reports reviewable ambient boundaries, not confirmed defects.

Run the complete local contract with:

```powershell
pwsh scripts/verify-acceptance.ps1
```

The script checks all four MoonBit targets, cross-file and legacy behavior,
Node/Action tests, package contents, and the 70-line application.

## 1. Compiler and test contract

```bash
moon check --target all --deny-warn
moon test --target native --deny-warn
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
```

Expected result: zero warnings and a passing test summary for every target.

## 2. Cross-file semantic evidence

```bash
moon run cmd/main -- examples/semantic/cross_file \
  --no-config --format text --fail-on never
```

Expected result: one `HERM-ENV` finding in `request.mbt` with this call path:

```text
cross-file request reads an ambient token
  -> prepare_request
  -> read_ambient_token
```

The unused network helper in the same file must not be reported. A helper in a
different package directory must not be linked, even when its name matches.

## 3. Machine-readable output

```bash
moon run cmd/main -- examples/semantic/cross_file \
  --no-config --format json --fail-on never > cross-file.json
```

The finding must contain `path`, `line`, `column`, `ruleId`, `testName`, and a
three-element `callPath`. The SARIF and Markdown renderers carry the same trace
metadata.

## 4. Adoption workflow

```bash
tmp=$(mktemp -d)
cp examples/semantic/cross_file/*.mbt "$tmp"
moon run cmd/main -- init "$tmp" \
  --config "$tmp/moonhermetic.json" \
  --baseline "$tmp/baseline.json" --force
moon run cmd/main -- doctor "$tmp" \
  --config "$tmp/moonhermetic.json" \
  --baseline "$tmp/baseline.json"
```

The generated baseline must include the cross-file finding once. Re-running the
scanner with that baseline should suppress it and leave no new finding.

## 5. Reusable CI surface

The `Reusable Action` workflow runs the cross-file fixture through `action.yml`
and checks the parsed JSON call path. `CI` repeats the contract independently on
Linux, Windows, and macOS. Release smoke tests use the published version tag
instead of the working tree.

## 6. Packaging and identity

```bash
moon package --list
node scripts/validate-package.mjs --output dist
```

The package must include the cross-file fixture, semantic implementation, docs,
Action metadata, and no build or credential directories. Commit and tag identity
must remain `kobe108 <3360944005@qq.com>`.

## 7. Reviewed rule boundaries

```bash
node scripts/render-reviewed-cases.mjs
```

This verifies that the generated [reviewed case report](REVIEWED_CASES.md)
matches the pinned positive and negative decisions, including all reviewed
false-positive boundaries.

## Acceptance matrix

| Criterion | Evidence |
|---|---|
| MoonBit-specific semantics | Test-rooted package call graph and concrete call paths |
| Engineering depth | Parser masking, brace spans, cross-file resolution, cycle protection |
| Correctness | Four-target test suite plus package-boundary regressions |
| Practical adoption | Config, suppression governance, baselines, doctor, diff filtering |
| CI integration | Reusable Action, SARIF, managed summary, cross-file contract job |
| Explicit limits | Package-local `fn` calls only; no methods, dynamic dispatch, or macros |

Mooncakes upload still requires project-owner credentials and is not claimed by
automated checks. A deterministic 150-second captioned demo is included; if the
submission portal specifically requires a human voiceover, the included script
can be read over the same scenes.
