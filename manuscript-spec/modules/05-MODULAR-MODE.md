# Module 05: Modular Card View
## Manuscript — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 01 (Project I/O) — reads scene metadata, calls reorder operations; Module 03 (Sidebar) — shares `FilterSet`
> **Exposes**: `ModularModeView`, card layout, drag-and-drop reorder, filter engine

---

## 1. Purpose

Presents scenes as spatial index cards. The user sees the project's shape at a glance, reorders by dragging cards, and filters to focus on subsets. Mental model: index cards pinned to a corkboard. In v1.0, this is a grid layout; v1.1 upgrades to a full corkboard with freeform positioning.

---

## 2. Interface Specification

```swift
struct ModularModeView: View {
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var editorState: EditorState
    
    var grouping: CardGrouping             // How cards are grouped
    var activeFilters: FilterSet
    
    func selectCard(sceneId: UUID)         // Highlights card
    func openCard(sceneId: UUID)           // Opens for editing (triggers editor)
}

enum CardGrouping {
    case byChapter                         // Cards grouped under chapter headers
    case flat                              // All cards in one pool (useful with filters)
    case byTag(tagId: UUID)                // Cards grouped by a specific tag
    case byStatus                          // Cards grouped by status column
}

struct CardData {
    let sceneId: UUID
    let title: String
    let previewText: String                // First ~50 words OR synopsis
    let wordCount: Int
    let status: ContentStatus
    let colorLabel: ColorLabel?
    let tags: [Tag]                        // Resolved tag objects (not just IDs)
    let chapterTitle: String               // Parent chapter name
}
```

---

## 3. Behavioral Specification

### 3.1 Card Display
- **Given** a scene with title "The Confrontation", synopsis "Hero faces the villain in the tower", status "First Draft", color label red, word count 2,340, tags ["Subplot A", "Action"]
- **When** its card renders
- **Then** the card shows: title at top, synopsis text (or first ~50 words of content if synopsis is empty), word count, a status badge ("First Draft"), a red color dot, and up to 3 tag pills. Card dimensions are fixed width (~200px), variable height based on content.

### 3.2 Default Grouping (By Chapter)
- **Given** Ch1 has [S1, S2, S3] and Ch2 has [S4, S5]
- **When** modular mode renders with `grouping: .byChapter`
- **Then** chapter headers appear as group labels. Under "Chapter 1", cards S1–S3 are arranged in a row/grid. Under "Chapter 2", cards S4–S5 follow. A "Staging Area" group appears at the bottom showing any unassigned scenes.

### 3.3 Drag-and-Drop
- **Given** card S2 is in the Chapter 1 group
- **When** the user drags S2 to the Chapter 2 group and drops it between S4 and S5
- **Then** `ProjectManager.moveScene(S2, to: Ch2, atIndex: 1)` is called. Card S2 animates to its new position. Chapter 1 group reflows. This is one undo entry.

- **Given** a card is dragged to the Staging Area
- **When** dropped
- **Then** `ProjectManager.moveToStaging(sceneId)` is called. The card appears in the Staging group.

### 3.4 Filtering
- **Given** the user activates filter: status = "To Do"
- **When** the filter is applied
- **Then** only cards with status "To Do" are visible. Other cards are hidden (not dimmed — this is a hard filter). Chapter groups with zero matching cards show "(0 matching)" and are collapsed. The filter state is shared with the sidebar via `NavigationState.activeFilters`.

- **Given** the user groups by status
- **When** `grouping: .byStatus` is active
- **Then** cards are grouped under column headers matching each status value. Cards can be dragged between status columns, which updates the scene's status.

### 3.5 Card Interaction
- **Given** a card is single-clicked
- **When** the click occurs
- **Then** the card is selected (highlighted border). The sidebar selection updates. The inspector panel (if visible) shows the scene's metadata.

- **Given** a card is double-clicked
- **When** the double-click occurs
- **Then** the scene opens for editing. Implementation: either switch to linear mode at that scene, or open an inline editor overlay on top of the card view (configurable preference). The inline overlay shows the full editor for that scene and closes on Escape or clicking outside.

### 3.6 New Scene in Modular Mode
- **Given** the user is in modular mode viewing Chapter 1
- **When** they press the "+" button in the Chapter 1 group header (or use command palette "New Scene in Chapter 1")
- **Then** a new scene card appears at the end of the Chapter 1 group. The scene is created via `ProjectManager.addScene(to: Ch1)`. If the user is in the Staging Area, the scene is added to staging.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Scene with no synopsis and no content | Card shows title and "(Empty)" placeholder in preview area. |
| Scene with very long title | Truncate at 2 lines with ellipsis on card. Full title in tooltip. |
| 200+ cards visible | Use lazy grid rendering. Only cards in the visible viewport + buffer are fully rendered. Off-screen cards are placeholder rectangles with correct dimensions. |
| Drag card to invalid target (e.g., outside any group) | Cancel drag. Card snaps back to original position. |
| Multi-select cards | Cmd+click selects multiple cards. Dragging multi-selection moves all selected cards as a group. Multi-select context menu offers bulk operations (set status, set tag, delete). |
| Grouping by tag when scene has multiple tags | Scene card appears in each matching group (duplicated visually). Dragging between tag groups changes the scene's tag assignment. |
| Window resize | Cards reflow within groups. Group headers remain fixed. |

---

## 5. Test Cases

```
TEST: Cards display correct metadata
  GIVEN scene S1 with title "Test", synopsis "Summary", status .firstDraft, colorLabel .red, wordCount 500, tags ["Action"]
  WHEN card renders
  THEN card shows "Test", "Summary", "500 words", "First Draft" badge, red dot, "Action" tag pill

TEST: Drag card between chapters
  GIVEN Ch1 has [S1, S2], Ch2 has [S3]
  WHEN S1 is dragged to Ch2 after S3
  THEN Ch1 shows [S2], Ch2 shows [S3, S1]
  AND single undo reverts to original arrangement

TEST: Filter by status hides non-matching cards
  GIVEN 10 scenes: 3 with status .todo, 7 with other statuses
  WHEN filter status=.todo is applied
  THEN only 3 cards are visible
  AND chapter groups with 0 matching cards show "(0 matching)"

TEST: Double-click opens scene for editing
  GIVEN card S1 is visible
  WHEN S1 is double-clicked
  THEN the editor opens with S1's content loaded
  AND EditorState.currentSceneId == S1.id

TEST: Group by status enables drag-to-change-status
  GIVEN grouping is .byStatus, scene S1 has status .todo
  WHEN S1's card is dragged to the "Revised" column
  THEN S1's status updates to .revised
  AND the card appears in the "Revised" group

TEST: Multi-select bulk operations
  GIVEN cards S1, S2, S3 are visible
  WHEN Cmd+click selects S1 and S3
  AND context menu > Set Status > "Final" is chosen
  THEN S1 and S3 both have status .final_
  AND S2 is unchanged

TEST: Lazy rendering for large projects
  GIVEN 300 scene cards
  WHEN modular mode renders
  THEN fewer than 50 card views are in the view hierarchy
  AND scrolling smoothly reveals additional cards
```

---

## 6. Implementation Notes

- Use SwiftUI `LazyVGrid` for the card layout within each group. Group headers are section headers.
- Card drag-and-drop: use `onDrag` with `NSItemProvider` encoding the scene UUID. Drop targets on groups and between-card insertion points.
- The `CardData` struct is derived from the in-memory metadata index (loaded at project open in Module 01). No scene content files are read to render cards unless the scene has no synopsis (in which case, content is loaded to extract the first 50 words, then cached).
- Shared filter state: `NavigationState.activeFilters` is observed by both the sidebar (Module 03) and the modular view. Changing a filter in either place updates both.
