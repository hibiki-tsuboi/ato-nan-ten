# Repository Guidelines

## Project Structure & Module Organization

`AtoNanTen/` contains the SwiftUI application source. `AtoNanTenApp.swift` is the app entry point, while `ContentView.swift` defines the current root view. Images, app icons, and colors belong in `AtoNanTen/Assets.xcassets/`. Xcode target and build settings live in `AtoNanTen.xcodeproj/`.

As the app grows, group related views, models, and services by feature under `AtoNanTen/` (for example, `Features/Score/`). Keep reusable UI in a clearly named `Components/` directory. Do not commit user-specific Xcode state from `xcuserdata/`.

## Build, Test, and Development Commands

- `open AtoNanTen.xcodeproj` opens the project for local development and SwiftUI previews.
- `xcodebuild -project AtoNanTen.xcodeproj -scheme AtoNanTen -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` performs a command-line simulator build without signing.
- `xcodebuild -project AtoNanTen.xcodeproj -scheme AtoNanTen clean` removes generated build products for the scheme.

Run the app from Xcode by selecting an installed iPhone or iPad simulator and pressing Command-R.

## Coding Style & Naming Conventions

Use four-space indentation and standard Swift API design conventions. Name types and SwiftUI views in `UpperCamelCase`; use `lowerCamelCase` for properties, functions, and local values. Prefer immutable `let` values, mark implementation details `private`, and split large view bodies into focused subviews. Add a `#Preview` for visual components when practical.

No formatter or linter is configured. Use Xcode's indentation tools and keep builds warning-free.

## Testing Guidelines

The project currently has no test target or coverage requirement. New behavior should introduce an `AtoNanTenTests` unit-test target; use names such as `ScoreCalculatorTests.swift` and describe the expected behavior in each test. Add UI tests only for critical user flows. Once a test target exists, run it with `xcodebuild test` using the project, scheme, and an installed simulator destination.

## Commit & Pull Request Guidelines

No Git history is present in this checkout, so an existing commit convention cannot be inferred. Use short, imperative subjects with an optional area prefix, such as `ui: add countdown display`. Keep commits focused.

Pull requests should explain the user-visible change, implementation notes, and verification performed. Link related issues and include simulator screenshots or recordings for UI changes. Never commit signing credentials, provisioning profiles, build output, or local Xcode user data.
