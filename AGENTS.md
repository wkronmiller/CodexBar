# CodexBar Agent Guidelines

## Project Overview
CodexBar is a Swift 6 macOS menu bar app that monitors AI service usage/credits with real-time updates. Built with SwiftUI, modern Observation framework, and strict concurrency enforcement.

## Project Structure & Modules
- `Sources/CodexBarCore`: Core logic (usage probes, status monitors, data models, formatters)
- `Sources/CodexBar`: Main menu bar app (AppDelegate, StatusItemController, settings views)
- `Sources/CodexBarCLI`: Command-line interface for usage queries
- `Sources/CodexBarWidget`: macOS widget extensions
- `Sources/CodexBarClaudeWebProbe`: Web scraper for Claude usage
- `Sources/CodexBarClaudeWatchdog`: Process monitor for Claude CLI
- `Tests/CodexBarTests`: Swift Testing coverage (mimic source file structure)
- `Scripts/`: Build/package/release automation tools

## Build, Test, Lint Commands

### Quick Reference
```bash
# Dev loop (build + test + package + relaunch app)
./Scripts/compile_and_run.sh

# Build only
swift build                    # debug
swift build -c release         # release

# Build with Xcode (Swift Package Manager)
xcodebuild -scheme <SchemeName> -configuration Debug -destination 'platform=macOS' build
xcodebuild -scheme CodexBarClaudeWebProbe -configuration Debug -destination 'platform=macOS' build
# Available schemes: CodexBar, CodexBar-Package, CodexBarClaudeWatchdog, CodexBarClaudeWebProbe, CodexBarCLI, CodexBarWidget

# Test
swift test                     # run all tests
swift test --filter ClassName  # run specific test suite
pnpm test                      # alias for swift test
pnpm test:tty                  # TTY integration tests only
pnpm test:live                 # live API tests (requires LIVE_TEST=1)

# Format & Lint
pnpm check                     # format check + lint (ALWAYS run before handoff)
pnpm format                    # auto-format with SwiftFormat
swiftformat Sources Tests      # explicit format
pnpm lint                      # SwiftLint strict mode
swiftlint --strict             # explicit lint

# Package & Run
./Scripts/package_app.sh       # build app bundle
./Scripts/launch.sh            # kill old + launch new
# Manual restart:
pkill -x CodexBar || pkill -f CodexBar.app || true; cd /Users/steipete/Projects/codexbar && open -n /Users/steipete/Projects/codexbar/CodexBar.app
```

### Running Single Tests
```bash
# Run one test suite class
swift test --filter UsageFormatterTests

# Run specific test method (use test name without test_ prefix)
swift test --filter UsageFormatterTests/formatsUsageLine
```

### Release Workflow
```bash
./Scripts/sign-and-notarize.sh  # creates notarized arm64 zip (foreground, wait for completion)
./Scripts/make_appcast.sh <zip> <feed-url>
# See docs/RELEASING.md for full checklist
```

## Code Style Guidelines

### Imports
- **Order**: System frameworks first (alphabetical), then project modules (alphabetical)
- **Grouping**: Use blank lines to separate groups
- **Testable**: Place `@testable import` at the end of imports
```swift
import AppKit
import Foundation
import Observation
import SwiftUI

import CodexBarCore
import KeyboardShortcuts

@testable import CodexBar
```

### Formatting Rules (SwiftFormat)
- **Indentation**: 4 spaces (no tabs)
- **Line length**: 120 characters max (hard limit 250 for lint)
- **Self**: ALWAYS use explicit `self` (required by Swift 6 concurrency)
- **Wrapping**: Arguments/parameters wrap "before first" style
- **Marks**: Auto-generate for types/extensions with `MARK: - TypeName` and `MARK: - Protocol`
- **Trailing commas**: Required in multiline collections
- **Never remove `self`**: It's intentional for Swift 6, not accidental

### Type Conventions
- **Prefer structs** for value types and immutable data
- **Use enums** for state/variants with associated values when appropriate
- **Protocols**: Use for abstraction, add `@MainActor` when UI-related
- **Observable models**: Use `@Observable` macro (not `ObservableObject`)
```swift
@Observable
final class StatusManager {
    var status: ServiceStatus
    var lastUpdate: Date
}
```

### Naming Conventions
- **Types**: PascalCase (e.g., `UsageFormatter`, `StatusProbe`)
- **Functions/vars**: camelCase (e.g., `fetchUsage()`, `isLoading`)
- **Private members**: prefix with `_` only when shadowing a computed property
- **Test methods**: descriptive names (e.g., `formatsUsageLine`, `resetCountdown_minutes`)
- **MARK comments**: Use for organization (`// MARK: - Section Name`)
- **Enum cases**: camelCase (e.g., `.success`, `.notAuthenticated`)

### Error Handling
- **Prefer typed errors**: Define specific `Error` enums
```swift
enum ProbeError: Error {
    case networkFailure(URLError)
    case invalidResponse(statusCode: Int)
    case parsingFailed(reason: String)
}
```
- **Propagate or handle**: Don't silently swallow errors
- **Logging**: Use `Logger` from `OSLog` for production code
- **Testing**: Use `#expect(throws:)` for error assertions

### Swift 6 Concurrency
- **Strict concurrency**: Enabled project-wide via `StrictConcurrency` language feature
- **MainActor**: Annotate UI types/methods with `@MainActor`
- **Sendable**: Value types (structs/enums) are implicitly `Sendable`, mark reference types explicitly
- **Explicit self**: Required in closures and async contexts (enforced by compiler and swiftformat)
- **Modern patterns**: Use `@Observable` + `@State` instead of `ObservableObject` + `@StateObject`

## Testing Guidelines

### Framework & Structure
- **Swift Testing**: Use `@Test` and `@Suite` (not XCTest's `XCTestCase`)
- **Assertions**: Use `#expect(condition)` and `#expect(throws:)` (not XCTAssert)
- **File naming**: Match source file names (e.g., `UsageFormatter.swift` → `UsageFormatterTests.swift`)
- **Test organization**: Group with `// MARK:` comments and `@Suite` structs

### Test Patterns
```swift
import Testing
@testable import CodexBar

@Suite struct UsageFormatterTests {
    @Test func formatsUsageLine() {
        let formatter = UsageFormatter()
        let result = formatter.format(usage: 100, limit: 200)
        #expect(result == "100 / 200")
    }
    
    @Test func invalidInput_throwsError() {
        #expect(throws: FormatterError.self) {
            try formatter.format(usage: -1, limit: 200)
        }
    }
}
```

### Coverage Requirements
- **New features**: Add tests for happy path and edge cases
- **Bug fixes**: Add regression test before fixing
- **Parsing logic**: Add fixtures for new formats
- **Always run**: `swift test` or `pnpm check` before handoff

## Common Pitfalls & Warnings

### Provider Data Isolation
- **Never cross-contaminate**: When displaying usage for Claude, don't show identity/plan fields from Codex (and vice versa)
- **Per-provider rendering**: Each provider's data should be self-contained

### Cookie Import Behavior
- **Default to Chrome-only** when possible to avoid triggering browser prompts
- Override with browser list only when explicitly needed

### CLI Status Parsing
- **Don't rely on status line format**: It's user-configurable and unstable
- Parse structured output or API responses instead

### Stale Binary Detection
- **After any code change**: Run `./Scripts/compile_and_run.sh` to ensure fresh binary
- **Never trust running instance** without confirming rebuild

### Release Scripts
- **Run in foreground**: Don't background `sign-and-notarize.sh`, wait for completion
- **Check ~/.profile**: Contains Sparkle keys and App Store Connect credentials

## Commit & PR Guidelines
- **Commit messages**: Short imperative (e.g., "Fix dimming logic", "Add usage formatter")
- **Scope commits**: One logical change per commit
- **PR description**: List changes, commands run, attach screenshots for UI changes
- **Link issues**: Reference GitHub/Linear issues when relevant

## Agent Workflow
1. **Before starting**: Understand task scope, read related code
2. **Make changes**: Keep modifications minimal, reuse existing helpers
3. **Format & lint**: Run `pnpm check` to fix all issues
4. **Test**: Run `swift test` (or `./Scripts/compile_and_run.sh` for app changes)
5. **Verify**: For app changes, confirm behavior in freshly built bundle
6. **Clean up**: Remove temporary files, revert exploratory changes
7. **Handoff**: Confirm all checks pass and app behaves correctly
