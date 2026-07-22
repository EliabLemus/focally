# Contributing to Focally

Thanks for your interest! This is a small, focused project — keep PRs minimal and on-scope.

## Setup

```bash
git clone https://github.com/EliabLemus/focally.git
cd focally
brew install swiftlint swiftformat xcodegen
xcodegen generate
xcodebuild build -scheme Focally -destination 'platform=macOS'
```

## PR Guidelines

- One feature/fix per PR
- Run `swiftlint` and `swiftformat` before pushing
- Tests must pass: `xcodebuild test -scheme Focally -destination 'platform=macOS'`
- Keep it simple — this is a menu bar app, not a framework

## Good First Issues

Look for issues labeled `good first issue`. If nothing is open, check [docs/](docs/) for known limitations worth fixing.

## Questions?

Open an issue — we keep it lightweight.