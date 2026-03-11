# Module 04: Multi-Scene Linear Mode
## Scribbles-N-Scripts — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 02 (Editor) — embeds `EditorView`; Module 03 (Sidebar) — consumes `NavigationState`
> **Exposes**: `LinearModeView`, sequential scene navigation, scene boundary rendering

---

## 1. Purpose

Presents the manuscript as a continuous, sequential reading/writing experience. The user moves through scenes in order, with visual boundaries between them. Mental model: writing a book from front to back.

---

## 2. Interface Specification

```swift
struct LinearModeView: View {
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var editorState: EditorState
    
    // Navigation within linear mode
    func goToNextScene()
    func goToPreviousScene()
    func goToScene(id: UUID)
}

struct SceneBoundary {
    let precedingSceneId: UUID
    let followingSceneId: UUID
    let chapterBreak: Bool          // True if scenes are in different chapters
    let chapterTitle: String?       // Non-nil on chapter breaks
}
```

---

## 3. Behavioral Specification

### 3.1 Sequential Display
- **Given** an open project with Chapter 1 (S1, S2) and Chapter 2 (S3, S4)
- **When** linear mode is active and the user is at S1
- **Then** the editor shows S1's content. A scene boundary divider is visible at the bottom, followed by S2. Chapter boundaries show the chapter title as a visual header. The user can scroll continuously from S1 through S4.

- **Design decision**: The editor loads the **current scene** for editing and renders adjacent scene previews (read-only, dimmed) above and below for context. Only the current scene is editable. Clicking a preview scene makes it the current scene.

### 3.2 Scene Navigation
- **Given** the user is editing S2
- **When** they press Cmd+↓ (or a "Next Scene" control)
- **Then** the editor transitions to S3. Autosave triggers for S2 if modified. S3's content loads from disk (via `ProjectManager.loadSceneContent`). Cursor is placed at the beginning of S3.

- **Given** the user is at the first scene (S1)
- **When** they press Cmd+↑ (Previous Scene)
- **Then** nothing happens (no wrap-around). A subtle indicator shows "Beginning of manuscript."

### 3.3 Scene Boundaries
- **Given** S2 and S3 are in the same chapter
- **When** the boundary between them is rendered
- **Then** a subtle horizontal divider with the scene title of S3 is shown. No chapter header.

- **Given** S2 is the last scene in Chapter 1 and S3 is the first in Chapter 2
- **When** the boundary is rendered
- **Then** a prominent chapter heading ("Chapter 2: [Title]") is displayed, visually distinct from scene dividers.

### 3.4 Creating New Scenes Inline
- **Given** the user is editing S2 and wants to add a scene after it
- **When** they press Cmd+Enter (or use the command palette "New Scene Below")
- **Then** a new empty scene is created at index S2.index + 1 in the same chapter. The editor transitions to the new scene. The sidebar updates to show the new scene.

### 3.5 Position Synchronization with Sidebar
- **Given** the user navigates to S5 via the sidebar
- **When** the sidebar selection changes
- **Then** the linear mode editor loads S5 and scrolls to its position. Conversely, when the user navigates via Cmd+↓/↑, the sidebar selection updates to reflect the current scene.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Empty chapter in the sequence | Display the chapter heading with "(No scenes)" indicator. Next Scene skips to the first scene of the following chapter. |
| Staging area scenes | Not visible in linear mode. Only scenes assigned to chapters appear. |
| Very long scene (50,000 chars) | The editor handles this via Module 02's block rendering. Linear mode does not add additional overhead. |
| Adjacent scene loading | When the user navigates to a scene, pre-load the next and previous scenes' content in the background to minimize transition lag. |
| Chapter with 50+ scenes | Performance is handled by loading only the current scene plus previews. The scroll indicator should show position within the chapter (e.g., "Scene 23 of 47"). |

---

## 5. Test Cases

```
TEST: Linear mode displays scenes in sequence order
  GIVEN Ch1(S1, S2) and Ch2(S3, S4)
  WHEN linear mode renders starting at S1
  THEN scenes appear in order: S1, S2, S3, S4
  AND chapter boundary between S2 and S3 shows "Chapter 2" heading

TEST: Next scene navigation loads content and updates sidebar
  GIVEN user is editing S2
  WHEN Cmd+↓ is pressed
  THEN S2 is saved (if modified)
  AND S3 content is loaded and displayed in editor
  AND sidebar selection updates to S3

TEST: New scene inline inserts at correct position
  GIVEN Ch1 has scenes [S1, S2, S3]
  WHEN user is at S1 and triggers "New Scene Below"
  THEN Ch1 has scenes [S1, NewScene, S2, S3]
  AND editor displays NewScene with empty content
  AND sidebar shows the updated order

TEST: Previous scene at manuscript start is no-op
  GIVEN user is at the first scene in the manuscript
  WHEN Cmd+↑ is pressed
  THEN nothing changes
  AND a subtle "Beginning of manuscript" indicator appears

TEST: Adjacent scenes are pre-loaded
  GIVEN user navigates to S5
  WHEN S5 is displayed
  THEN S4 and S6 content are loaded in background
  AND navigating to S6 does not trigger a visible loading delay
```

---

## 6. Implementation Notes

- The "current scene is editable, adjacent scenes are read-only previews" model avoids the complexity of a single-document virtual scroll over the entire manuscript. It keeps the editor scoped to one scene (simplifying undo, autosave, and word count) while giving the user a sense of continuity.
- Pre-loading: when the current scene changes, dispatch background loads for the ±1 adjacent scenes. Cache the last 5 loaded scenes' content in memory; evict on memory pressure.
- Scene boundary views should be non-editable, non-selectable visual elements that sit between the scene editor instances.
- Keyboard shortcut Cmd+↓/↑ for scene navigation should be registered at the window level to avoid conflicts with text editor cursor movement. Alternative: use Option+Cmd+↓/↑.
