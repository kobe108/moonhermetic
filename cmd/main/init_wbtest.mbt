///|
test "init defaults to config and baseline in the current directory" {
  let options = parse_init_options(["moonhermetic", "init"])
  assert_eq(options.target, ".")
  assert_eq(options.config_path, ".moonhermetic.json")
  assert_eq(options.baseline_path, Some(".moonhermetic-baseline.json"))
  assert_true(!options.force)
}

///|
test "init accepts a target and destination overrides" {
  let options = parse_init_options([
    "moonhermetic", "init", "subproject", "--config", "config/moonhermetic.json",
    "--baseline", "config/baseline.json", "--force",
  ])
  assert_eq(options.target, "subproject")
  assert_eq(options.config_path, "config/moonhermetic.json")
  assert_eq(options.baseline_path, Some("config/baseline.json"))
  assert_true(options.force)
}

///|
test "init can skip baseline generation" {
  let options = parse_init_options(["moonhermetic", "init", "--no-baseline"])
  assert_eq(options.baseline_path, None)
}

///|
test "generated init config is valid and uses default policies" {
  let config = parse_config("init.json", init_config_json())
  assert_eq(config.fail_on, Some("error"))
  assert_eq(config.excludes.length(), 0)
  for rule in @lib.rule_catalog() {
    guard @lib.resolve_severity(rule, config.options) is Some(severity) else {
      fail("generated config must keep every rule enabled")
    }
    assert_true(severity == @lib.default_severity(rule))
  }
}

///|
test "baseline generation requires a repository-containing destination" {
  assert_true(
    baseline_scope_error(["examples/safe"], "examples/baseline.json") is None,
  )
  assert_true(baseline_scope_error(["."], "work/baseline.json") is Some(_))
}
