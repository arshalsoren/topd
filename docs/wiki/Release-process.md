# Release process

1. Every change arrives as a pull request into `master`, approved before merge.
2. Add user-visible changes under "Unreleased" in `CHANGELOG.md`.
3. Bump `CFBundleShortVersionString` in `Support/Info.plist` and move the changelog entries into a dated section.
4. Tag the merge commit `vX.Y.Z` and publish a GitHub Release with the changelog entries.
5. Verify locally: `swift run topd-checks`, then `swift build -c release --product topd`, then `./run.sh`.

Versions follow Semantic Versioning. CI is not yet running, so the local checks above are the
gate for now.
