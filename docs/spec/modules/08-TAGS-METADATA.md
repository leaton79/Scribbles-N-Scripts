# Module 08: Tags & Metadata
## Scribbles-N-Scripts — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 01 (Project I/O) — reads/writes tags.json and manifest metadata; Module 03 (Sidebar) — shares filter predicates
> **Exposes**: `TagManager`, `MetadataManager`, filter predicates for Sidebar and Modular Mode

---

## 1. Purpose

Provides the organizational layer: tags, color labels, custom metadata fields, and status management. These properties are attached to scenes and chapters and are used for filtering, grouping, and visual identification across the sidebar and modular mode.

---

## 2. Interface Specification

```swift
class TagManager: ObservableObject {
    @Published var allTags: [Tag]
    
    func createTag(name: String, color: String?) throws -> Tag
    func renameTag(id: UUID, newName: String) throws
    func deleteTag(id: UUID) throws                    // Removes from all scenes
    func mergeTag(sourceId: UUID, targetId: UUID) throws // Replaces all uses of source with target
    
    func addTag(_ tagId: UUID, to sceneId: UUID) throws
    func removeTag(_ tagId: UUID, from sceneId: UUID) throws
    func scenesWithTag(_ tagId: UUID) -> [UUID]
    
    func autocomplete(prefix: String) -> [Tag]         // For tag input fields
}

class MetadataManager: ObservableObject {
    @Published var customFields: [CustomMetadataField]
    
    func addField(_ field: CustomMetadataField) throws
    func removeField(id: UUID) throws                  // Removes values from all scenes
    func renameField(id: UUID, newName: String) throws
    
    func setSceneMetadata(sceneId: UUID, field: String, value: String) throws
    func getSceneMetadata(sceneId: UUID, field: String) -> String?
    func scenesMatching(field: String, value: String) -> [UUID]
}

// Filter predicate builder — consumed by Sidebar (Module 03) and Modular Mode (Module 05)
struct FilterEngine {
    static func buildPredicate(from filterSet: FilterSet) -> (Scene) -> Bool
    static func matchingSceneIds(in project: Project, filters: FilterSet) -> Set<UUID>
}
```

---

## 3. Behavioral Specification

### 3.1 Tag CRUD
- **Given** no tags exist
- **When** the user creates a tag "Subplot A" via the tag input field on a scene
- **Then** a new Tag is created in `allTags`, assigned to the scene, and saved to `metadata/tags.json`. Future tag input shows "Subplot A" in autocomplete.

- **Given** tag "Subplot A" is used on 5 scenes
- **When** the user deletes the tag
- **Then** a confirmation dialog shows "This tag is used on 5 scenes. Remove it from all?" On confirm, the tag is removed from all scene tag arrays and deleted from tags.json.

### 3.2 Tag Autocomplete
- **Given** tags "Action", "Adventure", "Arc: Redemption" exist
- **When** the user types "A" in a tag input field
- **Then** autocomplete shows "Action", "Adventure", "Arc: Redemption" sorted alphabetically. Typing "Ac" narrows to "Action". Pressing Enter on a suggestion applies it. Typing a new string and pressing Enter creates a new tag.

### 3.3 Color Labels
- **Given** a scene with no color label
- **When** the user sets it to "red" via context menu or inspector panel
- **Then** the scene's colorLabel updates. The sidebar node shows a red dot. The modular mode card shows a red dot. The label name (user-defined, e.g., "Needs Research") is shown in tooltips.

### 3.4 Custom Metadata Fields
- **Given** the user defines a custom field "POV Character" (type: text) in project settings
- **When** the field is created
- **Then** every scene gains an empty "POV Character" metadata slot. The inspector panel for any scene shows "POV Character: [empty]" as an editable field. The field is available as a filter criterion.

- **Given** the field type is `singleSelect` with options ["Alice", "Bob", "Charlie"]
- **When** the user edits a scene's "POV Character" field
- **Then** a dropdown shows the three options. Selecting "Alice" sets the value.

### 3.5 Status Management
- **Given** default statuses: To Do, In Progress, First Draft, Revised, Final
- **When** the user changes S1's status from "To Do" to "In Progress"
- **Then** the manifest updates, sidebar badge updates, and modular mode card badge updates.

- **Given** the user wants custom statuses
- **When** they modify status options in project settings (e.g., add "Needs Fact-Check")
- **Then** the new status is available for all scenes. Existing scenes with the old statuses are unaffected.

### 3.6 Filter Composition
- **Given** filters: status = "First Draft" AND tag = "Subplot A"
- **When** the filter is applied
- **Then** only scenes matching BOTH conditions are shown (AND logic). Different filter types combine with AND. Multiple values within the same filter type combine with OR (e.g., status = "First Draft" OR "Revised").

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Tag name with special characters | Allow any UTF-8 string. Trim whitespace. Minimum 1 character. |
| Duplicate tag name | Prevent creation. Show error "Tag 'X' already exists." |
| Delete custom metadata field | Confirm dialog: "Remove field 'POV Character' and all its values from all scenes?" On confirm, all values are cleared and the field definition is deleted. |
| Scene with 20+ tags | Allow. UI truncates display to 3 tags with a "+17 more" indicator. Full list in inspector panel. |
| Rename tag used in active filter | Filter updates to use the new name automatically. |
| Color label with no user-defined name | Show the color name (e.g., "Red") as the label name. |
| Filter returns zero results | Show an empty state message: "No scenes match the current filters." with a "Clear filters" button. |

---

## 5. Test Cases

```
TEST: Create tag and assign to scene
  GIVEN no tags exist
  WHEN createTag("Action") is called and addTag(action.id, to: S1.id) is called
  THEN allTags contains "Action"
  AND S1.tags contains action.id
  AND scenesWithTag(action.id) returns [S1.id]

TEST: Delete tag removes from all scenes
  GIVEN tag "Action" is on scenes [S1, S2, S3]
  WHEN deleteTag(action.id) is called
  THEN allTags does not contain "Action"
  AND S1.tags, S2.tags, S3.tags no longer contain action.id

TEST: Merge tag replaces all references
  GIVEN tag "Fight" on [S1, S2] and tag "Action" on [S3]
  WHEN mergeTag(source: fight.id, target: action.id)
  THEN "Fight" is deleted
  AND S1 and S2 now have "Action" tag
  AND S3 still has "Action" tag (no duplicates)

TEST: Autocomplete filters correctly
  GIVEN tags ["Action", "Adventure", "Romance"]
  WHEN autocomplete(prefix: "A") is called
  THEN result is ["Action", "Adventure"] in alphabetical order

TEST: Filter AND composition
  GIVEN S1(status: .firstDraft, tags: ["Action"]), S2(status: .firstDraft, tags: ["Romance"]), S3(status: .revised, tags: ["Action"])
  WHEN filter is status=.firstDraft AND tag="Action"
  THEN matching scenes = [S1] only

TEST: Custom singleSelect field constrains values
  GIVEN field "POV" with options ["Alice", "Bob"]
  WHEN setSceneMetadata(S1, "POV", "Charlie")
  THEN error is thrown (value not in allowed options)

TEST: Color label appears in sidebar and cards
  GIVEN S1 has colorLabel .red
  WHEN sidebar and modular mode render S1
  THEN both show a red indicator for S1
```

---

## 6. Implementation Notes

- Tags and metadata are stored in the manifest (per-scene references) and in `metadata/tags.json` (tag definitions). Keep these in sync via `TagManager` — never write to tags.json directly from other modules.
- The `FilterEngine.buildPredicate` method returns a closure `(Scene) -> Bool` that can be applied by any view. This avoids duplicating filter logic across sidebar and modular mode.
- For autocomplete performance, maintain a sorted array of tag names in memory. Binary search for prefix matching.
- Color labels: use a fixed enum (8 colors) rather than arbitrary colors. This keeps the UI consistent and avoids a color picker for a simple organizational tool.
