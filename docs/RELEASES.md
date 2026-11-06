# Native binary releases

MoonHermetic publishes native executables as GitHub Release assets. The release
workflow builds one binary on each current GitHub-hosted runner family:

- Linux x86-64
- Windows x86-64
- macOS on the architecture used by `macos-latest`

Each asset is named with its version, platform, and architecture:

```text
moonhermetic-v0.12.0-linux-x86_64
moonhermetic-v0.12.0-windows-x86_64.exe
moonhermetic-v0.12.0-macos-arm64
moonhermetic-v0.12.0-mooncakes.zip
```

A matching `.sha256` file is published beside every executable. Release
downloads should verify the checksum before running the executable:

```bash
sha256sum -c moonhermetic-v0.12.0-linux-x86_64.sha256
chmod +x moonhermetic-v0.12.0-linux-x86_64
./moonhermetic-v0.12.0-linux-x86_64 --version
```

The reusable GitHub Action performs the checksum verification automatically
for version tags. If the release asset is unavailable, it falls back to
building from the Action's pinned source.

## Publishing

The `Release binaries` workflow runs for tags matching `v*`. It also has a
manual dry-run mode that builds and uploads workflow artifacts without creating
a GitHub Release.

Before tagging:

1. Update the version in `moon.mod`, the CLI, report renderers, and changelog.
2. Run `moon check --target all --deny-warn` and all test targets.
3. Run the manual `Release binaries` workflow and inspect all three artifacts.
4. Create and push the matching `vX.Y.Z` tag.

The tag workflow builds fresh binaries, verifies their `--version` output and
checksums, then creates or updates the GitHub Release.
