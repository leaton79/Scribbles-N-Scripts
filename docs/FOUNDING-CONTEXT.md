# Scribbles-N-Scripts - Founding Context (Chat Continuation Brief)

Last updated: 2026-03-10
Repository: https://github.com/leaton79/Scribbles-N-Scripts
Primary branch: main

## 1. Product Intent
Scribbles-N-Scripts is a macOS SwiftUI writing app for long-form manuscript development with structured project organization, dual writing modes, robust project I/O, backup/restore safety, navigation, goals, and increasingly capable Find/Replace workflows.

This document captures the implemented baseline, key decisions, current status, and near-term execution priorities so a new chat can continue work with minimal reorientation.

## 2. Grounding Specs and Rules Used
- `AGENTS.md`
- `docs/spec/PROJECT-BIBLE.md`
- `docs/spec/modules/*.md`

These drove:
- data model shape
- project filesystem contracts
- lock/backup/restore guarantees
- module-by-module implementation and testing style

## 3. Implemented Foundation (What Exists Now)

### 3.1 Project + App Skeleton
- Swift Package configured for macOS 14+, Swift 5.9
- Executable target: `Scribbles-N-Scripts`
- Swift module: `ScribblesNScripts`
- Test target: `ScribblesNScriptsTests`
- App entry and workspace coordinator architecture in place
- Directory organization aligned to AGENTS “File Organization”

### 3.2 Core Model + Project I/O
- Data model structs/enums created from PROJECT-BIBLE Section 3 with Codable/Identifiable/CaseIterable constraints where appropriate
- Project I/O module implemented:
  - project create/open/close/save lifecycle
  - manifest encode/decode
  - atomic writes
  - lock file semantics
  - scene markdown content handling (raw markdown)
  - backup create/list/prune/restore
  - safety hardening across many edge cases (malformed files, stale locks, restore path validation, symlink handling, manifest validation, etc.)

### 3.3 Editor/Navigation/Modeing/Growth Modules
Major module surfaces have been implemented with tests, including:
- editor core behavior
- sidebar/navigation hierarchy and actions
- linear mode
- modular mode
- mode switching
- split editor
- snapshots
- goals/session tracking
- workspace command bindings

### 3.4 Search & Replace (Current Advanced State)
Implemented and tested:
- inline and project search
- next/previous navigation through results
- select result -> scene navigation/selection
- replace next
- replace all
- search highlighting with active match

Then iteratively hardened with UX/perf controls:
- highlight cap (default 100)
- show-all toggle
- safety threshold for show-all (default 2000 active-scene matches)
- auto fallback from show-all when threshold exceeded
- persisted highlight prefs in UserDefaults
- reset highlight prefs to defaults
- Find menu shortcuts for highlight controls
- learn-more popover/help + inline explanations

Most recent additions (latest finish point):
- scene-level replace preview list (by scene with match counts)
- per-scene include/exclude checkboxes for Replace All scope
- include all / exclude all preview scenes
- replace confirmation reflects selected scenes vs total matched scenes
- replace action guarded for empty selection
- replace selection persistence modes:
  - Reset on Search
  - Keep Manual Selection
- quick helper: select scenes with >N matches
- Find menu bulk commands:
  - Include All Preview Scenes (`Option+Command+I`)
  - Exclude All Preview Scenes (`Option+Command+U`)
- updated shortcut help row in Find panel

## 4. Critical Decisions and Conventions

### 4.1 Safety-First I/O
- Writes are atomic
- lock ownership and stale lock handling are explicit
- backup restore path/symlink traversal protections are strict
- tests prioritize regression prevention for data loss/corruption paths

### 4.2 Coordinator-Centric App Layer
- `WorkspaceCoordinator` owns cross-feature app state
- `WorkspaceCommandBindings` acts as command/menu facade
- SwiftUI views bind into coordinator/bindings

### 4.3 Testing Philosophy Used
- heavy regression-style tests for edge-case behavior
- temporary directories + isolated UserDefaults suites where needed
- preference-key cleanup in tests to avoid hidden state bleed
- test additions accompany every behavior change

## 5. Current Repository State
Latest completed commit on `main`:
- `2d1037a` - Add replace selection modes, threshold helper, and find bulk commands

Recent preceding milestone commits include:
- selectable replace preview scenes + shortcut guidance
- find reset command + help state test + replace scene preview
- learn-more popover for highlight settings
- reset-to-default highlight preferences
- persisted highlight cap/safety preferences
- safe show-all toggle + command shortcut

All currently passing at last verification:
- `swift build`
- `swift test`
- total tests passing: **267**

## 6. Where We Are in the Full Build Scheme
Status: **late foundation / early product-hardening phase**

Meaning:
- core architecture and many module contracts are implemented
- broad behavior coverage exists
- app is now in a quality-and-depth cycle for UX safety, predictability, and advanced workflows (not just scaffolding)

What is still likely ahead in the full product journey:
- deeper workflow UX polish
- additional persistence/configuration options
- broader command coverage and discoverability
- higher-level feature completeness against full vision (compile/export pipeline, richer formatting workflows, etc., depending on remaining specs)

## 7. Immediate Next Grapples (Recommended Order)

1. Replace Preview clarity + safety polish
- Add stronger visual distinction for excluded scenes (badge/state color/icon)
- Make selected/total summary more prominent
- Reduce accidental destructive replaces via clearer confirmation copy

2. Persist replace-selection mode preference
- Store `Replace Scene Selection Mode` in UserDefaults
- Restore on launch/new project session
- Add tests for persistence and default behavior

3. Undo surface for Replace All batches
- expose “Undo last replace batch” at UI level
- ensure it respects selected-scene batch semantics
- add tests for chained replace/undo behavior

Secondary candidates:
- command discoverability polish (menu labels/help)
- richer quick-select expressions beyond `>N`
- lightweight performance tests for large projects/search datasets

## 8. Practical Restart Prompt for a New Chat
Use this exactly (or close):

"Read `docs/FOUNDING-CONTEXT.md` first, then continue from commit `2d1037a` on `main`. Prioritize the next grapple list in order: (1) excluded-scene preview clarity, (2) persistence of replace-selection mode, (3) UI-level undo for replace-all batches with tests. Keep coordinator+bindings architecture and regression-test style consistent with existing codebase. Run `swift build` and `swift test` before finalizing."

## 9. Working Constraints to Maintain
- Do not weaken file I/O safety invariants.
- Keep feature changes covered by tests.
- Avoid destructive git operations.
- Preserve current architecture pattern (coordinator + command bindings + SwiftUI view composition).
- Keep UX additions explicit about impact before destructive actions.

## 10. Bottom Line
The project is no longer at scaffold stage. It is in a disciplined hardening-and-expansion stage with strong tests, a stable architecture, and an increasingly robust Find/Replace system. The next most valuable progress is focused safety/UX refinement and persistence polish around replacement workflows.
