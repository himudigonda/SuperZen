# Releasing SuperZen

Releases are cut from `main` by pushing a `vX.Y.Z` tag. The Release workflow builds the DMG on a macOS runner, signs and notarizes it when the secrets below exist, and publishes a GitHub release with the DMG and its SHA-256 checksum.

## Steps

1. On a branch, run `just bump X.Y.Z`. This sets `MARKETING_VERSION` and increments `CURRENT_PROJECT_VERSION` in every target.
2. Add a `## [X.Y.Z] - YYYY-MM-DD` section to `CHANGELOG.md`. Its body becomes the release notes.
3. Open a PR and merge it once CI is green.
4. On an up to date `main`, run `just ship X.Y.Z`.

`just ship` refuses to continue unless the tree is clean, `main` matches `origin/main`, the project and changelog agree on the version, the signing config is complete, and the tag does not exist yet. It then runs lint and tests, builds the DMG locally, verifies the checksum, and only then creates and pushes the tag. It never commits and never pushes a branch.

The Release workflow also runs as a dry run on PRs that touch `scripts/`, the `justfile` or the workflow. It builds and uploads the DMG as a workflow artifact without publishing.

## Signing and notarization

Both are optional. With no secrets the app is ad hoc signed and the release notes include Gatekeeper instructions.

| Secret | Purpose |
| --- | --- |
| `DEVELOPER_ID_APPLICATION` | Full identity name, for example `Developer ID Application: Name (TEAMID)` |
| `APPLE_TEAM_ID` | Team ID that owns the identity |
| `MACOS_CERTIFICATE_P12` | Base64 encoded `.p12` export of the Developer ID certificate and key |
| `MACOS_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `NOTARY_APPLE_ID` | Apple ID used with `notarytool` |
| `NOTARY_PASSWORD` | App-specific password for that Apple ID |

Signing needs the first four. Notarization also needs the last two, and only runs for tag builds. A partial set fails fast instead of silently shipping an unsigned build. Locally, export the same variables and keep the identity in your login keychain.

## Script tests

`just test-scripts` runs shellcheck and the release script tests. CI runs them on every PR.
