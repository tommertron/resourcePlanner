# Project context for Claude

ResourcePlanner is a native macOS SwiftUI document-based app for capacity & cost planning. Source of truth for the build plan is `PLAN.md` — read it for current/next phase. This file captures conventions, gotchas, and the why behind decisions that aren't obvious from the code.

## Where things live

- **Xcode app**: `Resource Planner/Resource Planner.xcodeproj` (folder name has a space — quote it in shell). Uses `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup`, so **any file added to the source folder is automatically part of the target** — no need to drag into the project navigator.
- **Model files exist in two places**:
  - `Resource Planner/Resource Planner/Model/*.swift` — used by the app
  - `ResourcePlanner/Model/*.swift` — used by the SwiftPM package + tests (`swift build`, `swift test`)
  - **Keep them in sync.** Editing either alone will silently drift. Easiest workflow: edit the app copy, then `cp` to the package copy (or vice versa) before running tests.
- **Tests**: `ResourcePlannerTests/*.swift`, run with `swift test` from the repo root.
- **CLI build of the app**: `xcodebuild -project "Resource Planner/Resource Planner.xcodeproj" -scheme "Resource Planner" -configuration Debug -destination "platform=macOS" build`

## Architecture decisions (don't undo without thinking)

### Weekly is the source of truth, monthly is a projection
All allocations are stored as `[WeekKey: WeekEntry]`. Monthly entry/edit is a projection layer:
- **Write monthly value M** → fan out to every week in the month, set each `WeekEntry.source = .monthly(M)`
- **Edit a single week** → flip that week's `source` to `.weekly` (it becomes pinned)
- **Render monthly** → if all weeks in the month share `.monthly(M)`, display that value exactly (lossless). If any `.weekly`-pinned week exists, display the average and show a "mixed" indicator
- **Re-enter monthly with pinned weeks below** → confirm before overwriting

This means monthly planning stays lossless when the user stays in monthly view, and weekly edits are preserved across view toggles. Don't try to add a parallel `[MonthKey: ...]` store — it'll diverge.

### Rate normalization
Everything cost-related normalizes to `weeklyCost`. The three bases (annual / monthly / hourly) only differ in storage:
- annual: `rate / 52`
- monthly: `rate * 12 / 52`
- hourly: `rate * hoursPerWeek`

Mirror this in `Role.defaultWeeklyCost`. Adding a new basis means adding a case to `RateBasis` and a branch to **both** `Resource.weeklyCost` and `Role.defaultWeeklyCost`.

### Role inheritance with override protection
`Resource.isCustomRate: Bool` is the gate. When false, assigning a role calls `adoptRoleDefaults(_:)` which overwrites rate fields. When true, the role assignment leaves rate alone. Editing any rate field flips it to true. The "Reconcile to role default" button explicitly re-syncs and flips it back to false. **Never** silently overwrite when `isCustomRate == true` — that was the user's stated requirement.

### Single NavigationSplitView, not tabs
The original design had a `TabView` wrapping per-tab `NavigationSplitView`s, which gave each tab its own toolbar and caused the sidebar-toggle to jump and `+` buttons to multiply when switching tabs. The current design is one top-level `NavigationSplitView` with sidebar sections (Resources / Roles / Plans). `+` buttons live in section headers, not the toolbar. **Don't reintroduce per-tab toolbars** — keep all add actions section-scoped or sheet-based.

### Document format
JSON via `PlannerDocument.encoded() / .decoded(from:)`. UTI: `com.tommertron.resourceplanner.rplan`, declared in `Info.plist` under `UTExportedTypeDeclarations`, conforms to `public.json`. `Resource_PlannerDocument` is just a thin `FileDocument` wrapper around the Codable struct. Schema versioning via `schemaVersion: Int` is in place (currently `1`); migration logic is deferred to Phase 7.

### TextField empty-when-zero
SwiftUI's `TextField(value:format:)` with a non-optional `Double` always renders `0` for a zero value, which the user has to delete before typing. Use the `zeroEmptyBinding(_:)` helper (in `Views/Shared.swift`) which maps `0 ↔ nil` for any `Binding<Double>`. Apply it to every numeric input.

## Conventions

- **Currency**: hardcoded to USD for now (`format: .currency(code: "USD")`). When/if localization is added, plumb a currency code through the document.
- **Calendars**: always use `Calendar.iso8601UTC` for week math and `Calendar.gregorianUTC` for month math (both UTC, both defined in `TimeKeys.swift`). Don't use the user's local calendar — it produces inconsistent week boundaries across time zones.
- **Identifiers**: every model entity has a UUID `id`. Foreign references (e.g. `Resource.roleID`, `Assignment.initiativeID`) use those UUIDs. When deleting, scan for orphans rather than cascading.
- **Display name extensions** for enums (`EmploymentType.displayName`, `RateBasis.displayName`) live in `Views/Shared.swift`. Add new ones there.
- **Sheets for creation flows that need a name** (e.g. New Role) — autofocus the field, Enter commits, Esc cancels. Pattern: `NewRoleSheetView` in `ContentView.swift`.

## Known issues / paper cuts

- Swift-6 warning: main-actor-isolated Hashable conformance on `WeekKey`/`MonthKey`. Currently a warning under Swift 5 mode, will be an error in Swift 6. Fix when touching `TimeKeys.swift` — likely needs `nonisolated` annotations or reassessing where the dict types are used. Tracked in PLAN.md Phase 7.
- Two model copies (app + package) drift if you forget to sync. If this becomes painful, the cleanest fix is to make the Xcode app reference the SwiftPM package as a local dependency — but Xcode currently refuses because the package's directory is the parent of the `.xcodeproj`. Workarounds: move the `.xcodeproj` out, or move `Package.swift` into a sibling directory.

## Testing

`swift test` from repo root runs the XCTest suite in `ResourcePlannerTests/`. Eight tests covering rate normalization, week/month ordering & ranges, codable round-trip, dict-key string encoding, and monthly fan-out tagging. Add tests when changing model semantics — the package builds in seconds and round-trip tests catch most JSON regressions.

## Todoist task management

Tasks are tracked in the **Resource Planner** Todoist project via the `td` CLI.

- **Binary**: `/opt/homebrew/bin/td` (Node.js CLI — not on default PATH, so prefix every command with `PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"`)
- **Project ID**: `6gWmg3q6xF4V2hV9`
- **Sections**: Backlog, Inbox (`6gWmg56f3rMVrXPh`), Up Next (`6gWmg5PWcfvC3v2h`), Ready To Test (`6gWmg6Q9ChM6H9v9`)

### Common commands

```bash
# List all Inbox tasks (with descriptions)
PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH" td task list --project "id:6gWmg3q6xF4V2hV9" --filter "#Resource Planner & /Inbox" --json --full

# Add a comment to a task
PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH" td comment add "id:<taskId>" --content "Done — <summary of what was done>"

# Mark a task complete
PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH" td task complete "id:<taskId>"

# List sections
PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH" td section list --project 6gWmg3q6xF4V2hV9 --json
```

### Workflow

When picking up tasks: read the Inbox, work each item, add a comment summarizing what was done, then mark complete. The Todoist API occasionally returns 503 — just retry.
