///|
test "detects core implicit dependencies" {
  let source =
    #|test "risky" {
    #|  let now = @env.now()
    #|  let port = @env.get_env_var("PORT")
    #|  let response = fetch("https://example.com")
    #|  @fs.write_file("out.txt", "x")
    #|  sleep(10)
    #|}
  let findings = @moonhermetic.scan_source("demo_test.mbt", source)
  assert_eq(findings.length(), 5)
  assert_true(findings[0].rule == @moonhermetic.Clock)
  assert_true(findings[1].rule == @moonhermetic.Environment)
  assert_true(findings[2].rule == @moonhermetic.Network)
  assert_true(findings[3].rule == @moonhermetic.Filesystem)
  assert_true(findings[4].rule == @moonhermetic.Sleep)
}

///|
test "ignores comments literals and snapshot content" {
  let source =
    #|test "safe" {
    #|  // sleep(100) and @env.now() are documentation
    #|  let message = "fetch( and @fs.read_file"
    #|  inspect(message, content=(#|@env.get_env_var("TOKEN")
    #|  ))
    #|}
  assert_eq(@moonhermetic.scan_source("demo_test.mbt", source).length(), 0)
}

///|
test "supports line and next-line suppression" {
  let source =
    #|test "suppressed" {
    #|  sleep(1) // hermetic:ignore
    #|  // hermetic:ignore-next
    #|  @env.get_env_var("CI")
    #|  random_byte()
    #|}
  let findings = @moonhermetic.scan_source("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_true(findings[0].rule == @moonhermetic.Random)
  assert_eq(findings[0].line, 5)
}

///|
test "reports precise locations" {
  let findings = @moonhermetic.scan_source("x_test.mbt", "test { sleep(1) }")
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].line, 1)
  assert_eq(findings[0].column, 8)
  assert_true(findings[0].severity == @moonhermetic.Error)
}

///|
test "does not report function declarations" {
  let source =
    #|fn fetch(_url : String) -> String { "ok" }
    #|test "calls helper" {
    #|  let _ = fetch("https://example.test")
    #|}
  let findings = @moonhermetic.scan_source("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].line, 3)
}

///|
test "scans an inline function body without reporting its declaration" {
  let source =
    #|fn helper() { sleep(1) }
  let findings = @moonhermetic.scan_source("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_true(findings[0].rule == @moonhermetic.Sleep)
  assert_eq(findings[0].column, 15)
}

///|
test "does not confuse parameter literals with the function body" {
  let source =
    #|fn helper(options = { "retry": 1 }) { sleep(1) }
  let findings = @moonhermetic.scan_source("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_true(findings[0].rule == @moonhermetic.Sleep)
}

///|
test "requires identifier boundaries for generic call patterns" {
  let source =
    #|test "boundaries" {
    #|  client.stop_prefetch()
    #|  group.spawn(() => ())
    #|  fetch("https://example.test")
    #|}
  let findings = @moonhermetic.scan_source("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_true(findings[0].rule == @moonhermetic.Network)
  assert_eq(findings[0].line, 4)
}

///|
test "does not treat address parsing or unimplemented probes as effects" {
  let source =
    #|test "helpers" {
    #|  ignore(@socket.Addr::parse("127.0.0.1:80"))
    #|  ignore(@process.unimplemented)
    #|}
  assert_eq(@moonhermetic.scan_source("demo_test.mbt", source).length(), 0)
}

///|
test "applies per-rule severity and disable overrides" {
  let source =
    #|test "configured" {
    #|  let now = @env.now()
    #|  let response = fetch("https://example.test")
    #|  random_byte()
    #|}
  let options : @moonhermetic.ScanOptions = {
    overrides: [
      { rule: @moonhermetic.Network, severity: None, },
      { rule: @moonhermetic.Clock, severity: Some(@moonhermetic.Warning), },
      { rule: @moonhermetic.Random, severity: Some(@moonhermetic.Error), },
    ],
  }
  let findings = @moonhermetic.scan_source_with_options(
    "demo_test.mbt", source, options,
  )
  assert_eq(findings.length(), 2)
  assert_true(findings[0].rule == @moonhermetic.Clock)
  assert_true(findings[0].severity == @moonhermetic.Warning)
  assert_true(findings[1].rule == @moonhermetic.Random)
  assert_true(findings[1].severity == @moonhermetic.Error)
}

///|
test "parses every public rule ID and rejects unknown IDs" {
  for rule in @moonhermetic.rule_catalog() {
    guard @moonhermetic.RuleKind::from_code(rule.code()) is Some(parsed) else {
      fail("known rule ID did not parse")
    }
    assert_true(parsed == rule)
  }
  assert_true(@moonhermetic.RuleKind::from_code("herm-http") is None)
}

///|
test "rule-specific suppression hides only named rules" {
  let source =
    #|test "scoped" {
    #|  let response = fetch("https://example.test"); sleep(1) // hermetic:ignore HERM-NET owner=kobe108 expires=2027-01-31 reason=fixture
    #|}
  let findings = @moonhermetic.scan_source_with_options_and_date(
    "demo_test.mbt",
    source,
    @moonhermetic.default_scan_options(),
    "2026-11-05",
  )
  assert_eq(findings.length(), 1)
  assert_true(findings[0].rule == @moonhermetic.Sleep)
}

///|
test "expired or incomplete scoped suppressions fail open" {
  let expired =
    #|test "expired" {
    #|  fetch("https://example.test") // hermetic:ignore HERM-NET owner=kobe108 expires=2026-11-04
    #|}
  let expired_findings = @moonhermetic.scan_source_with_options_and_date(
    "expired_test.mbt",
    expired,
    @moonhermetic.default_scan_options(),
    "2026-11-05",
  )
  assert_eq(expired_findings.length(), 1)
  let incomplete =
    #|test "incomplete" {
    #|  fetch("https://example.test") // hermetic:ignore HERM-NET owner=kobe108
    #|}
  let incomplete_findings = @moonhermetic.scan_source_with_options_and_date(
    "incomplete_test.mbt",
    incomplete,
    @moonhermetic.default_scan_options(),
    "2026-11-05",
  )
  assert_eq(incomplete_findings.length(), 1)
}

///|
test "scoped next-line suppression supports comma-separated rules" {
  let source =
    #|test "next" {
    #|  // hermetic:ignore-next HERM-NET,HERM-SLEEP owner=kobe108 expires=2026-11-05 reason=fixture
    #|  let response = fetch("https://example.test"); sleep(1)
    #|}
  let findings = @moonhermetic.scan_source_with_options_and_date(
    "demo_test.mbt",
    source,
    @moonhermetic.default_scan_options(),
    "2026-11-05",
  )
  assert_eq(findings.length(), 0)
}

///|
test "scoped suppression requires a reference date when using the base API" {
  let source =
    #|test "undated" {
    #|  fetch("https://example.test") // hermetic:ignore HERM-NET owner=kobe108 expires=2099-01-01
    #|}
  let findings = @moonhermetic.scan_source("undated_test.mbt", source)
  assert_eq(findings.length(), 1)
}
