///|
test "classifies active expiring expired and legacy suppressions" {
  let source =
    #|// hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-07 reason=active fixture
    #|// hermetic:ignore HERM-SLEEP owner=kobe108 expires=2026-12-06 reason=expiring fixture
    #|// hermetic:ignore-next HERM-ENV,HERM-CLOCK owner=kobe108 expires=2026-11-06
    #|// hermetic:ignore HERM-FS owner=kobe108 expires=2026-11-05
    #|// hermetic:ignore: documented legacy exception
  let audits = @moonhermetic.audit_suppressions(
    "governance_test.mbt", source, "2026-11-06",
  )
  assert_eq(audits.length(), 5)
  assert_true(audits[0].status == @moonhermetic.Active)
  assert_true(audits[1].status == @moonhermetic.ExpiringSoon)
  assert_true(audits[2].status == @moonhermetic.ExpiringSoon)
  assert_true(audits[3].status == @moonhermetic.Expired)
  assert_true(audits[4].status == @moonhermetic.Legacy)
  assert_eq(audits[0].line, 1)
  assert_eq(audits[0].column, 4)
  assert_eq(audits[2].directive, "hermetic:ignore-next")
  assert_eq(audits[2].rules.length(), 2)
}

///|
test "reports malformed scoped suppressions as invalid" {
  let source =
    #|// hermetic:ignore HERM-NET expires=2026-12-31
    #|// hermetic:ignore HERM-NET owner=kobe108
    #|// hermetic:ignore HERM-NOPE owner=kobe108 expires=2026-12-31
    #|// hermetic:ignore HERM-NET owner=kobe108 expires=2026-02-30
    #|// hermetic:ignore HERM-NET owner= expires=2026-12-31
  let audits = @moonhermetic.audit_suppressions(
    "invalid_test.mbt", source, "2026-11-06",
  )
  assert_eq(audits.length(), 5)
  for audit in audits {
    assert_true(audit.status == @moonhermetic.Invalid)
    assert_true(!audit.message.is_empty())
  }
  let report = @moonhermetic.make_suppression_audit_report(
    1, "2026-11-06", audits,
  )
  assert_true(@moonhermetic.has_suppression_errors(report))
}

///|
test "extracts owner expiry reason and comma separated rules" {
  let source =
    #|test "fixture" {
    #|  fetch("https://example.test") // hermetic:ignore HERM-NET, HERM-SLEEP owner=kobe108 expires=2026-12-31 reason=local fixture required
    #|}
  let audits = @moonhermetic.audit_suppressions(
    "demo_test.mbt", source, "2026-11-06",
  )
  assert_eq(audits.length(), 1)
  assert_eq(audits[0].owner, Some("kobe108"))
  assert_eq(audits[0].expires, Some("2026-12-31"))
  assert_eq(audits[0].reason, Some("local fixture required"))
  assert_eq(audits[0].rules.length(), 2)
  assert_eq(audits[0].rules[0], "HERM-NET")
  assert_eq(audits[0].rules[1], "HERM-SLEEP")
  assert_eq(audits[0].column, 36)
}

///|
test "audit ignores directives inside strings block comments and snapshots" {
  let source =
    #|let message = "// hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-31"
    #|/*
    #|  // hermetic:ignore HERM-SLEEP owner=kobe108 expires=2026-12-31
    #|*/
    #|let snapshot =
    #|  #|// hermetic:ignore HERM-ENV owner=kobe108 expires=2026-12-31
    #|// hermetic:ignore HERM-FS owner=kobe108 expires=2026-12-31
  let audits = @moonhermetic.audit_suppressions(
    "masked_test.mbt", source, "2026-11-06",
  )
  assert_eq(audits.length(), 1)
  assert_eq(audits[0].line, 7)
  assert_true(audits[0].rules[0] == "HERM-FS")
}

///|
test "audit JSON contains parsed summary and tool version" {
  let audits = @moonhermetic.audit_suppressions(
    "demo_test.mbt",
    (
      #|// hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-31 reason=fixture
      #|// hermetic:ignore: legacy
    ),
    "2026-11-06",
  )
  let json = @moonhermetic.render_suppression_audit_json(
    @moonhermetic.make_suppression_audit_report(3, "2026-11-06", audits),
  )
  let parsed = @json.parse(json)
  guard parsed is Json::Object(root) else {
    fail("audit root must be an object")
  }
  assert_eq(root["schema"], Json("moonhermetic/suppression-audit-v1"))
  guard root["tool"] is Json::Object(tool) else {
    fail("audit tool must be an object")
  }
  assert_eq(tool["version"], Json("0.14.0"))
  guard root["summary"] is Json::Object(summary) else {
    fail("audit summary must be an object")
  }
  assert_eq(summary["scannedFiles"], Json(3.0))
  assert_eq(summary["total"], Json(2.0))
  assert_eq(summary["active"], Json(1.0))
  assert_eq(summary["legacy"], Json(1.0))
  assert_eq(summary["expired"], Json(0.0))
}

///|
test "audit text exposes governance counts and directive metadata" {
  let audits = @moonhermetic.audit_suppressions(
    "demo_test.mbt",
    (
      #|// hermetic:ignore HERM-NET owner=kobe108 expires=2026-11-05 reason=expired fixture
    ),
    "2026-11-06",
  )
  let text = @moonhermetic.render_suppression_audit_text(
    @moonhermetic.make_suppression_audit_report(1, "2026-11-06", audits),
  )
  assert_true(text.contains("expired [HERM-NET]"))
  assert_true(text.contains("owner: kobe108"))
  assert_true(text.contains("expires: 2026-11-05"))
  assert_true(text.contains("reason: expired fixture"))
  assert_true(text.contains("1 expired, 0 legacy, 0 invalid"))
}

///|
test "active suppressions do not trigger the optional governance gate" {
  let audits = @moonhermetic.audit_suppressions(
    "demo_test.mbt",
    (
      #|// hermetic:ignore HERM-NET owner=kobe108 expires=2027-01-01
    ),
    "2026-11-06",
  )
  let report = @moonhermetic.make_suppression_audit_report(
    1, "2026-11-06", audits,
  )
  assert_true(!@moonhermetic.has_suppression_errors(report))
  assert_eq(
    @moonhermetic.count_suppression_status(report, @moonhermetic.Active),
    1,
  )
}

///|
test "audit accepts CRLF source files without changing directive metadata" {
  let source = "// hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-31 reason=crlf\r\n"
  let audits = @moonhermetic.audit_suppressions(
    "windows_test.mbt", source, "2026-11-06",
  )
  assert_eq(audits.length(), 1)
  assert_true(audits[0].status == @moonhermetic.Active)
  assert_eq(audits[0].reason, Some("crlf"))
}

///|
test "audit Markdown summary includes governance counts and ownership" {
  let audits = @moonhermetic.audit_suppressions(
    "demo_test.mbt",
    (
      #|// hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-31 reason=fixture
    ),
    "2026-11-06",
  )
  let summary = @moonhermetic.render_suppression_audit_markdown(
    @moonhermetic.make_suppression_audit_report(1, "2026-11-06", audits),
  )
  assert_true(summary.contains("# MoonHermetic suppression audit"))
  assert_true(summary.contains("| 1 | 0 | 0 | 0 | 0 |"))
  assert_true(summary.contains("kobe108"))
  assert_true(summary.contains("fixture"))
}
