///|
fn sample_finding(rule : @moonhermetic.RuleKind) -> @moonhermetic.Finding {
  {
    path: "demo_test.mbt",
    line: 3,
    column: 5,
    rule,
    severity: @moonhermetic.default_severity(rule),
    evidence: "sleep(1)",
  }
}

///|
test "text report includes counts and remediation" {
  let report = @moonhermetic.make_report(2, [
    sample_finding(@moonhermetic.Sleep),
    sample_finding(@moonhermetic.Clock),
  ])
  let text = @moonhermetic.render_text(report)
  assert_true(text.contains("HERM-SLEEP"))
  assert_true(text.contains("1 error(s), 1 warning(s)"))
  assert_true(text.contains("fix:"))
}

///|
test "json report is valid and structured" {
  let report = @moonhermetic.make_report(1, [
    sample_finding(@moonhermetic.Environment),
  ])
  let json = @json.parse(@moonhermetic.render_json(report))
  guard json is Object(root) else { fail("root must be an object") }
  assert_eq(root["schema"], Json("moonhermetic/v1"))
  guard root["findings"] is Array(findings) else {
    fail("findings must be an array")
  }
  assert_eq(findings.length(), 1)
}

///|
test "markdown report escapes table separators" {
  let finding : @moonhermetic.Finding = {
    ..sample_finding(@moonhermetic.Network),
    evidence: "fetch(\"a|b\")",
  }
  let markdown = @moonhermetic.render_markdown(
    @moonhermetic.make_report(1, [finding]),
  )
  assert_true(markdown.contains("a\\|b"))
  assert_true(markdown.contains("HERM-NET"))
}

///|
test "markdown report escapes backticks and backslashes" {
  let finding : @moonhermetic.Finding = {
    ..sample_finding(@moonhermetic.Environment),
    evidence: "value=`ci\\\\token`",
  }
  let markdown = @moonhermetic.render_markdown(
    @moonhermetic.make_report(1, [finding]),
  )
  assert_true(markdown.contains("value=\\`ci\\\\\\\\token\\`"))
}

///|
test "sarif report contains rule and source location" {
  let sarif = @moonhermetic.render_sarif(
    @moonhermetic.make_report(1, [sample_finding(@moonhermetic.Process)]),
  )
  let json = @json.parse(sarif)
  assert_true(sarif.contains("\"version\": \"2.1.0\""))
  assert_true(sarif.contains("HERM-PROC"))
  assert_true(sarif.contains("\"startLine\": 3"))
  guard json is Object(_) else { fail("SARIF root must be an object") }
}

///|
test "filtered report exposes the omitted finding count" {
  let report = @moonhermetic.make_filtered_report(
    1,
    [sample_finding(@moonhermetic.Network)],
    2,
  )
  let text = @moonhermetic.render_text(report)
  let markdown = @moonhermetic.render_markdown(report)
  let json = @moonhermetic.render_json(report)
  assert_true(text.contains("ignored 2 finding(s)"))
  assert_true(markdown.contains("2 finding(s) outside changed lines"))
  assert_true(json.contains("\"filteredOut\": 2"))
}
