# Module 06: Mode Switching
## Manuscript — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 04 (Linear Mode), Module 05 (Modular Mode)
> **Exposes**: `ModeController` — switch mode preserving position, bidirectional position mapping

---

## 1. Purpose

Manages the transition between linear and modular modes. Ensures context (selected scene, scroll position, unsaved changes) is preserved across switches. Both modes are live views of the same data — this module ensures they stay synchronized.

---

## 2. Interface Specification

```swift
class ModeController: ObservableObject {
    @Published var activeMode: ViewMode
    
    func switchMode()                              // Toggle between linear/modular
    func switchTo(_ mode: ViewMode)
    func positionInLinearMode(for sceneId: UUID) -> LinearPosition
    func positionInModularMode(for sceneId: UUID) -> ModularPosition
}

enum ViewMode {
    case linear
    case modular
}

struct LinearPosition {
    let sceneId: UUID
    let cursorOffset: Int?           // Restore cursor if returning to a previously-edited scene
}

struct ModularPosition {
    let sceneId: UUID                // Card to highlight
    let groupScrollOffset: CGFloat?  // Scroll position in the card grid
}
```

---

## 3. Behavioral Specification

### 3.1 Linear → Modular
- **Given** user is editing S5 in linear mode
- **When** Cmd+Shift+M is pressed (or toolbar toggle clicked)
- **Then**: (1) If S5 has unsaved changes, autosave triggers immediately. (2) The view transitions to modular mode. (3) The card for S5 is highlighted and scrolled into view. (4) The transition animation completes in ≤200ms.

### 3.2 Modular → Linear
- **Given** user has card S8 selected in modular mode
- **When** Cmd+Shift+M is pressed
- **Then**: (1) The view transitions to linear mode. (2) S8's content is loaded. (3) The editor displays S8 with cursor at position 0 (or at the last known cursor position if the user previously edited S8 this session). (4) Transition completes in ≤200ms.

### 3.3 No Selection Edge Case
- **Given** user is in modular mode with no card selected
- **When** switching to linear mode
- **Then** linear mode opens at the first scene of the first chapter.

### 3.4 Staging Area Scene
- **Given** user has a staging area scene selected in modular mode
- **When** switching to linear mode
- **Then** linear mode opens at the first scene of the first chapter (staging scenes are not in the linear sequence). A toast notification reads: "Staging scenes are not visible in linear mode."

### 3.5 Data Consistency
- **Given** the user reorders scenes in modular mode and then switches to linear mode
- **When** the switch occurs
- **Then** linear mode reflects the new order immediately. No sync step is needed — both modes read from the same manifest.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Rapid toggling (switch, switch, switch) | Each switch is idempotent and immediate. No queuing or debounce. |
| Switch during active drag-and-drop in modular mode | Cancel the drag operation, then switch. |
| Switch with inline editor overlay open in modular mode | Close the overlay, save changes, then switch. |
| Filter active in modular mode, switch to linear | Filters are mode-specific display state. Linear mode ignores card filters (shows all scenes in sequence). The filter set is preserved in memory so returning to modular mode restores it. |

---

## 5. Test Cases

```
TEST: Switch preserves scene selection
  GIVEN user is editing S5 in linear mode
  WHEN switching to modular mode
  THEN S5's card is highlighted in modular view

TEST: Switch triggers autosave of dirty content
  GIVEN user has unsaved changes to S5 in linear mode
  WHEN switching to modular mode
  THEN S5's content is saved before transition completes

TEST: Switch performance is within budget
  GIVEN a project with 200 scenes
  WHEN mode switch is triggered
  THEN transition completes in ≤200ms (measure from input event to render-complete)

TEST: Reorder in modular, verify in linear
  GIVEN Ch1 has scenes [S1, S2, S3] in modular mode
  WHEN S3 is dragged before S1 making order [S3, S1, S2]
  AND user switches to linear mode
  THEN linear sequence shows S3 → S1 → S2

TEST: Staging scene switch to linear shows toast
  GIVEN a staging scene is selected in modular mode
  WHEN switching to linear mode
  THEN linear mode shows the first manuscript scene
  AND a toast notification appears about staging scenes
```

---

## 6. Implementation Notes

- `ModeController` should be a top-level state object injected into both mode views. The active view container swaps between `LinearModeView` and `ModularModeView` based on `activeMode`.
- Store a `lastLinearPosition` and `lastModularPosition` dictionary (keyed by scene UUID) to restore cursor offsets when returning to previously-visited scenes.
- The switch animation should be a simple crossfade (0.15s ease-in-out). No sliding or complex transitions — speed is more important than polish here.
- Toolbar toggle: a segmented control or icon toggle in the toolbar showing the current mode. Also accessible via command palette ("Switch to Linear Mode" / "Switch to Modular Mode").
