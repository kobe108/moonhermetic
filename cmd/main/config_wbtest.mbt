///|
fn config_error_text(text : String) -> String {
  let result = try {
    ignore(parse_config("test.json", text))
    None
  } catch {
    ConfigError(message) => Some(message)
  }
  match result {
    Some(message) => message
    None => ""
  }
}

///|
test "parses fail threshold exclusions and rule policies" {
  let config = parse_config(
    "test.json",
    (
      #|{
      #|  "version": 1,
      #|  "failOn": "warning",
      #|  "exclude": ["generated", "legacy"],
      #|  "rules": {
      #|    "HERM-NET": "warning",
      #|    "HERM-FS": "off",
      #|    "HERM-SLEEP": "error"
      #|  }
      #|}
    ),
  )
  assert_true(config.fail_on is Some("warning"))
  assert_true(config.excludes.contains("generated"))
  assert_true(config.excludes.contains("legacy"))
  assert_true(
    @lib.resolve_severity(@lib.Network, config.options) is Some(@lib.Warning),
  )
  assert_true(@lib.resolve_severity(@lib.Filesystem, config.options) is None)
  assert_true(
    @lib.resolve_severity(@lib.Sleep, config.options) is Some(@lib.Error),
  )
  assert_true(
    @lib.resolve_severity(@lib.Clock, config.options) is Some(@lib.Warning),
  )
}

///|
test "rejects unknown top-level keys" {
  let message = config_error_text("{\"unknown\": true}")
  assert_true(message.contains("top-level"))
}

///|
test "rejects unknown rules and invalid policies" {
  assert_true(
    config_error_text("{\"rules\":{\"HERM-HTTP\":\"error\"}}").contains(
      "unknown rule ID",
    ),
  )
  assert_true(
    config_error_text("{\"rules\":{\"HERM-NET\":\"fatal\"}}").contains(
      "off, warning, or error",
    ),
  )
}

///|
test "rejects unsupported versions and duplicate rule casing" {
  assert_true(
    config_error_text("{\"version\":2}").contains("'version' must be 1"),
  )
  assert_true(
    config_error_text("{\"version\":1.5}").contains("'version' must be 1"),
  )
  assert_true(
    config_error_text(
      "{\"rules\":{\"HERM-NET\":\"off\",\"herm-net\":\"error\"}}",
    ).contains("more than once"),
  )
  assert_true(
    config_error_text("{\"failOn\":\"sometimes\"}").contains(
      "never, warning, or error",
    ),
  )
}

///|
test "disabled config bypasses file loading" {
  let config = load_project_config(Some("does-not-exist.json"), true) catch {
    ConfigError(message) => fail(message)
  }
  assert_true(config.fail_on is None)
  assert_eq(config.excludes.length(), 0)
  assert_eq(config.options.overrides.length(), 0)
}
