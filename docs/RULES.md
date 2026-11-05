# Rule semantics

MoonHermetic is a review aid. A match means "this test has a likely hidden
dependency", not "this test is wrong". A test can be intentionally
non-hermetic if the dependency is owned by a fixture and the exception is
documented.

Default severities can be changed in `.moonhermetic.json`. Setting a rule to
`off` removes its findings entirely; changing it to `warning` or `error`
changes only the reported severity.

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

Rule-specific suppressions must be attached to the code under review and
include an owner and UTC expiry date:

```moonbit
fetch("https://example.test") // hermetic:ignore HERM-NET owner=kobe108 expires=2026-12-31 reason=local_fixture
```

`ignore-next` uses the same syntax. Expiration is inclusive: the directive
remains active through the ISO date in `expires`. Expired, incomplete, or
malformed directives fail open, so the original finding is reported.

## Suppression governance

Run `--audit-suppressions` to review all directives without changing scanner
results. Governance states are:

| State | Meaning |
|---|---|
| `active` | More than 30 days remain before expiry. |
| `expiring-soon` | Between 0 and 30 days remain, including today. |
| `expired` | The expiry date was before the scan date. |
| `legacy` | A blanket directive without owner or expiry metadata. |
| `invalid` | A scoped directive has missing, unknown, or malformed fields. |

The audit ignores directive-like text inside strings, nested block comments,
and snapshot content. Use `--fail-on-suppression` in CI to reject expired or
invalid scoped directives. The gate does not change the fail-open behavior of
the ordinary scanner because the two modes serve different policies.
