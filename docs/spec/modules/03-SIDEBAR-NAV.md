# Module 03: Sidebar & Navigation
## Scribbles-N-Scripts — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 01 (Project I/O) — reads manifest hierarchy, calls reorder operations
> **Exposes**: `SidebarView`, `NavigationState`, reorder operations

---

## 1. Purpose

The persistent left-side panel showing the full project hierarchy. Provides navigation, reordering, and structural operations. This is the primary way users understand and manipulate the shape of their project.

---

## 2. Interface Specification

```swift
class NavigationState: ObservableObject {
    @Published var selectedSceneId: UUID?
    @Published var selectedChapterId: UUID?
    @Published var expandedNodes: Set<UUID>        // Which chapters/parts are expanded
    @Published var breadcrumb: [BreadcrumbItem]    // Current location path
    @Published var activeFilters: FilterSet        // Currently applied filters
    
    func navigateTo(sceneId: UUID)
    func navigateTo(chapterId: UUID)
    func expandAll()
    func collapseAll()
}

struct BreadcrumbItem {
    let id: UUID
    let title: String
    let type: HierarchyLevel  // .manuscript, .part, .chapter, .scene
}

enum HierarchyLevel {
    case manuscript, part, chapter, scene
}

struct FilterSet {
    var tags: Set<UUID>?
    var statuses: Set<ContentStatus>?
    var colorLabels: Set<ColorLabel>?
    var metadataFilters: [String: String]?  // field name → value
    
    var isActive: Bool { /* true if any filter is non-nil */ }
}
```

---

## 3. Behavioral Specification

### 3.1 Tree View
- **Given** an open project with Parts → Chapters → Scenes
- **When** the sidebar renders
- **Then** the hierarchy is displayed as a tree: Part nodes contain Chapter nodes, which contain Scene nodes. Each node shows its title and word count. Chapters and Parts are collapsible. Scene nodes show a color label indicator (small dot) if assigned.

- **Given** the hierarchy has no Parts (chapters directly under manuscript)
- **When** the sidebar renders
- **Then** chapters appear at the top level with no wrapping Part layer.

### 3.2 Drag-and-Drop Reordering
- **Given** Scene S2 is in Chapter A at index 1
- **When** the user drags S2 below S5 in Chapter B
- **Then** `ProjectManager.moveScene(S2, to: ChapterB, atIndex: appropriateIndex)` is called. The sidebar updates to show the new position. The operation is a single undo entry.

- **Given** a chapter is dragged
- **When** it is dropped in a new position
- **Then** the chapter (with all its scenes) moves. `ProjectManager.moveChapter()` is called.

- **Constraint**: Scenes cannot be dragged to the Part or Manuscript level — they must always be inside a chapter. Chapters cannot be dragged inside other chapters.

### 3.3 Quick Jump (Cmd+J)
- **Given** the user presses Cmd+J
- **When** the quick jump dialog opens
- **Then** a text field with fuzzy search is shown. As the user types, results are filtered from all scene and chapter titles. Results show the full path (Part > Chapter > Scene). Pressing Enter navigates to the selected result in the current mode.

- **Given** the user types "dragon" in quick jump
- **When** results are displayed
- **Then** scenes/chapters with "dragon" in their title are shown first, followed by scenes with "dragon" in their content (content search is secondary, title match takes priority).

### 3.4 Breadcrumb Navigation
- **Given** the user is editing Scene 3 in Chapter 2 of Part 1
- **When** the breadcrumb bar renders
- **Then** it shows: "My Novel > Part 1 > Chapter 2 > Scene 3". Each segment is clickable — clicking "Chapter 2" navigates to that chapter (first scene in linear mode, chapter overview in modular mode).

### 3.5 Context Menu
- **Given** the user right-clicks a scene node
- **When** the context menu appears
- **Then** options include: Rename, Set Status (submenu), Set Color Label (submenu), Duplicate, Move to Staging, Delete (to Trash), and New Scene Below.

- **Given** the user right-clicks a chapter node
- **When** the context menu appears
- **Then** options include: Rename, Add Scene, Set Status, Delete Chapter (to Trash), and New Chapter Below.

### 3.6 Filtering
- **Given** the user activates a filter (e.g., status = "First Draft")
- **When** the filter is applied
- **Then** only scenes matching the filter are visible in the sidebar. Non-matching scenes are hidden (not dimmed). Chapters with zero visible scenes are still shown (with "(0 matching)" indicator). An active filter badge is shown in the sidebar header. Clearing the filter restores full view.

### 3.7 Word Count Display
- **Given** a chapter with 5 scenes
- **When** displayed in the sidebar
- **Then** the chapter node shows the sum of its scenes' word counts. Parts show the sum of their chapters. The manuscript root shows the total project word count.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Drag scene to staging area | If modular mode has a staging area, dragging to it calls `moveToStaging()`. Staging is visible in sidebar as a special "Unassigned" section at the bottom. |
| Rename to empty string | Reject. Revert to previous title. |
| Rename to duplicate title | Allow. Titles are not required to be unique (scenes are identified by UUID). |
| Very long title (200+ chars) | Truncate display in sidebar with ellipsis. Full title visible as tooltip on hover. |
| 100+ scenes in one chapter | Sidebar remains performant. Use lazy list rendering for chapters with >50 scenes. |
| Filter active + drag-and-drop | Drag-and-drop works on visible items only. Drop targets include hidden items' positions (the user sees the filtered view but the drop inserts into the actual sequence position). |
| Sidebar width | User-resizable with drag handle. Minimum width: 200px. Maximum: 40% of window width. Persisted in project settings. |

---

## 5. Test Cases

```
TEST: Sidebar displays correct hierarchy
  GIVEN a project with Part1(Ch1(S1, S2), Ch2(S3)) and Part2(Ch3(S4))
  WHEN the sidebar renders
  THEN the tree shows Part1 > Ch1 > S1, S2 and Ch1 sibling Ch2 > S3, etc.
  AND Part1's word count = sum(S1, S2, S3)
  AND Part2's word count = sum(S4)

TEST: Drag scene between chapters
  GIVEN Ch1 has [S1, S2] and Ch2 has [S3]
  WHEN S2 is dragged to Ch2 after S3
  THEN Ch1 contains [S1], Ch2 contains [S3, S2]
  AND one undo restores original state

TEST: Quick jump finds by title first, then content
  GIVEN S1 titled "Dragon Attack" and S2 with content containing "dragon" but titled "Night Scene"
  WHEN user types "dragon" in quick jump
  THEN S1 ("Dragon Attack") appears above S2 ("Night Scene") in results

TEST: Filter hides non-matching scenes
  GIVEN 10 scenes, 3 with status "First Draft"
  WHEN filter status="First Draft" is applied
  THEN only 3 scenes are visible in sidebar
  AND an active filter indicator is shown

TEST: Breadcrumb is clickable
  GIVEN user is at Part1 > Ch2 > S5
  WHEN user clicks "Ch2" in breadcrumb
  THEN navigation moves to Chapter 2 (first scene or chapter overview depending on mode)

TEST: Context menu delete sends to trash
  GIVEN scene S1 exists in Ch1
  WHEN user right-clicks S1 and selects "Delete"
  THEN S1 is removed from sidebar
  AND S1 appears in trash
  AND undo restores S1 to its original position
```

---

## 6. Implementation Notes

- Use SwiftUI `List` with `OutlineGroup` for the tree view, or a custom `NSOutlineView` wrapper if SwiftUI performance is insufficient for large hierarchies.
- Quick jump should index scene titles at project open and update incrementally on renames. Content search uses the search index from Module 09 (when available); before Module 09 is built, quick jump is title-only.
- Drag-and-drop: use SwiftUI's `onDrag`/`onDrop` modifiers with custom `NSItemProvider` payloads containing the dragged item's UUID and type.
- The sidebar should observe `ProjectManager.currentProject` for hierarchy changes and re-render automatically via Combine/SwiftUI bindings.
