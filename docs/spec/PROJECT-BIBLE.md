# Manuscript — Project Bible
## Core Reference for AI-Assisted Development

> **Purpose**: This document is the single source of truth included as context in every AI prompt during development. It contains the data model, file format specification, design constraints, glossary, and dependency map. Individual module specs reference this document rather than redefining shared concepts.

---

## 1. Product Identity

**Name**: Manuscript
**Platform**: macOS (primary), Windows (future)
**Language**: Swift + SwiftUI
**Architecture**: Monolithic, local-only, no network dependencies
**Editor Model**: Plain text with live Markdown rendering
**Project Format**: Open directory structure (Markdown + JSON), optionally bundled as `.manuscript` ZIP archive

---

## 2. Design Principles (Binding Constraints)

These are not aspirational — they are hard constraints that override feature requests.

| ID | Principle | Constraint |
|----|-----------|------------|
| DP-1 | Performance First | Typing latency ≤16ms. Project open ≤2s for 100K words. No full-manuscript memory load. |
| DP-2 | Writer's Mental Model | All UI concepts map to writing concepts (scene, chapter, card) — never to software concepts (file, record, node). |
| DP-3 | Local Ownership | Zero network calls. No accounts. No telemetry. Project format is human-readable without the app. |
| DP-4 | Progressive Complexity | Core writing works with zero configuration. Power features are discoverable but never obstruct. |
| DP-5 | Keyboard First | Every action reachable via keyboard. Command palette is the universal entry point. |
| DP-6 | Non-Destructive | No user action permanently destroys content. Deletes go to trash. Restores auto-snapshot first. |

---

## 3. Data Model — Swift Struct Definitions

These are the canonical type definitions. All module specs consume these types. Field names, types, and optionality are binding.

```swift
import Foundation

// MARK: - Core Content Hierarchy

struct Project {
    let id: UUID
    var name: String
    var manuscript: Manuscript
    var settings: ProjectSettings
    var tags: [Tag]
    var snapshots: [Snapshot]
    var entities: [Entity]          // v1.1
    var sources: [Source]           // v1.1 lightweight, v2.0 full
    var notes: [Note]              // v2.0
    var compilePresets: [CompilePreset]  // v2.0
    var trash: [TrashedItem]
    let createdAt: Date
    var modifiedAt: Date
}

struct Manuscript {
    let id: UUID
    var title: String
    var parts: [Part]              // Optional grouping layer; may be empty
    var chapters: [Chapter]        // If parts are unused, chapters live here directly
    var stagingArea: [Scene]       // Scenes not yet assigned to a chapter (modular mode)
}

struct Part {
    let id: UUID
    var title: String
    var synopsis: String           // Visible in outliner/cards, excluded from manuscript
    var chapters: [Chapter]        // Ordered
    var sequenceIndex: Int         // Position within manuscript
}

struct Chapter {
    let id: UUID
    var title: String
    var synopsis: String
    var scenes: [Scene]            // Ordered
    var status: ContentStatus
    var sequenceIndex: Int         // Position within parent (Part or Manuscript)
    var goalWordCount: Int?        // Optional per-chapter target
}

struct Scene {
    let id: UUID
    var title: String
    var content: String            // Raw Markdown text
    var synopsis: String           // Short summary for cards/outliner
    var status: ContentStatus
    var tags: [UUID]               // References to Tag.id
    var colorLabel: ColorLabel?
    var metadata: [String: String] // User-defined key-value pairs
    var sequenceIndex: Int         // Position within parent Chapter
    var wordCount: Int             // Computed on save, cached in metadata
    let createdAt: Date
    var modifiedAt: Date
}

enum ContentStatus: String, Codable, CaseIterable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case firstDraft = "First Draft"
    case revised = "Revised"
    case final_ = "Final"
}

enum ColorLabel: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, gray, none
}

// MARK: - Metadata & Organization

struct Tag {
    let id: UUID
    var name: String               // Unique within project
    var color: String?             // Hex color string, optional
}

struct CustomMetadataField {
    let id: UUID
    var name: String               // e.g., "POV Character", "Setting"
    var fieldType: MetadataFieldType
}

enum MetadataFieldType: String, Codable {
    case text
    case singleSelect              // Predefined options
    case multiSelect
}

// MARK: - Version Control

struct Snapshot {
    let id: UUID
    var name: String               // User-provided label
    let createdAt: Date
    var wordCount: Int             // Total manuscript words at snapshot time
    var isBaseline: Bool           // True for the first (full-copy) snapshot
    // Storage: baseline = full copy; subsequent = diff against previous
}

struct SnapshotDiff {
    let snapshotId: UUID
    var sceneDiffs: [SceneDiff]
    var hierarchyChanges: HierarchyDiff
}

struct SceneDiff {
    let sceneId: UUID
    var changeType: DiffChangeType
    var textDiff: String?          // Unified diff format for content changes
}

enum DiffChangeType: String, Codable {
    case added, removed, modified, unchanged
}

struct HierarchyDiff {
    var addedScenes: [UUID]
    var removedScenes: [UUID]
    var reorderedChapters: [(chapterId: UUID, oldIndex: Int, newIndex: Int)]
    var reorderedScenes: [(sceneId: UUID, oldChapterId: UUID, newChapterId: UUID, oldIndex: Int, newIndex: Int)]
}

// MARK: - Trash

struct TrashedItem {
    let id: UUID
    var originalType: TrashedItemType
    var originalParentId: UUID?
    var originalIndex: Int
    var content: Any               // The full Scene, Chapter, or Part object
    let trashedAt: Date
}

enum TrashedItemType: String, Codable {
    case scene, chapter, part
}

// MARK: - Entity Tracking (v1.1)

struct Entity {
    let id: UUID
    var entityType: EntityType
    var name: String
    var aliases: [String]          // Alternative names for @-mention matching
    var fields: [String: String]   // Custom fields (e.g., "Appearance", "Role")
    var sceneMentions: [UUID]      // Scene IDs where this entity is @-mentioned
    var relationships: [EntityRelationship]
    var notes: String              // Freeform notes about this entity
}

enum EntityType: String, Codable {
    case character, location, object, faction, concept, custom
}

struct EntityRelationship {
    let targetEntityId: UUID
    var label: String              // e.g., "sibling of", "located in"
    var isBidirectional: Bool
}

// MARK: - Timeline (v1.1)

struct TimelineEvent {
    let id: UUID
    var title: String
    var description: String
    var track: String              // e.g., "Main Plot", "Character Arc: Jane"
    var position: TimelinePosition
    var linkedSceneIds: [UUID]
    var color: String?             // Hex color
}

enum TimelinePosition {
    case absolute(Date)
    case relative(order: Int)      // Integer ordering within track
}

// MARK: - Sources & Citations (v1.1 lightweight → v2.0 full)

struct Source {
    let id: UUID
    var title: String
    var author: String?
    var date: String?              // Freeform date string
    var url: String?
    var publication: String?       // v2.0
    var volume: String?            // v2.0
    var pages: String?             // v2.0
    var doi: String?               // v2.0
    var notes: String
    var citationKey: String        // Short key for inline refs, e.g., "smith2024"
}

// MARK: - Notes (v2.0)

struct Note {
    let id: UUID
    var title: String
    var content: String            // Markdown
    var folder: String?            // User-defined folder name
    var tags: [UUID]
    var linkedSceneIds: [UUID]     // Bidirectional links to scenes
    var attachments: [NoteAttachment]
    let createdAt: Date
    var modifiedAt: Date
}

struct NoteAttachment {
    let id: UUID
    var filename: String
    var mimeType: String
    // Stored in project directory: notes/attachments/{id}/{filename}
}

// MARK: - Export & Compile (v1.1 basic → v2.0 full)

struct CompilePreset {
    let id: UUID
    var name: String               // e.g., "Manuscript Submission"
    var format: ExportFormat
    var includedSectionIds: [UUID] // Ordered list of Part/Chapter IDs to include
    var styleOverrides: StyleConfig
    var frontMatter: FrontMatterConfig
    var backMatter: BackMatterConfig
}

enum ExportFormat: String, Codable {
    case markdown, docx, pdf, epub, html
}

struct StyleConfig {
    var fontFamily: String         // e.g., "Times New Roman"
    var fontSize: Int              // Points
    var lineSpacing: Double        // e.g., 2.0 for double-spaced
    var paragraphIndent: Double    // Inches
    var chapterHeadingStyle: String
    var sceneBreakMarker: String   // e.g., "***", "# # #"
    var pageMargins: Margins
}

struct Margins {
    var top: Double                // Inches
    var bottom: Double
    var left: Double
    var right: Double
}

struct FrontMatterConfig {
    var includeTitlePage: Bool
    var includeCopyright: Bool
    var includeDedication: Bool
    var includeTableOfContents: Bool
    var titlePageContent: TitlePageContent?
    var copyrightText: String?
    var dedicationText: String?
}

struct TitlePageContent {
    var title: String
    var subtitle: String?
    var author: String
}

struct BackMatterConfig {
    var includeAppendices: Bool
    var includeAboutAuthor: Bool
    var includeBibliography: Bool  // v2.0
    var aboutAuthorText: String?
    var appendices: [AppendixEntry]
}

struct AppendixEntry {
    var title: String
    var content: String            // Markdown
}

// MARK: - Project Settings

struct ProjectSettings {
    var autosaveIntervalSeconds: Int       // Default: 30
    var backupIntervalMinutes: Int         // Default: 30
    var backupRetentionCount: Int          // Default: 20
    var backupLocation: String?            // nil = alongside project
    var customMetadataFields: [CustomMetadataField]
    var customStatusOptions: [String]?     // nil = use ContentStatus defaults
    var editorFont: String                 // Default: "Menlo"
    var editorFontSize: Int                // Default: 14
    var editorLineHeight: Double           // Default: 1.6
    var theme: AppTheme                    // Default: .system
    var defaultColorLabelNames: [ColorLabel: String]  // User-defined label names
}

enum AppTheme: String, Codable {
    case light, dark, system
}
```

---

## 4. File Format Specification

### 4.1 Directory Structure (Canonical)

```
project-name/
├── manifest.json               # Project metadata, hierarchy, settings
├── content/
│   ├── ch-{uuid}/
│   │   ├── scene-{uuid}.md     # Scene content (raw Markdown)
│   │   ├── scene-{uuid}.md
│   │   └── ...
│   ├── ch-{uuid}/
│   │   └── ...
│   └── staging/                # Unassigned scenes (modular mode)
│       └── scene-{uuid}.md
├── metadata/
│   ├── tags.json               # Tag definitions
│   ├── entities.json           # Entity profiles (v1.1)
│   ├── sources.json            # Source library (v1.1/v2.0)
│   ├── timeline.json           # Timeline events (v1.1)
│   ├── presets.json            # Compile presets (v2.0)
│   └── snapshots/
│       ├── snap-{uuid}.json    # Snapshot metadata + diff
│       └── baselines/
│           └── snap-{uuid}/    # Full copy for baseline snapshots
├── notes/                      # v2.0
│   ├── note-{uuid}.md
│   └── attachments/
│       └── {uuid}/
│           └── filename.ext
├── research/                   # Imported reference files (v1.1)
│   └── (user-organized files)
├── backups/                    # Timestamped automatic backups
│   └── backup-{ISO8601}.zip
└── .manuscript-version         # File format version (semver string)
```

### 4.2 manifest.json Schema

```json
{
  "$schema": "manuscript-manifest-v1",
  "formatVersion": "1.0.0",
  "project": {
    "id": "uuid",
    "name": "string",
    "createdAt": "ISO8601",
    "modifiedAt": "ISO8601"
  },
  "hierarchy": {
    "parts": [
      {
        "id": "uuid",
        "title": "string",
        "synopsis": "string",
        "sequenceIndex": 0,
        "chapters": ["chapter-uuid-ref"]
      }
    ],
    "chapters": [
      {
        "id": "uuid",
        "title": "string",
        "synopsis": "string",
        "status": "ContentStatus.rawValue",
        "sequenceIndex": 0,
        "parentPartId": "uuid | null",
        "goalWordCount": "int | null",
        "scenes": ["scene-uuid-ref"]
      }
    ],
    "scenes": [
      {
        "id": "uuid",
        "title": "string",
        "synopsis": "string",
        "status": "ContentStatus.rawValue",
        "tags": ["tag-uuid-ref"],
        "colorLabel": "ColorLabel.rawValue | null",
        "metadata": { "key": "value" },
        "sequenceIndex": 0,
        "parentChapterId": "uuid | null",
        "wordCount": 0,
        "filePath": "content/ch-{uuid}/scene-{uuid}.md",
        "createdAt": "ISO8601",
        "modifiedAt": "ISO8601"
      }
    ],
    "stagingScenes": ["scene-uuid-ref"]
  },
  "settings": {
    "// See ProjectSettings struct — serialized directly"
  }
}
```

### 4.3 File Format Rules

| Rule | Specification |
|------|---------------|
| Scene content files | Raw Markdown. No YAML front matter. No metadata in the .md file — all metadata lives in manifest.json. |
| UUIDs | v4, lowercase, hyphenated (e.g., `550e8400-e29b-41d4-a716-446655440000`). |
| Encoding | UTF-8 for all text files. |
| Line endings | LF (`\n`), never CRLF. |
| Format versioning | `.manuscript-version` contains a semver string. The app refuses to open projects with a major version higher than it supports and offers migration for minor version mismatches. |
| Bundle format | `.manuscript` file = ZIP archive of the project directory. Extension is cosmetic — standard ZIP tools can open it. |

---

## 5. Glossary (Binding Terminology)

Use these terms exactly in all code, UI, and documentation. Do not use synonyms.

| Term | Definition | Code Type |
|------|-----------|-----------|
| **Project** | The top-level container. One project = one writing endeavor. | `Project` |
| **Manuscript** | The content body of the project. Contains the hierarchy of parts, chapters, and scenes. | `Manuscript` |
| **Part** | Optional grouping of chapters (e.g., "Part I: The Beginning"). May be unused. | `Part` |
| **Chapter** | An ordered group of scenes. The primary structural division. | `Chapter` |
| **Scene** | The atomic content unit. A discrete block of prose. The smallest independently editable, taggable, movable piece. | `Scene` |
| **Synopsis** | A short text summary attached to a scene, chapter, or part. Visible in outliner and cards. Excluded from compiled output. | `String` field |
| **Linear Mode** | View mode presenting the manuscript as sequential prose. Mental model: reading a book. | UI state |
| **Modular Mode** | View mode presenting scenes as spatial cards. Mental model: index cards on a desk. | UI state |
| **Staging Area** | Holding space for scenes not yet assigned to a chapter. Visible only in modular mode. | `Manuscript.stagingArea` |
| **Snapshot** | A named, timestamped capture of the full manuscript state. Writer-friendly version control. | `Snapshot` |
| **Tag** | A freeform label assignable to scenes. Used for filtering and organization. | `Tag` |
| **Color Label** | One of 8 color indicators assignable to a scene. User-defined meaning (e.g., red = "Needs Research"). | `ColorLabel` |
| **Entity** | A tracked recurring element: character, location, object, etc. Has a profile and manuscript mention links. (v1.1) | `Entity` |
| **Source** | A bibliographic reference in the source library. Linkable via inline citation markers. (v1.1/v2.0) | `Source` |
| **Compile** | The process of assembling selected scenes/chapters into a formatted output file. (v1.1 basic / v2.0 full) | Function |
| **Command Palette** | Cmd+K searchable action launcher. Universal entry point for all app functions. | UI component |
| **Inspector Panel** | Right-side panel showing contextual information (scene metadata, entity details, notes). Toggleable. | UI component |

---

## 6. Dependency Map & Build Order

Each module lists what it **requires** (must be built first) and what it **exposes** (interfaces other modules consume).

```
┌─────────────────────────────────────────────────────────┐
│  BUILD ORDER (MVP)                                       │
│                                                          │
│  ① Project I/O ──→ ② Editor ──→ ③ Sidebar/Nav           │
│                         │                                │
│                         ▼                                │
│               ④ Multi-Scene Linear ──→ ⑥ Mode Switch     │
│                                            │             │
│               ⑤ Modular Card View ─────────┘             │
│                                                          │
│  ⑦ Snapshots ──→ ⑧ Tags/Metadata ──→ ⑨ Find/Replace    │
│                                                          │
│  ⑩ Split Editor       ⑪ Writing Goals                   │
│  (depends on ②④)      (depends on ①②)                   │
└─────────────────────────────────────────────────────────┘
```

| Step | Module | Requires | Exposes |
|------|--------|----------|---------|
| 1 | Project I/O | — (foundation) | `ProjectManager` protocol: `createProject()`, `openProject(url:)`, `saveProject()`, `loadSceneContent(id:)`, `saveSceneContent(id:, content:)`, manifest read/write |
| 2 | Editor | Project I/O | `EditorView`, `EditorState` (current scene ID, cursor position, selection), Markdown parser, word count computation |
| 3 | Sidebar & Navigation | Project I/O | `SidebarView`, `NavigationState` (current location in hierarchy), reorder operations on manifest |
| 4 | Multi-Scene Linear Mode | Editor, Sidebar | `LinearModeView`, sequential scene navigation, scene boundary rendering |
| 5 | Modular Card View | Project I/O, Sidebar | `ModularModeView`, card layout, drag-and-drop reorder, filter engine |
| 6 | Mode Switching | Linear Mode, Modular Mode | `ModeController` (switch mode preserving position, bidirectional position mapping) |
| 7 | Snapshots | Project I/O | `SnapshotManager`: create, list, diff, restore. Diff engine (text + hierarchy). |
| 8 | Tags & Metadata | Project I/O, Sidebar | `TagManager`, `MetadataManager`, filter predicates consumable by Sidebar and Modular Mode |
| 9 | Find & Replace | Editor, Project I/O | `SearchEngine`: project-wide indexed search, regex, scoped search, replace operations |
| 10 | Split Editor | Editor, Linear Mode | `SplitEditorView`: two independent editor panes, synchronized scroll option |
| 11 | Writing Goals | Project I/O, Editor | `GoalsManager`: session/project/chapter goals, history logging, statistics computation |

---

## 7. Cross-Cutting Concerns

These apply to every module. Include in every module prompt.

### 7.1 Error Handling
- All file I/O operations must handle: file not found, permission denied, disk full, corrupted JSON, corrupted Markdown.
- Errors surface as non-modal alerts with a "Details" expansion. Never crash. Never silently discard data.
- On corrupted project open: show specific corruption details and offer to open in recovery mode (read-only with corrupted sections flagged).

### 7.2 Undo/Redo
- All content mutations (edits, reorders, tag changes, metadata changes, deletes) are undoable.
- Undo stack is per-document, persisted in memory during session, and flushed to the project file on autosave.
- Structural changes (reorder chapters, move scene between chapters) are single undo operations, not multi-step.

### 7.3 Performance Budgets
| Operation | Budget |
|-----------|--------|
| Keystroke to render | ≤ 16ms |
| Mode switch | ≤ 200ms |
| Project open (100K words) | ≤ 2s |
| Project open (300K words) | ≤ 5s |
| Search index build (100K words) | ≤ 3s (async, non-blocking) |
| Snapshot creation | ≤ 1s |
| Autosave | ≤ 500ms (non-blocking) |

### 7.4 Accessibility
- All custom views support VoiceOver with descriptive labels.
- All interactive elements are keyboard-navigable.
- Color is never the sole indicator of state (always paired with text or icon).
- Respect macOS system settings: reduced motion, increased contrast, font size.

---

## 8. Release Scope Summary

### v1.0 (MVP)
Modules 1–11: Editor, dual-mode, project structure, file I/O, snapshots, tags/metadata, find/replace, split editor, writing goals, UI foundation.

### v1.1
Outliner, corkboard upgrade, timeline, entity tracking, basic export (Markdown/DOCX/PDF), import (DOCX/MD/TXT), lightweight citations.

### v2.0
Full compile system, EPUB, stylesheet engine, notes system, full source library, scratchpad/clipboard manager.
