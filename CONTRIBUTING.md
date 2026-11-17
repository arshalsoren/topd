# Contributing to topd

Thanks for helping. topd is a small menu bar app. Keep changes focused and easy to review.

## Build and check

```sh
swift build              # debug build
swift run topd-checks    # behavior checks; must report 0 failed
./run.sh                 # build the app bundle and start it
```

Requirements: macOS 14 or later, and the Xcode Command Line Tools.

## Before you open a pull request

- `swift run topd-checks` passes.
- `swift build -c release --product topd` builds without warnings.
- Behavior you changed is checked on screen. Say what you checked, and what you did not.
- New user-visible behavior is noted in `CHANGELOG.md` under "Unreleased".
- No personal data, secrets, machine paths, or internal tracker references in code, docs, or commit messages.

## Design rules

- The sampling core (`Sources/TopdCore`) has no UI code, so it stays testable.
- No network access and no telemetry. Do not add either without an explicit, opt-in design.
- Charts use the validated data palette. Themes change only the app chrome.
- Labels and icons must stay readable in every theme and in light and dark appearance.

## Licensing of contributions

By contributing you agree that your contribution is licensed under the MIT License in `LICENSE`.
