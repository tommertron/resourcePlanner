# ResourcePlanner — Build Plan

Native macOS app (SwiftUI) for planning people, initiatives, and capacity, with cost rollups and export.

## Architecture summary

- **Storage unit**: weekly allocations are the source of truth. Monthly entries fan out to weeks and tag each `WeekEntry` with `.monthly(MonthKey)` so monthly view is lossless when no weekly edits exist beneath. Editing a week pins it as `.weekly`. Monthly view averages mixed weeks and shows a "mixed" indicator.
- **Resource rates**: `RateBasis` (hourly / monthly / annual) + `hoursPerWeek`; everything normalizes to a weekly cost via `Resource.weeklyCost`.
- **Role defaults**: each `Role` carries `defaultRate / defaultRateBasis / defaultHoursPerWeek`. Resources inherit on assignment if `isCustomRate == false`. Editing a resource's rate flips `isCustomRate = true` and protects it from being clobbered. A "Reconcile to role default" button lets the user re-sync explicitly.
- **Document**: `.rplan` JSON via `DocumentGroup` + `Codable`. One file = many plans. UTI `com.tommertron.resourceplanner.rplan` declared in `Info.plist`, conforms to `public.json`.
- **UI shape**: single `NavigationSplitView` at the top with a sidebar that has three sections — Resources, Roles, Plans. Detail pane swaps based on selection. Per-section `+` buttons in section headers (no toolbar buttons → no chrome jumping between contexts).
- **Platform**: macOS 14+, SwiftUI, `@Observable` where useful, `ImageRenderer`/PDFKit for PDF later.

## Data model (current shape)

```
PlannerDocument                                       Model/PlannerDocument.swift
├── schemaVersion: Int (currently 1)
├── resources: [Resource]   // Model/Resource.swift
├── roles: [Role]
└── plans: [Plan]                                     Model/Plan.swift
        ├── name, notes
        ├── initiatives: [Initiative]    // start/end dates
        └── assignments: [Assignment]    // name, initiativeID
                └── allocations: [Allocation]
                        └── weeks: [WeekKey: WeekEntry]
```

- `Resource` — `name, roleID?, employmentType (.fullTime/.contractor/.placeholder), rate, rateBasis, hoursPerWeek, isCustomRate`. Helpers: `weeklyCost`, `matchesRoleDefault(_:)`, `adoptRoleDefaults(_:)`.
- `Role` — `name, defaultRate, defaultRateBasis, defaultHoursPerWeek`. Helper: `defaultWeeklyCost`.
- `WeekKey` / `MonthKey` — ISO year-week & year-month identifiers; `CodingKeyRepresentable` so JSON dict keys serialize as `"2026-W18"` / `"2026-06"` strings. Calendars: `Calendar.iso8601UTC`, `Calendar.gregorianUTC`. `MonthKey.weeksInMonth()` returns every ISO week whose Monday lies in that calendar month.
- `EntrySource` — `.weekly | .monthly(MonthKey)`. `WeekEntry { percent, source }`.

## File layout

```
resourcePlanner/                                          ← repo root
├── PLAN.md                                               ← this file
├── CLAUDE.md                                             ← project conventions for Claude
├── Package.swift                                         ← SwiftPM wrapper for CLI builds + tests
├── ResourcePlanner/Model/*.swift                         ← canonical model source (also used by package)
├── ResourcePlannerTests/*.swift                          ← XCTest unit tests
└── Resource Planner/                                     ← Xcode app
    ├── Resource Planner.xcodeproj                        ← objectVersion 77, PBXFileSystemSynchronizedRootGroup
    └── Resource Planner/
        ├── Resource_PlannerApp.swift                     ← @main, DocumentGroup
        ├── Resource_PlannerDocument.swift                ← FileDocument wrapping PlannerDocument
        ├── ContentView.swift                             ← single NavigationSplitView, sidebar selection
        ├── Info.plist                                    ← .rplan UTI + CFBundleDocumentTypes
        ├── Model/                                        ← copy of model files (auto-included by sync group)
        └── Views/
            ├── ResourceDetailView.swift
            └── Shared.swift                              ← ResourceRow, RoleDetailView, displayName extensions, zeroEmptyBinding
```

**Important**: `ResourcePlanner/Model/*.swift` (used by the SwiftPM target) and `Resource Planner/Resource Planner/Model/*.swift` (used by the Xcode app) are kept in sync manually. When changing the model, edit both — or edit one and `cp` to the other. Tests (`swift test`) only see the package copy.

## Tasks

### Phase 1 — Project + data model ✅
- [x] Scaffold Swift package (`ResourcePlannerCore`) — model layer compiles, tests pass
- [x] Xcode app shell (Document App template, `Resource Planner.xcodeproj`)
- [x] Register `.rplan` document type / UTI in `Info.plist`
- [x] Codable data model (Resource, Role, Initiative, Assignment, Allocation, WeekEntry, Plan, PlannerDocument)
- [x] WeekKey / MonthKey with `CodingKeyRepresentable` for string-keyed JSON
- [x] Weekly cost normalization (`Resource.weeklyCost`, `Role.defaultWeeklyCost`)
- [x] Monthly fan-out groundwork (`MonthKey.weeksInMonth`, `EntrySource.monthly` tagging)
- [x] Monthly-average projection helper (compute monthly % from weekly entries) — deferred to Phase 4 where it's needed
- [x] Unit tests: codable round-trip, week/month math, fan-out tagging, rate normalization, dict-key string encoding

### Phase 2 — Resources & Roles ✅
- [x] Single `NavigationSplitView` with sidebar sections (Resources, Roles, Plans) — replaced the original tabbed layout to fix toolbar/chrome thrash
- [x] Resource list + CRUD (sidebar row → detail form)
- [x] Rate basis toggle with Convert/Keep prompt (preserves effective weekly cost or just reinterprets the number)
- [x] Employment type with icon + tint per type
- [x] Live normalized weekly + annualized cost preview
- [x] "Equivalent hourly (40h/wk)" preview when basis is annual or monthly
- [x] Role list + detail (default rate fields + list of resources using the role with "Custom rate" badge if diverged)
- [x] Role inheritance: assigning a role to a non-custom resource adopts its defaults
- [x] Override protection: editing the rate flips `isCustomRate`; future assignments don't clobber it
- [x] "Reconcile to role default" button (disabled when already in sync)
- [x] "New Role…" item at the bottom of resource detail's role picker → modal sheet (autofocused, Enter to commit) → assigns and adopts defaults
- [x] Empty-when-zero TextFields via `zeroEmptyBinding`

### Phase 3 — Initiatives ✅
- [x] Sidebar **Initiatives** section showing list of initiatives across all plans (or per-plan once plans UI exists)
- [x] Detail editor with `name`, `startDate`, `endDate` (DatePicker), `notes` (TextEditor)
- [x] Add validation: `endDate >= startDate`
- [x] Decide on plan grouping: **suggested** — keep one default plan named "Baseline" auto-created on first save, expose plans as a top-level sidebar concept later in Phase 7
- [x] Show duration in weeks/months on the detail view as feedback

### Phase 4 — Planning grid ✅
- [x] Pick a plan, see assignments grouped under their initiatives
- [x] Add an Assignment to an initiative (name + which resource(s))
- [x] Weekly grid: rows = (initiative → assignment → resource), cols = weeks; cells editable as `%`
- [x] Per-resource allocation summary strip across visible date range — `Alice: 80% allocated, 20% free` with a bar; over-allocation flagged
- [x] Monthly view toggle:
  - render = if all weeks in month share the same `.monthly(M)` source, show that exact value; if any `.weekly` pin exists in the month, show average + small "mixed" indicator
  - write = fan out the entered % to all weeks in that month, tagging each `WeekEntry.source = .monthly(M)`
  - re-entering monthly with pinned weeks below → confirm before overwriting
- [x] Date range picker (start week/month, end week/month)
- [x] Implement the monthly-average projection helper deferred from Phase 1

### Phase 5 — Reports ✅
- [x] Cost-per-initiative over time, bucketed by year (e.g. "CRM rebuild: $250k in 2026, $100k in 2027")
- [x] Placeholder vs committed cost split
- [x] Incremental-cost preview when toggling whether a placeholder is included

### Phase 6 — Exports
- [ ] CSV export of the resourcing plan grid
- [ ] JSON export of the full `PlannerDocument`
- [ ] PDF formatted report via `ImageRenderer` + PDFKit

### Phase 7 — Polish
- [ ] Schema-version migration stub (read older `schemaVersion`, upgrade, save)
- [ ] Sample `.rplan` for QA + onboarding
- [ ] App icon + About panel
