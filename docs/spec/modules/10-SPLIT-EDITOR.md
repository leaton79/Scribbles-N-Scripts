# Module 10: Split Editor
## Scribbles-N-Scripts — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 02 (Editor) — embeds two `EditorView` instances; Module 04 (Linear Mode) — scene loading
> **Exposes**: `SplitEditorView` — two independent editor panes

---

## 1. Purpose

Allows the user to view and edit two scenes simultaneously in side-by-side or stacked panes. Essential for referencing earlier content while writing, comparing two scenes, or viewing a scene alongside metadata (in v1.1+).

---

## 2. Interface Specification

```swift
class SplitEditorState: ObservableObject {
    @Published var isSplit: Bool                      // Default: false
    @Published var orientation: SplitOrientation      // Default: .vertical
    @Published var primarySceneId: UUID?              // Left/top pane
    @Published var secondarySceneId: UUID?            // Right/bottom pane
    @Published var splitRatio: CGFloat                // Default: 0.5 (equal split)
    @Published var activePaneIndex: Int               // 0 = primary, 1 = secondary
    
    func openSplit(sceneId: UUID)                     // Opens scene in secondary pane
    func closeSplit()                                 // Returns to single pane
    func swapPanes()                                  // Swap primary ↔ secondary
    func toggleOrientation()                          // Vertical ↔ horizontal
}

enum SplitOrientation {
    case vertical    // Side-by-side (left | right)
    case horizontal  // Stacked (top / bottom)
}
```

---

## 3. Behavioral Specification

### 3.1 Opening a Split
- **Given** the user is editing S3 in a single pane
- **When** they trigger "Open in Split" on S7 (via sidebar context menu, command palette, or Cmd+\\)
- **Then** the editor splits into two panes. The primary pane (left/top) continues showing S3. The secondary pane (right/bottom) shows S7. Both panes are fully editable with independent cursors, selections, and undo stacks.

### 3.2 Independent Editing
- **Given** split view is open with S3 (primary) and S7 (secondary)
- **When** the user types in the secondary pane
- **Then** only S7 is modified. S3 is unaffected. Each pane has its own `EditorState`. Word count updates independently. Autosave covers both panes.

### 3.3 Active Pane Focus
- **Given** split view is open
- **When** the user clicks in the secondary pane
- **Then** `activePaneIndex` changes to 1. The active pane has a subtle border highlight. Keyboard shortcuts (Cmd+F, Cmd+Z, etc.) apply to the active pane only. The sidebar selection follows the active pane's scene.

### 3.4 Resizing
- **Given** split view is open at 50/50 ratio
- **When** the user drags the divider
- **Then** `splitRatio` updates smoothly. Minimum pane width: 250px. The ratio persists across mode switches and session restarts.

### 3.5 Closing Split
- **Given** split view is open
- **When** the user triggers "Close Split" (Cmd+\\ again, or button)
- **Then** the secondary pane closes. The primary pane expands to full width. The active scene remains whichever pane was last active. Unsaved changes in both panes are preserved (autosave triggers for the closing pane).

### 3.6 Same Scene in Both Panes
- **Given** split view with S3 in both panes
- **When** the user edits S3 in the primary pane
- **Then** the secondary pane updates in real-time to reflect the change. This allows viewing different sections of the same long scene simultaneously. Both panes maintain independent scroll positions and cursor positions.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Split in modular mode | Split is only available in linear mode. If split is open and user switches to modular mode, split closes automatically (autosave both panes first). |
| Split + Focus Mode | Focus mode applies to the active pane only. The inactive pane dims entirely (not just surrounding text). |
| Window too narrow for split | If window width < 500px, prevent vertical split. Show tooltip: "Window too narrow for side-by-side split. Try stacked layout." |
| Navigate from sidebar while split is open | Navigation changes the active pane's scene. The other pane is unaffected. |
| Delete a scene that's in the secondary pane | The secondary pane shows "Scene deleted" placeholder. User must select a different scene or close the split. |
| Undo in one pane while editing the other | Undo stacks are independent. Undoing in the primary pane does not affect the secondary pane. |

---

## 5. Test Cases

```
TEST: Open split shows two independent panes
  GIVEN user is editing S3
  WHEN openSplit(sceneId: S7) is called
  THEN two panes are visible
  AND primary pane shows S3
  AND secondary pane shows S7

TEST: Editing in one pane doesn't affect the other
  GIVEN split with S3 (primary) and S7 (secondary)
  WHEN user types "Hello" in secondary pane
  THEN S7 content changes
  AND S3 content is unchanged

TEST: Active pane receives keyboard shortcuts
  GIVEN split view, secondary pane is active
  WHEN Cmd+F is pressed
  THEN search bar opens in secondary pane only

TEST: Same scene in both panes syncs edits
  GIVEN S3 is in both primary and secondary panes
  WHEN user types in primary pane
  THEN secondary pane reflects the change in real-time

TEST: Close split preserves content
  GIVEN split view with unsaved changes in both panes
  WHEN closeSplit() is called
  THEN both scenes are saved
  AND single-pane view shows the last active scene

TEST: Resize respects minimum width
  GIVEN vertical split at 50/50 in 800px window
  WHEN user drags divider to 100px from left
  THEN divider stops at 250px (minimum pane width)
```

---

## 6. Implementation Notes

- Implement as two `EditorView` instances within an `HSplitView` or `VSplitView` (SwiftUI) or custom `NSSplitView` wrapper.
- Each pane has its own `EditorState` instance. The `SplitEditorState` coordinates which pane is active and manages lifecycle.
- For same-scene-in-both-panes sync: both editor instances should observe the same underlying content model. Changes from either are written to the shared model and both views update. Use Combine to propagate changes.
- Split state (is open, orientation, ratio, scene IDs) should persist in the project's runtime state (session-level, not saved to manifest).
