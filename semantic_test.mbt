///|
test "semantic scan attaches direct effects to their test" {
  let source =
    #|test "network case" {
    #|  fetch("https://example.test")
    #|}
  let findings = @moonhermetic.scan_source_semantically("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].test_name, Some("network case"))
  assert_eq(findings[0].call_path.length(), 1)
  assert_eq(findings[0].call_path[0], "network case")
}

///|
test "semantic scan traces helper call chains" {
  let source =
    #|fn read_token() -> String {
    #|  @env.get_env_var("TOKEN")
    #|}
    #|
    #|fn prepare_request() -> String {
    #|  read_token()
    #|}
    #|
    #|test "request uses environment" {
    #|  ignore(prepare_request())
    #|}
  let findings = @moonhermetic.scan_source_semantically("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].line, 2)
  assert_eq(findings[0].test_name, Some("request uses environment"))
  assert_eq(findings[0].call_path.length(), 3)
  assert_eq(findings[0].call_path[0], "request uses environment")
  assert_eq(findings[0].call_path[1], "prepare_request")
  assert_eq(findings[0].call_path[2], "read_token")
}

///|
test "semantic scan ignores functions unreachable from tests" {
  let source =
    #|fn unused_debug_helper() {
    #|  sleep(100)
    #|}
    #|
    #|test "safe" {
    #|  assert_eq(1, 1)
    #|}
  assert_eq(
    @moonhermetic.scan_source_semantically("demo_test.mbt", source).length(),
    0,
  )
  assert_eq(@moonhermetic.scan_source("demo_test.mbt", source).length(), 1)
}

///|
test "semantic scan reports one trace per calling test" {
  let source =
    #|fn load_fixture() -> String {
    #|  @fs.read_file_to_string("fixture.txt")
    #|}
    #|
    #|test "first" {
    #|  ignore(load_fixture())
    #|}
    #|
    #|test "second" {
    #|  ignore(load_fixture())
    #|}
  let findings = @moonhermetic.scan_source_semantically("demo_test.mbt", source)
  assert_eq(findings.length(), 2)
  assert_eq(findings[0].test_name, Some("first"))
  assert_eq(findings[1].test_name, Some("second"))
  assert_eq(findings[0].line, 2)
  assert_eq(findings[1].line, 2)
}

///|
test "semantic call graph terminates recursive call cycles" {
  let source =
    #|fn first() -> Unit {
    #|  second()
    #|}
    #|
    #|fn second() -> Unit {
    #|  first()
    #|  @env.get_env_var("TOKEN")
    #|}
    #|
    #|test "recursive helpers" {
    #|  first()
    #|}
  let findings = @moonhermetic.scan_source_semantically("demo_test.mbt", source)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].line, 7)
  assert_eq(findings[0].call_path.length(), 3)
  assert_eq(findings[0].call_path[1], "first")
  assert_eq(findings[0].call_path[2], "second")
}

///|
test "semantic call graph ignores calls in strings and comments" {
  let source =
    #|fn unused_helper() {
    #|  sleep(1)
    #|}
    #|
    #|test "documented" {
    #|  let message = "unused_helper()"
    #|  // unused_helper()
    #|}
  assert_eq(
    @moonhermetic.scan_source_semantically("demo_test.mbt", source).length(),
    0,
  )
}

///|
test "semantic scanning preserves scoped suppression behavior" {
  let source =
    #|fn load_fixture() -> String {
    #|  @fs.read_file_to_string("fixture.txt") // hermetic:ignore HERM-FS owner=kobe108 expires=2026-11-30 reason=fixture
    #|}
    #|
    #|test "fixture" {
    #|  ignore(load_fixture())
    #|}
  let findings = @moonhermetic.scan_source_semantically_with_options_and_date(
    "demo_test.mbt",
    source,
    @moonhermetic.default_scan_options(),
    "2026-11-07",
  )
  assert_eq(findings.length(), 0)
}
