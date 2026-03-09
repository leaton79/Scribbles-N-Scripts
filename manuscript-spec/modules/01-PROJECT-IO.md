# Module 01: Project I/O
## Manuscript — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Nothing (foundation module)
> **Exposes**: `ProjectManager` protocol consumed by every other module

---

## 1. Purpose

This module handles all persistence: creating, opening, saving, and reading project files. It owns the manifest.json and the directory structure. Every other module accesses project data through this module's interface — no module reads or writes files directly.

---

## 2. Interface Specification

```swift
protocol ProjectManager {
    // Project lifecycle
    func createProject(name: String, at url: URL) throws -> Project
    func openProject(at url: URL) throws -> Project
    func closeProject() throws
    
    // Manifest operations
    func saveManifest() throws
    func getManifest() -> Manifest
    
    // Scene content (loaded on demand, not at project open)
    func loadSceneContent(sceneId: UUID) throws -> String
    func saveSceneContent(sceneId: UUID, content: String) throws
    
    // Hierarchy mutations
    func addScene(to chapterId: UUID, at index: Int?, title: String) throws -> Scene
    func addChapter(to partId: UUID?, at index: Int?, title: String) throws -> Chapter
    func addPart(at index: Int?, title: String) throws -> Part
    func moveScene(sceneId: UUID, toChapterId: UUID, atIndex: Int) throws
    func moveChapter(chapterId: UUID, toPartId: UUID?, atIndex: Int) throws
    func moveToStaging(sceneId: UUID) throws
    func deleteItem(id: UUID, type: TrashedItemType) throws  // Moves to trash
    func restoreFromTrash(trashedItemId: UUID) throws
    func emptyTrash() throws
    
    // Backup
    func createBackup() throws
    func listBackups() -> [BackupInfo]
    func restoreFromBackup(backupId: String) throws -> Project
    
    // Metadata updates (convenience — writes to manifest)
    func updateSceneMetadata(sceneId: UUID, updates: SceneMetadataUpdate) throws
    func updateChapterMetadata(chapterId: UUID, updates: ChapterMetadataUpdate) throws
    
    // Autosave
    func startAutosave(intervalSeconds: Int)
    func stopAutosave()
    
    // State
    var currentProject: Project? { get }
    var isDirty: Bool { get }  // Unsaved changes exist
}

struct BackupInfo {
    let filename: String
    let date: Date
    let sizeBytes: Int64
}

struct SceneMetadataUpdate {
    var title: String?
    var synopsis: String?
    var status: ContentStatus?
    var tags: [UUID]?
    var colorLabel: ColorLabel?
    var metadata: [String: String]?
}

struct ChapterMetadataUpdate {
    var title: String?
    var synopsis: String?
    var status: ContentStatus?
    var goalWordCount: Int?
}
```

---

## 3. Behavioral Specification

### 3.1 Project Creation
- **Given** a project name "My Novel" and a directory URL
- **When** `createProject` is called
- **Then** the full directory structure from PROJECT-BIBLE §4.1 is created, manifest.json is populated with defaults, one empty chapter ("Chapter 1") with one empty scene ("Untitled Scene") is created, `.manuscript-version` contains the current format version, and the project is returned in an open state.

### 3.2 Project Open
- **Given** a valid project directory URL
- **When** `openProject` is called
- **Then** manifest.json is parsed and validated, the full metadata index is loaded into memory (all scene metadata — titles, tags, status, word counts, UUIDs — but NOT scene content text), `.manuscript-version` is checked for compatibility, and the project is returned ready for navigation.

- **Given** a project with a higher major format version
- **When** `openProject` is called
- **Then** an `IncompatibleVersionError` is thrown with the project's version and the app's supported version.

- **Given** a project with a higher minor format version
- **When** `openProject` is called
- **Then** a migration is offered. If accepted, the manifest is updated and a backup is created first. If declined, the project opens in read-only mode.

### 3.3 Scene Content Loading
- **Given** an open project and a valid scene UUID
- **When** `loadSceneContent` is called
- **Then** the .md file at the path specified in the manifest is read and returned as a String.
- **Performance**: ≤50ms for scenes up to 50,000 characters.

- **Given** a scene UUID whose file is missing on disk
- **When** `loadSceneContent` is called
- **Then** a `SceneContentMissingError` is thrown containing the scene's title and expected file path. The scene metadata remains valid in the manifest.

### 3.4 Hierarchy Mutations
- **Given** a `moveScene` call
- **When** the scene is moved from Chapter A to Chapter B at index 2
- **Then** the scene's `parentChapterId` is updated, `sequenceIndex` values in both chapters are recalculated (gap-free, starting from 0), the scene's .md file is moved from `content/ch-{A}/` to `content/ch-{B}/`, `manifest.json` is updated, and `isDirty` becomes true.

- **Given** a `deleteItem` call on a scene
- **When** the scene is deleted
- **Then** a `TrashedItem` is created capturing the full scene metadata and its original position, the .md file is NOT deleted from disk (it stays in place until trash is emptied), the scene is removed from the manifest hierarchy, and word counts are recalculated for the parent chapter.

### 3.5 Autosave
- **Given** autosave is running with a 30-second interval
- **When** 30 seconds elapse and `isDirty` is true
- **Then** the manifest and any modified scene content are saved. The save operation runs on a background thread and does not block the UI. If save fails, a non-modal error is queued for display.

- **Given** autosave is running
- **When** `isDirty` is false at the interval tick
- **Then** no save occurs (skip the cycle).

### 3.6 Backup
- **Given** a backup is triggered
- **When** `createBackup` is called
- **Then** the entire project directory is ZIP-compressed into `backups/backup-{ISO8601}.zip`. If the backup count exceeds `settings.backupRetentionCount`, the oldest backup(s) are deleted. Backup runs on a background thread.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Manifest JSON is malformed | Throw `CorruptManifestError` with parse error details. Offer recovery: attempt to reconstruct manifest from directory structure (scan for .md files, infer hierarchy from directory names). |
| Scene .md file has encoding issues | Attempt UTF-8 read. If invalid bytes found, read as Latin-1 fallback and flag the scene with a warning. Never discard content. |
| Disk full during save | Catch `NSFileWriteOutOfSpaceError`. Alert user. Do not leave partially-written files — use write-to-temp-then-rename (atomic write) for all file operations. |
| Two scenes have the same UUID | Detected at project open. Log warning, assign a new UUID to the duplicate, save immediately. |
| Moving a scene to its current location | No-op. Do not mark as dirty. |
| Empty chapter after last scene deleted | Chapter persists (empty chapters are valid). User must explicitly delete the chapter. |
| Project directory renamed externally | The app tracks the project by its open URL. If the directory is renamed while open, saves may fail. Detect and prompt user to re-locate. |
| Concurrent access (two app instances) | Not supported. On project open, create a `.lock` file. If lock exists, warn user and offer read-only mode. Remove lock on close. Handle stale locks (check process ID if recorded). |

---

## 5. Test Cases

```
TEST: Create project creates correct directory structure
  GIVEN a temp directory
  WHEN createProject(name: "Test", at: tempDir) is called
  THEN tempDir/Test/ exists
  AND tempDir/Test/manifest.json is valid JSON matching schema
  AND tempDir/Test/content/ directory exists
  AND tempDir/Test/metadata/ directory exists
  AND tempDir/Test/backups/ directory exists
  AND tempDir/Test/.manuscript-version contains "1.0.0"
  AND manifest contains exactly 1 chapter with 1 scene

TEST: Open project loads metadata but not content
  GIVEN a project with 50 scenes totaling 100,000 words
  WHEN openProject is called
  THEN all 50 scene metadata entries are accessible
  AND no scene content has been loaded (verify loadSceneContent not called)
  AND openProject completes in ≤2 seconds

TEST: Move scene updates both chapters correctly
  GIVEN Chapter A with scenes [S1, S2, S3] and Chapter B with scenes [S4, S5]
  WHEN moveScene(S2, to: ChapterB, atIndex: 1)
  THEN Chapter A contains [S1, S3] with sequenceIndex [0, 1]
  AND Chapter B contains [S4, S2, S5] with sequenceIndex [0, 1, 2]
  AND S2's file exists in content/ch-{B}/
  AND S2's file does NOT exist in content/ch-{A}/

TEST: Delete scene creates trash entry and preserves file
  GIVEN Chapter A with scene S1
  WHEN deleteItem(S1, type: .scene)
  THEN S1 is not in manifest hierarchy
  AND trash contains an entry for S1 with correct originalParentId and originalIndex
  AND the .md file still exists on disk

TEST: Restore from trash puts scene back in original position
  GIVEN a trashed scene S1 that was at index 2 in Chapter A
  AND Chapter A now has 4 scenes
  WHEN restoreFromTrash(S1.trashedId)
  THEN S1 is at index 2 in Chapter A (other scenes shift)
  AND trash no longer contains S1

TEST: Atomic save does not corrupt on interruption
  GIVEN an open project with unsaved changes
  WHEN save is interrupted (simulate by filling disk during write)
  THEN the previous valid manifest.json remains intact
  AND no partial manifest.json exists

TEST: Autosave skips when not dirty
  GIVEN autosave running at 5-second interval (test config)
  AND no changes have been made
  WHEN 5 seconds elapse
  THEN no file write operations occur

TEST: Lock file prevents concurrent access
  GIVEN an open project with a .lock file
  WHEN a second openProject call targets the same directory
  THEN an error is thrown offering read-only mode
```

---

## 6. Implementation Notes

- Use `FileManager` for all directory operations. Use `Data.write(to:options:.atomic)` for all file writes to ensure atomicity.
- Manifest should be the single source of truth for hierarchy and metadata. Scene .md files contain only content — never embed metadata in Markdown front matter.
- Consider using `NSFileCoordinator` for file access to cooperate with Finder and Spotlight.
- Word count computation: count words in scene content on save. Store in manifest. This avoids needing to load all scene content to display word counts in the sidebar.
- The `isDirty` flag should be granular: track which specific scenes have unsaved content changes and whether the manifest has unsaved changes, to minimize I/O on autosave.
