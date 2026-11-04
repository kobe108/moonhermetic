///|
test "validates ISO dates including leap years" {
  assert_true(valid_iso_date("2026-11-05"))
  assert_true(valid_iso_date("2028-02-29"))
  assert_true(!valid_iso_date("2027-02-29"))
  assert_true(!valid_iso_date("2026-13-01"))
  assert_true(!valid_iso_date("2026-1-01"))
  assert_true(!valid_iso_date("abcd-ef-gh"))
}

///|
test "ignores directives that only appear in strings" {
  let raw = "let value = \"// hermetic:ignore HERM-NET\""
  assert_true(line_comment(raw) is None)
}
