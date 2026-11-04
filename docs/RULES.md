# Rule semantics

MoonHermetic is a review aid. A match means "this test has a likely hidden
dependency", not "this test is wrong". A test can be intentionally
non-hermetic if the dependency is owned by a fixture and the exception is
documented.

## HERM-CLOCK

Matches current wall-clock or local-time reads. A fixed timestamp lets the test
verify date logic without depending on the day the test runs.

## HERM-RAND

Matches common random API shapes. Injecting a seeded generator makes failures
reproducible; the seed should be visible in the assertion or failure message.

## HERM-ENV

Matches ambient environment reads. Tests should receive configuration
explicitly. A fixture that sets and restores environment variables is an
accepted exception.

## HERM-NET

Matches live HTTP, socket, and DNS shapes. Prefer a transport trait, fake
response, or a local fixture whose lifecycle the test owns.

## HERM-PROC

Matches subprocess and shell execution shapes. The binary version and PATH can
differ between developer machines and CI.

## HERM-FS

Matches external file reads and writes. A temporary directory created by the
test and removed with `defer` is acceptable. The rule stays warning-level
because filesystem fixtures are common and can be hermetic.

## HERM-SLEEP

Matches sleep and elapsed-time waits. Prefer waiting on a condition, virtual
time, or an explicit event from the system under test.

## Suppression

```moonbit
sleep(5) // hermetic:ignore: remote fixture guarantees startup after 5ms
```

```moonbit
// hermetic:ignore-next: intentional locale regression test
let language = @env.get_env_var("LANG")
```

Suppressions must be attached to the code under review. A future release will
add expiration and owner fields.
