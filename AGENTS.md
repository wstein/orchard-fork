# Repository Guidelines

## Project Structure & Module Organization

Orchard is a native SwiftUI macOS app for Apple containers. `Orchard/Views/` contains presentation code; `Orchard/Services/` contains desktop services; `Orchard/Assets.xcassets/` holds app assets. `Packages/OrchardCore/Sources/` separates Foundation-only `OrchardDomain`, native adapters in `OrchardRuntime`, and shared use cases in `OrchardApplication`. Keep reusable logic in these modules and desktop presentation in `Orchard/`. Both GUIs must use the shared implementation: SwiftUI imports the core directly, while browser JavaScript calls the standalone HTTP service. Do not duplicate container lifecycle, retry, recovery, or validation logic in either GUI.

App unit tests live in `OrchardTests/`, UI tests in `OrchardUITests/`, and package tests in `Packages/OrchardCore/Tests/`. `site/` is the documentation website; `scripts/` contains release and demo utilities.

## Build, Test, and Development Commands

Use macOS 26, Xcode 26, and Swift 6.2; install Apple Container for live runtime operations.

- `open Orchard.xcodeproj`: open Xcode; select the `Orchard` scheme and run with ⌘R.
- `xcodebuild build -project Orchard.xcodeproj -scheme Orchard -destination 'platform=macOS'`: build the desktop app.
- `swift test --package-path Packages/OrchardCore`: run shared package tests without launching the app.
- `xcodebuild test -project Orchard.xcodeproj -scheme Orchard -destination 'platform=macOS'`: run app unit tests.
- Substitute `-scheme OrchardUITests` to run UI smoke tests in a macOS GUI session.

## Coding Style & Naming Conventions

Match existing Swift style: four-space indentation, `UpperCamelCase` types, and `lowerCamelCase` functions and properties. Name files after their principal type; keep SwiftUI views small and composable. Prefer typed backend protocols and native XPC adapters for runtime operations. No repository-wide SwiftLint or SwiftFormat configuration is present.

## Testing Guidelines

Use TDD for behavior changes: write a failing test, implement the smallest passing change, then refactor. Unit tests use Swift Testing (`@Test`, `#expect`); UI tests use XCTest. Use `*Tests.swift` filenames and descriptive behavior names. Prefer mock backends for deterministic tests. Record the failing test before implementation, then run affected suites before committing. Public package API tests must use normal imports so external consumers do not depend on `@testable`. Use the native unit suite to verify SwiftUI integration; CI reports `Orchard/Services/` coverage without enforcing a percentage threshold.

## Commit, Pull Request & Task Guidelines

Create and update issues and PRs only in `wstein/orchard-fork`. Always pass `--repo wstein/orchard-fork` to GitHub CLI issue/PR commands. Never create issues or PRs in `andrew-waters/orchard`. This fork-specific instruction takes precedence over upstream issue and PR links in `CONTRIBUTING.md` and repository templates.

Use stacked PRs for dependent work. `feat/shared-swift-core` targets `main`; `feat/standalone-web-gui` targets `feat/shared-swift-core` until the core PR merges. Push requested feature branches to `origin`, verify that the remote points to the fork, inspect the PR base repository and branch, and do not merge without authorization.

History mixes imperative subjects with recent Conventional Commits. Use focused, atomic conventional commits, such as `fix(runtime): handle stopped machines`; split multi-step work into multiple logical commits.

After each phase or task, update the corresponding issue/task in `wstein/orchard-fork` with commit/PR links, TDD results, validation, and remaining work. Mark acceptance criteria only when verified; keep implementation completion distinct from merge/release status. PRs should explain what changed and why, link related issues, include UI screenshots or recordings, and add an appropriate `CHANGELOG.md` entry. Follow `CONTRIBUTING.md`; report vulnerabilities privately as described in `SECURITY.md`.
