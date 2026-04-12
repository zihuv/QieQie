# Repository Guidelines

## Project Structure & Module Organization
`QieQie/` contains the macOS menu bar app source, including SwiftUI views, app lifecycle code, timer logic, and persistence-related types. Static assets live under `QieQie/Assets/`. The Xcode project is kept at the repository root. Helper scripts and CI definitions live in `scripts/` and `.github/workflows/`. Generated output belongs in `build/`, `DerivedData/`, and `artifacts/`; do not commit those directories.

## Build, Test, and Development Commands
Prefer building and running from Xcode during daily development. From the terminal, use the shared app scheme in Debug for a local verification build:
```bash
xcodebuild -project <project>.xcodeproj -scheme <app-scheme> -configuration Debug -derivedDataPath build build
```
Launch the compiled app bundle from `build/Build/Products/Debug/` after a successful build. Use helper scripts only when they are already part of the current workflow; contributor guidance here focuses on local development, not release operations.

## Coding Style & Naming Conventions
Follow the existing Swift style: 4-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties and methods, and one primary type per file when practical. Keep `@MainActor` UI-facing managers on the main thread and prefer small, descriptive helper methods over long view bodies. No repo-level `SwiftFormat` or `SwiftLint` config exists yet, so use Xcode’s formatter and match surrounding code.

## Testing Guidelines
There is no committed XCTest target or coverage gate yet. For logic changes, at minimum run a clean Debug build and manually exercise the menu bar flow. When adding tests, create a dedicated test target, name files `*Tests.swift`, and focus on timer state transitions, pause/resume math, and persistence-backed history aggregation.

## Commit & Pull Request Guidelines
Recent history shows short, direct commit subjects; keep them concise and imperative. Pull requests should include a clear summary, manual verification steps, linked issues when relevant, and screenshots or short recordings for menu bar, popover, or history UI changes.
