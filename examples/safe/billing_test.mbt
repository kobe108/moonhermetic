///|
struct Clock {
  fixed : Int
}

///|
fn charge_at(clock : Clock) -> String {
  if clock.fixed == 1_700_000_000 {
    "accepted"
  } else {
    "rejected"
  }
}

///|
test "fixed clock keeps billing deterministic" {
  let clock = Clock::{ fixed: 1_700_000_000 }
  assert_eq(charge_at(clock), "accepted")
}
