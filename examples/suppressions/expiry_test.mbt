///|
fn fetch(_url : String) -> String {
  "fixture"
}

///|
fn sleep(_milliseconds : Int) -> Unit {
  ()
}

///|
test "scoped and expiring suppressions" {
  let response = fetch("https://example.test") // hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-31 reason=local_fixture
  sleep(10) // hermetic:ignore HERM-SLEEP owner=kobe108 expires=2026-10-31 reason=legacy_retry_fixture
  assert_eq(response, "fixture")
}
