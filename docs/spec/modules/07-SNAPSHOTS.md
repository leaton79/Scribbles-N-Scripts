# Module 07: Snapshots (Version Control)
## Scribbles-N-Scripts — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 01 (Project I/O) — reads/writes snapshot files, accesses scene content
> **Exposes**: `SnapshotManager` — create, list, diff, restore

---

## 1. Purpose

Writer-friendly version control. Named, timestamped captures of the full manuscript state. Supports comparison between any two snapshots and safe restoration. Not git — no branches, no merges, no commits. Just "save this moment" and "compare two moments."

---

## 2. Interface Specification

```swift
protocol SnapshotManager {
    func createSnapshot(name: String) throws -> Snapshot
    func listSnapshots() -> [Snapshot]               // Sorted by date, newest first
    func deleteSnapshot(id: UUID) throws
    
    func diff(snapshotA: UUID, snapshotB: UUID) throws -> ManuscriptDiff
    func diffWithCurrent(snapshotId: UUID) throws -> ManuscriptDiff
    
    func restore(snapshotId: UUID) throws            // Auto-snapshots current state first
}

struct ManuscriptDiff {
    let snapshotA: SnapshotSummary
    let snapshotB: SnapshotSummary
    var sceneDiffs: [SceneComparisonResult]
    var hierarchyChanges: HierarchyDiff              // From PROJECT-BIBLE
    var wordCountDelta: Int                           // B.wordCount - A.wordCount
}

struct SnapshotSummary {
    let id: UUID
    let name: String
    let date: Date
    let wordCount: Int
}

struct SceneComparisonResult {
    let sceneId: UUID
    let sceneTitle: String
    var changeType: DiffChangeType                    // added, removed, modified, unchanged
    var lineDiffs: [LineDiff]?                        // nil if unchanged or added/removed wholesale
}

struct LineDiff {
    let lineNumber: Int
    let type: LineDiffType
    let text: String
}

enum LineDiffType {
    case added, removed, unchanged, modified
}
```

---

## 3. Behavioral Specification

### 3.1 Create Snapshot
- **Given** user triggers Cmd+Shift+S or menu > Snapshots > Create Snapshot
- **When** a dialog prompts for a name
- **Then** entering a name (e.g., "Before Act 2 restructure") creates a snapshot: all scene content is captured (first snapshot = full copy; subsequent = diff against the most recent snapshot), the manifest hierarchy is captured, word count at this moment is recorded, and the snapshot appears in the snapshot list.
- **Performance**: ≤1s for a 100K-word manuscript.

### 3.2 Diff View
- **Given** user selects two snapshots in the snapshot panel
- **When** "Compare" is clicked
- **Then** a diff view opens showing: a list of scenes grouped by change type (Added, Removed, Modified, Unchanged), and clicking a modified scene shows an inline diff with red (removed) and green (added) highlighted lines.

- **Given** user selects one snapshot and clicks "Compare with Current"
- **When** the comparison is generated
- **Then** snapshot B is the current manuscript state (not a saved snapshot). All unsaved changes are included in the comparison.

### 3.3 Restore
- **Given** user selects a snapshot and clicks "Restore"
- **When** a confirmation dialog appears ("This will revert your manuscript to '[snapshot name]'. Your current state will be saved as an automatic snapshot first. Continue?")
- **Then** on confirm: (1) An automatic snapshot named "Auto-save before restoring '[name]'" is created. (2) The manuscript content and hierarchy are reverted to the selected snapshot's state. (3) The project reloads in the editor showing the restored content.

- **Critical constraint**: The user can NEVER lose work by restoring. The auto-snapshot-before-restore is mandatory and non-skippable.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| First snapshot ever | Stored as a full copy (baseline). All subsequent snapshots are diffs against the most recent baseline or snapshot. |
| Snapshot of a 300K-word manuscript | Baseline (full copy) may be 1–2 MB. Diffs are typically <100 KB. Acceptable for local storage. |
| Scene deleted between snapshots | Diff shows the scene as "Removed" with full content visible in the diff (from the older snapshot). |
| Scene added between snapshots | Diff shows the scene as "Added" with full content visible. |
| Scene UUID collision after restore | Should not occur — restore replaces manifest and content wholesale. UUIDs are preserved from the snapshot. |
| Snapshot with missing diff chain | If an intermediate snapshot is deleted and the diff chain breaks, fall back to a full comparison (load both snapshot states and diff directly). This is slower but always works. |
| Snapshot name already used | Allow duplicate names. Snapshots are identified by UUID, not name. |
| 50+ snapshots accumulated | No enforced limit. Offer a "Clean up old snapshots" action that lists snapshots and lets the user delete in bulk. |
| Restore when current state is identical to snapshot | Detect this case. Skip restore, show "Your manuscript is already identical to this snapshot." |

---

## 5. Test Cases

```
TEST: Create snapshot captures full state
  GIVEN a project with Ch1(S1 "Hello", S2 "World")
  WHEN createSnapshot(name: "v1") is called
  THEN snapshot exists in listSnapshots()
  AND snapshot.wordCount matches current total

TEST: Diff detects modified scene
  GIVEN snapshot A has S1 content "Hello" and snapshot B has S1 content "Hello World"
  WHEN diff(A, B) is called
  THEN sceneDiffs contains S1 with changeType .modified
  AND lineDiffs shows the addition of " World"

TEST: Diff detects added scene
  GIVEN snapshot A has [S1, S2] and snapshot B has [S1, S2, S3]
  WHEN diff(A, B) is called
  THEN sceneDiffs contains S3 with changeType .added

TEST: Diff detects removed scene
  GIVEN snapshot A has [S1, S2, S3] and snapshot B has [S1, S3]
  WHEN diff(A, B) is called
  THEN sceneDiffs contains S2 with changeType .removed

TEST: Restore auto-snapshots current state first
  GIVEN snapshot "v1" exists, and current state has modifications
  WHEN restore(v1.id) is called
  THEN listSnapshots() contains a new snapshot named "Auto-save before restoring 'v1'"
  AND that auto-snapshot captures the pre-restore state
  AND current manuscript matches v1's state

TEST: Restore is reversible
  GIVEN snapshot "v1" is restored (creating auto-snapshot "Auto-save before restoring 'v1'")
  WHEN the auto-snapshot is then restored
  THEN manuscript returns to the state before the first restore

TEST: Create snapshot performance
  GIVEN a 100K-word manuscript
  WHEN createSnapshot is called
  THEN it completes in ≤1 second

TEST: Compare with current includes unsaved changes
  GIVEN snapshot A was created, then user edits S1 without saving
  WHEN diffWithCurrent(A.id) is called
  THEN the diff includes the unsaved changes to S1
```

---

## 6. Implementation Notes

- Use a standard text diff algorithm (Myers diff or patience diff) at the line level for scene content comparison. Swift has no built-in diff for strings — consider porting a lightweight diff library or using `CollectionDifference` on line arrays.
- Snapshot storage strategy: the first snapshot is a full copy of all scene .md files into `metadata/snapshots/baselines/snap-{uuid}/`. Subsequent snapshots store unified diffs against the previous snapshot. This balances storage size vs. reconstruction speed.
- For the diff UI, consider a split-pane view: left = snapshot A, right = snapshot B, with synchronized scrolling and colored line highlights.
- The diff view should be read-only. Users cannot edit within the diff view — they must close it and edit in the normal editor.
- Snapshot metadata (name, date, word count) is stored in the snapshot's JSON file. The full list is loaded from the `metadata/snapshots/` directory at project open.
