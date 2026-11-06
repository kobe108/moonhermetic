# Mooncakes package publication

MoonHermetic is a MoonBit library and CLI module:

```text
kobe108/moonhermetic
```

Consumers can use the analyzer from MoonBit source:

```moonbit
let findings = @moonhermetic.scan_source("billing_test.mbt", source)
```

and can add a published package with:

```bash
moon add kobe108/moonhermetic
```

## Package validation

Every release builds the package with `moon package --list` and validates the
ZIP before publication. The validator checks:

- Required module, README, license, Action, analyzer, CLI, report, suppression,
  and generated API files are present.
- ZIP paths are relative and contain no parent traversal.
- Build outputs, Git data, dependency caches, work directories, environment
  files, and credential files are absent.

The resulting `moonhermetic-vX.Y.Z-mooncakes.zip` and its SHA-256 file are also
attached to the GitHub Release.

## GitHub-hosted publication

The `Publish Mooncakes package` workflow has a safe default: it verifies,
builds, and validates the package without publishing or requiring a token.

To publish:

1. Open the repository Actions tab.
2. Run `Publish Mooncakes package`.
3. Enter the existing `vX.Y.Z` tag.
4. Enable `publish` only after reviewing the package validation result.

Actual publishing requires a repository secret named `MOONCAKES_TOKEN`,
created from the Mooncakes account `kobe108`. The workflow writes that token
only to the ephemeral GitHub runner's `~/.moon/credentials.json`.

The publish path runs `moon publish --dry-run` immediately before the real
publication. Credentials are never used during the token-free preflight.

The credential setup rejects:

- A module not owned by `kobe108`.
- Any username other than `kobe108`.
- Missing or unusually short tokens.

Tokens are never printed by the workflow.

## Local publication

Do not reuse credentials belonging to another Mooncakes user. Confirm the
username in `~/.moon/credentials.json` before publishing.

For a maintainer account:

```bash
moon login
moon package --list
node scripts/validate-package.mjs
moon publish --dry-run
moon publish
```

Choose the `kobe108` GitHub identity during login. The dry run is mandatory
before the irreversible publish command.
