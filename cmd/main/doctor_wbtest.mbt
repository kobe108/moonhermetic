///|
test "doctor options default to text and non-strict mode" {
  let options = parse_doctor_options(["moonhermetic", "doctor"])
  assert_eq(options.target, ".")
  assert_eq(options.config_path, None)
  assert_true(!options.config_disabled)
  assert_eq(options.baseline_path, None)
  assert_true(!options.baseline_disabled)
  assert_eq(options.format, "text")
  assert_true(!options.strict)
}

///|
test "doctor accepts json strict and disabled integrations" {
  let options = parse_doctor_options([
    "moonhermetic", "doctor", "src", "--no-config", "--no-baseline", "--format",
    "json", "--strict",
  ])
  assert_eq(options.target, "src")
  assert_true(options.config_disabled)
  assert_true(options.baseline_disabled)
  assert_eq(options.format, "json")
  assert_true(options.strict)
}

///|
test "doctor reports counts and strict failure policy" {
  let checks : Array[DoctorCheck] = [
    doctor_check("one", Pass, "ok", None),
    doctor_check("two", Warn, "warning", Some("fix it")),
    doctor_check("three", Error, "failed", None),
  ]
  let report = { strict: false, checks, }
  assert_eq(doctor_status_count(report, Pass), 1)
  assert_eq(doctor_status_count(report, Warn), 1)
  assert_eq(doctor_status_count(report, Error), 1)
  assert_true(doctor_should_fail(report))

  let warnings_only = {
    strict: true,
    checks: [doctor_check("warning", Warn, "warning", None)],
  }
  assert_true(doctor_should_fail(warnings_only))
  let relaxed = { ..warnings_only, strict: false, }
  assert_true(!doctor_should_fail(relaxed))
}

///|
test "doctor renders text and valid JSON reports" {
  let report = {
    strict: false,
    checks: [
      doctor_check("config", Pass, "Configuration is valid.", None),
      doctor_check("baseline", Warn, "Baseline is stale.", Some("Refresh it.")),
    ],
  }
  let text = render_doctor_text(report)
  let json_text = render_doctor_json(report)
  assert_true(text.contains("PASS: config"))
  assert_true(text.contains("next: Refresh it."))
  assert_true(text.contains("1 passed, 1 warning(s), 0 error(s)"))
  let parsed = @json.parse(json_text)
  guard parsed is Json::Object(root) else {
    fail("doctor JSON root must be an object")
  }
  assert_eq(root["schema"], Json("moonhermetic/doctor-v1"))
  guard root["summary"] is Json::Object(summary) else {
    fail("doctor summary must be an object")
  }
  assert_eq(summary["warnings"], Json(1.0))
}

///|
test "doctor missing explicit baseline becomes an error check" {
  let checks : Array[DoctorCheck] = []
  doctor_check_baseline(".doctor-baseline-does-not-exist.json", [], checks)
  assert_eq(checks.length(), 1)
  assert_true(checks[0].status == Error)
}
