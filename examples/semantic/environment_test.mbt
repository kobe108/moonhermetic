///|
fn read_ambient_token() -> String {
  @env.get_env_var("TOKEN")
}

///|
fn prepare_request() -> String {
  read_ambient_token()
}

///|
fn unused_debug_helper() -> String {
  fetch("https://debug.example.test")
}

///|
test "request reads an ambient token" {
  ignore(prepare_request())
}
