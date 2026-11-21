# MoonBit test semantics

MoonHermetic still recognizes ambient effects through MoonBit API signatures,
but API matching is only the leaf operation. The scanner now constructs a
MoonBit-specific semantic layer before reporting a boundary.

## Analysis pipeline

1. Mask comments, strings, characters, nested block comments, and snapshots.
2. Discover every `.mbt` source file and group files by their containing MoonBit
   package directory.
3. Parse `test` declarations and `fn` declarations using brace-aware body
   spans.
4. Extract call edges from masked function and test bodies.
5. Resolve unqualified calls to functions in the same package, including
   declarations in another file.
6. Walk the package call graph from every test block, with cycle protection.
7. Apply API boundary rules only inside code reachable from a test.
8. Attach the owning test name and call path to each finding.

This changes the unit of analysis from "a risky-looking line in a test file" to
"an environment boundary reachable from a named test through its package."

## Concrete case

```moonbit
fn read_ambient_token() -> String {
  @env.get_env_var("TOKEN")
}

fn prepare_request() -> String {
  read_ambient_token()
}

fn unused_debug_helper() -> String {
  fetch("https://debug.example.test")
}

test "request reads an ambient token" {
  ignore(prepare_request())
}
```

Semantic mode reports only:

```text
test: request reads an ambient token
path: request reads an ambient token -> prepare_request -> read_ambient_token
rule: HERM-ENV
```

The unused debug helper is not reachable from any test and does not become a
finding. Legacy whole-file mode can still be requested with
`--no-reachability`; on this fixture it additionally reports the unused
network helper.

Cross-file calls are handled by the same graph. A test can call
`prepare_request` in one file while the environment access lives in another file
of the same package; the reported path still names the owning test and every
intermediate function. The fixture under `examples/semantic/cross_file/`
demonstrates this directly.

## Engineering depth

- Brace and nesting aware body extraction.
- Comment, string, character, nested-block-comment, and snapshot masking.
- Package-local, multi-file call graph with cycle protection.
- One semantic trace per calling test.
- Test and helper scope tracking, including scoped suppression behavior.
- Stable trace fields in Text, JSON, Markdown, SARIF, baselines, Action
  summaries, and PR comments.
- Semantic and legacy scans covered by deterministic unit tests across Native,
  Wasm-GC, and JavaScript targets.

## Scope

The current call graph covers `fn` declarations in one MoonBit package
directory. It deliberately ignores calls between package directories, methods,
qualified module calls, dynamic dispatch, macros, and generated code. API
boundary detection remains rule-based and is not a full MoonBit type checker.

These limitations are explicit: `--no-reachability` provides line-based
analysis across every discovered `.mbt` source file for migration and
precision-corpus compatibility, while semantic mode provides the default
test-oriented result.
