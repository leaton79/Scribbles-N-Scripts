# Scribbles-N-Scripts — AI-Optimized Design Specification
## How to Use This Document Set

---

## File Inventory

```
manuscript-spec/
├── README.md                          ← You are here
├── project-bible/
│   └── PROJECT-BIBLE.md               ← Core reference (include in EVERY prompt)
└── modules/
    ├── 01-PROJECT-IO.md               ← Foundation: file format, CRUD, backup
    ├── 02-EDITOR.md                   ← Markdown editor, block rendering, undo
    ├── 03-SIDEBAR-NAV.md              ← Hierarchy tree, navigation, breadcrumbs
    ├── 04-LINEAR-MODE.md              ← Sequential reading/writing view
    ├── 05-MODULAR-MODE.md             ← Card-based spatial view
    ├── 06-MODE-SWITCH.md              ← Transition controller between modes
    ├── 07-SNAPSHOTS.md                ← Version control, diff, restore
    ├── 08-TAGS-METADATA.md            ← Tags, labels, custom fields, filters
    ├── 09-FIND-REPLACE.md             ← Search engine, regex, project-wide replace
    ├── 10-SPLIT-EDITOR.md             ← Dual-pane editing
    └── 11-WRITING-GOALS.md            ← Session goals, stats, history
```

---

## Architecture: Two-Layer System

### Layer 1: Project Bible (Shared Context)
`PROJECT-BIBLE.md` is included in **every** AI prompt. It contains the data model (Swift structs), file format spec, design constraints, glossary, dependency map, performance budgets, and cross-cutting concerns. This ensures every module is built against the same types, terminology, and constraints.

### Layer 2: Module Spec Cards (Task-Specific Context)
Each module card is a self-contained specification for one buildable unit. It contains everything the AI needs to implement that module: purpose, interface definitions, behavioral specs (given/when/then), edge cases, test cases, and implementation notes. Feed one module card at a time alongside the Project Bible.

---

## Prompting Strategy

### Building a Module From Scratch

```
Prompt structure:
┌──────────────────────────────────────┐
│  System: "You are building a native  │
│  macOS app in Swift/SwiftUI."        │
│                                      │
│  Context: [paste PROJECT-BIBLE.md]   │
│                                      │
│  Task: [paste MODULE-XX.md]          │
│                                      │
│  Instruction: "Implement this module │
│  following the interface spec, all   │
│  behavioral specs, and edge cases.   │
│  Produce the Swift source files.     │
│  Include unit tests matching the     │
│  test cases in section 5."           │
└──────────────────────────────────────┘
```

### Fixing / Iterating on a Module

```
Prompt structure:
┌──────────────────────────────────────┐
│  Context: [paste PROJECT-BIBLE.md]   │
│                                      │
│  Context: [paste MODULE-XX.md]       │
│                                      │
│  Current code: [paste current .swift │
│  files for this module]              │
│                                      │
│  Issue: "The following test fails:   │
│  [paste test output]. Fix the        │
│  implementation to pass this test    │
│  while maintaining all other specs." │
└──────────────────────────────────────┘
```

### Integrating Two Modules

```
Prompt structure:
┌──────────────────────────────────────┐
│  Context: [paste PROJECT-BIBLE.md]   │
│                                      │
│  Module A: [paste MODULE-A.md]       │
│  Module A code: [paste .swift files] │
│                                      │
│  Module B: [paste MODULE-B.md]       │
│  Module B code: [paste .swift files] │
│                                      │
│  Task: "Wire Module B to consume     │
│  Module A's exposed interface.       │
│  Produce the integration code and    │
│  any necessary adapter layers."      │
└──────────────────────────────────────┘
```

---

## Build Order

Follow this sequence. Each step produces a testable, runnable increment.

| Step | Module | What You Have After This Step |
|------|--------|-------------------------------|
| 1 | 01-PROJECT-IO | You can create, open, save, and backup projects. The file format works. You can add/remove/move scenes and chapters programmatically. |
| 2 | 02-EDITOR | You can open a single scene and edit it with Markdown rendering. Autosave works. Undo/redo works. |
| 3 | 03-SIDEBAR-NAV | You can see the project hierarchy, navigate between scenes, and reorder via drag-and-drop. |
| 4 | 04-LINEAR-MODE | You can write sequentially through scenes with boundary markers. Previous/Next navigation works. |
| 5 | 05-MODULAR-MODE | You can see all scenes as cards, drag to reorder, and filter. |
| 6 | 06-MODE-SWITCH | You can switch between linear and modular mode preserving context. **The core app is now usable for daily writing.** |
| 7 | 07-SNAPSHOTS | You can save named versions and compare them. Restore is safe. |
| 8 | 08-TAGS-METADATA | You can tag, label, and add custom fields to scenes. Filtering works across sidebar and cards. |
| 9 | 09-FIND-REPLACE | You can search project-wide with regex and batch-replace. |
| 10 | 10-SPLIT-EDITOR | You can view two scenes side-by-side. |
| 11 | 11-WRITING-GOALS | You can set goals, track progress, and view writing history. **MVP is complete.** |

---

## Key Design Decisions (Quick Reference)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Editor model | Plain text + Markdown rendering | Fast to build, universal format, no proprietary encoding |
| Data format | Directory of .md + .json files | Human-readable, no vendor lock-in, git-friendly |
| Scene as atomic unit | One .md file per scene | Keeps files small, enables granular loading and versioning |
| Metadata in manifest, not in .md files | Separation of content and metadata | Scenes are pure Markdown readable by any tool |
| No cloud/sync | Local-only | Reduces complexity, matches design principles |
| Fixed color labels (8 colors) | Enum, not arbitrary picker | Keeps UI consistent, avoids color picker complexity |
| Undo per-scene, not per-project | Scene-scoped undo stacks | Simpler, more predictable for the user |
| Snapshots as diffs | Baseline + incremental diffs | Storage-efficient while allowing full reconstruction |

---

## Document Version

| Field | Value |
|-------|-------|
| Spec Version | 1.0 |
| Date | March 2026 |
| Target | macOS (Swift/SwiftUI) |
| Scope | MVP (v1.0) — 11 modules |
| Author | Lance (Northeastern University) |
