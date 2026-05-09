# ResourcePlanner

A native macOS document-based app for capacity and cost planning. Built with SwiftUI.

ResourcePlanner lets you model the people, roles, teams, and initiatives that make up a project portfolio, then roll the numbers up into reports you can share. Source files are plain JSON (`.rplan`) so plans are diffable, scriptable, and not locked into the app.

## Features

- **Resources, roles, teams** — model who does the work. Roles carry default rates and a default team that resources adopt automatically; the override-protection pattern prevents accidental data loss when reassigning.
- **Programs and initiatives** — programs group initiatives and provide default date ranges that new initiatives inherit. Each initiative has its own timeline, color, icon, expected returns, and arbitrary "other costs" (consulting, licensing, travel).
- **Weekly-truth allocations** — allocations are stored weekly; the monthly view is a projection that fans out to weeks losslessly. Weekly edits "pin" their week, monthly edits flow back across all unpinned weeks.
- **Multi-currency** — per-resource and per-cost currency codes, normalized through a configurable conversion table to a single display currency.
- **Reports** — overview report rolls up cost by program, by initiative, committed vs. placeholder, and placeholder impact. Resource allocation report breaks down by role and by resource. Per-initiative reports include ROI when expected returns are set.
- **Exports** — every report exports to PDF, CSV, or JSON. Errors surface as dialogs rather than disappearing silently.

## Get the App

You can download the latest stable release over at the [official page](https://coefficiencies.com/apps/resourceplanner/) for the application.

## Building

The Xcode app and a SwiftPM package share the model layer. The package exists primarily to keep XCTest fast.

```bash
# CLI build of the app
xcodebuild -project "Resource Planner/Resource Planner.xcodeproj" \
  -scheme "Resource Planner" \
  -configuration Debug \
  -destination "platform=macOS" build

# Run the test suite
swift test
```

To work in Xcode, open `Resource Planner/Resource Planner.xcodeproj`.

Requires macOS 14+ and Xcode 15+.

## Repo layout

```
resourcePlanner/
├── README.md                                  ← you are here
├── PLAN.md                                    ← phased build plan, current phase
├── CLAUDE.md                                  ← conventions and gotchas for Claude
├── Package.swift                              ← SwiftPM wrapper for CLI build + tests
├── Resource Planner/
│   └── Resource Planner.xcodeproj             ← the Xcode app
│       └── Resource Planner/                  ← app sources (Model/, Views/, Export/)
├── ResourcePlanner/Model/                     ← package mirror of Model/ (kept in sync)
└── ResourcePlannerTests/                      ← XCTest suite
```

The app sources and the package's Model directory are intentionally duplicated — see `CLAUDE.md` for the rationale and the sync workflow.

## Document format

Plans are saved as JSON with UTI `com.tommertron.resourceplanner.rplan`. The current schema version is `4`; older documents are read transparently with `decodeIfPresent` defaults for any fields that did not exist in earlier versions.

## For Claude

If you are an AI assistant working in this repository:

- **Read `PLAN.md` and `CLAUDE.md` first.** `PLAN.md` is the source of truth for what is built, in flight, and next. `CLAUDE.md` documents the conventions and the *why* behind non-obvious decisions (rate normalization, weekly-vs-monthly truth, sync between the two model copies, etc.).
- **Update this README on major updates.** When you ship something that changes how a user perceives the app — a new top-level concept (Programs, Teams), a new export format, a schema bump that affects compatibility, a meaningful UI restructure — update the relevant section here in the same commit. Small bug fixes and refactors do not need a README change.
- **Keep the two model copies in sync.** Files under `Resource Planner/Resource Planner/Model/*.swift` and `ResourcePlanner/Model/*.swift` must match. Edit one, then `cp` to the other; verify with `swift build` and `swift test` before considering the change done.
- **Track work via Todoist.** Tasks live in the "Resource Planner" project. The workflow is documented in `CLAUDE.md` under "Todoist task management". Move completed work to *Ready To Test* and add a comment summarizing what was done — do not silently mark tasks complete.
