///|
fn current_time() -> Int {
  0
}

///|
fn fetch(_url : String) -> String {
  "response"
}

///|
fn sleep(_milliseconds : Int) -> Unit {
  ()
}

///|
test "risky checkout" {
  let started = current_time()
  let endpoint = "https://example.test/checkout"
  let response = fetch(endpoint)
  sleep(20)
  assert_true(response.length() > started)
}
