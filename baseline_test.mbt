///|
fn baseline_finding(
  line : Int,
  rule : @moonhermetic.RuleKind,
  evidence : String,
) -> @moonhermetic.Finding {
  {
    path: "src/demo_test.mbt",
    line,
    column: 5,
    rule,
    severity: @moonhermetic.default_severity(rule),
    evidence,
  }
}

///|
test "baseline fingerprints ignore line movement and spacing" {
  let first = baseline_finding(3, @moonhermetic.Network, "fetch(  \"fixture\")")
  let moved = baseline_finding(
    90,
    @moonhermetic.Network,
    " fetch(\"fixture\") ",
  )
  let changed = baseline_finding(3, @moonhermetic.Network, "fetch(\"other\")")
  let first_fingerprint = @moonhermetic.finding_fingerprint(".", first)
  assert_eq(first_fingerprint, @moonhermetic.finding_fingerprint(".", moved))
  assert_true(
    first_fingerprint != @moonhermetic.finding_fingerprint(".", changed),
  )
  assert_eq(first_fingerprint.char_length(), 64)
}

///|
test "baseline groups duplicate fingerprints and round-trips JSON" {
  let findings = [
    baseline_finding(3, @moonhermetic.Network, "fetch(\"fixture\")"),
    baseline_finding(9, @moonhermetic.Network, "fetch(\"fixture\")"),
  ]
  let baseline = @moonhermetic.create_baseline(
    findings, ".", "2026-11-07", "0.13.0",
  )
  assert_eq(baseline.entries.length(), 1)
  assert_eq(baseline.entries[0].count, 2)
  let parsed = @moonhermetic.parse_baseline(
    @moonhermetic.render_baseline_json(baseline),
  )
  assert_eq(parsed.entries.length(), 1)
  assert_eq(parsed.entries[0].count, 2)
  assert_eq(parsed.entries[0].path, "src/demo_test.mbt")
}

///|
test "baseline filters accepted findings and exposes stale entries" {
  let known = baseline_finding(3, @moonhermetic.Network, "fetch(\"fixture\")")
  let baseline = @moonhermetic.create_baseline(
    [known],
    ".",
    "2026-11-07",
    "0.13.0",
  )
  let moved = baseline_finding(77, @moonhermetic.Network, "fetch(\"fixture\")")
  let new_finding = baseline_finding(80, @moonhermetic.Sleep, "sleep(10)")
  let filtered = @moonhermetic.filter_with_baseline(
    [moved, new_finding],
    baseline,
    ".",
  )
  assert_eq(filtered.suppressed_count, 1)
  assert_eq(filtered.stale_count, 0)
  assert_eq(filtered.findings.length(), 1)
  assert_true(filtered.findings[0].rule == @moonhermetic.Sleep)

  let stale = @moonhermetic.filter_with_baseline([new_finding], baseline, ".")
  assert_eq(stale.suppressed_count, 0)
  assert_eq(stale.stale_count, 1)
}

///|
test "baseline count preserves a new duplicate occurrence" {
  let known = baseline_finding(3, @moonhermetic.Network, "fetch(\"fixture\")")
  let baseline = @moonhermetic.create_baseline(
    [known],
    ".",
    "2026-11-07",
    "0.13.0",
  )
  let result = @moonhermetic.filter_with_baseline(
    [known, baseline_finding(8, @moonhermetic.Network, "fetch(\"fixture\")")],
    baseline,
    ".",
  )
  assert_eq(result.suppressed_count, 1)
  assert_eq(result.findings.length(), 1)
}

///|
test "baseline parser rejects unknown fields and unsafe paths" {
  let unknown =
    #|{
    #|  "schema": "moonhermetic/baseline-v1",
    #|  "createdOn": "2026-11-07",
    #|  "createdWith": "0.13.0",
    #|  "findings": [],
    #|  "extra": true
    #|}
  let unknown_failed = try {
    ignore(@moonhermetic.parse_baseline(unknown))
    false
  } catch {
    BaselineError(_) => true
  }
  assert_true(unknown_failed)

  let traversal_baseline =
    #|{
    #|  "schema": "moonhermetic/baseline-v1",
    #|  "createdOn": "2026-11-07",
    #|  "createdWith": "0.13.0",
    #|  "findings": [{
    #|    "fingerprint": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    #|    "ruleId": "HERM-NET",
    #|    "path": "../secret_test.mbt",
    #|    "evidence": "fetch",
    #|    "count": 1
    #|  }]
    #|}
  let unsafe_failed = try {
    ignore(@moonhermetic.parse_baseline(traversal_baseline))
    false
  } catch {
    BaselineError(_) => true
  }
  assert_true(unsafe_failed)
}

///|
test "baseline counts appear in reports and CI summaries" {
  let report = @moonhermetic.make_baseline_report(
    2,
    [baseline_finding(8, @moonhermetic.Sleep, "sleep(1)")],
    0,
    4,
    2,
    ".moonhermetic-baseline.json",
  )
  let text = @moonhermetic.render_text(report)
  let json = @moonhermetic.render_json(report)
  let summary = @moonhermetic.render_ci_summary(report)
  assert_true(text.contains("Baseline accepted 4 existing finding(s)."))
  assert_true(json.contains("\"baselineSuppressed\": 4"))
  assert_true(json.contains("\"baselineStale\": 2"))
  assert_true(summary.contains("4 existing finding(s)"))
  assert_true(summary.contains("2 stale baseline count(s)"))
}
