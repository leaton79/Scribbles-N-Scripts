# Module 09: Find & Replace
## Manuscript — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 02 (Editor) — inline highlight and replace in current scene; Module 01 (Project I/O) — loads scene content for project-wide search
> **Exposes**: `SearchEngine` — project-wide indexed search, regex, scoped search, replace operations

---

## 1. Purpose

Full-text search and replace across the entire project. Supports plain text, regex, scoped search, and batch replace. Includes a background search index for instant project-wide results.

---

## 2. Interface Specification

```swift
protocol SearchEngine {
    // Index management
    func buildIndex(for project: Project) async      // Called at project open
    func updateIndex(sceneId: UUID, content: String)  // Called on scene save
    
    // Search
    func search(query: SearchQuery) -> [SearchResult]
    func searchCount(query: SearchQuery) -> Int
    
    // Replace
    func replaceNext(in editorState: EditorState, replacement: String)
    func replaceAll(query: SearchQuery, replacement: String) throws -> ReplaceReport
}

struct SearchQuery {
    var text: String
    var isRegex: Bool                    // Default: false
    var isCaseSensitive: Bool            // Default: false
    var isWholeWord: Bool                // Default: false
    var scope: SearchScope
}

enum SearchScope {
    case currentScene
    case currentChapter
    case selectedChapters(ids: [UUID])
    case entireProject
    case markdownFormatting(MarkdownElement)  // Find by format type
}

enum MarkdownElement {
    case heading(level: Int?)            // nil = any heading level
    case bold, italic, strikethrough
    case codeBlock, inlineCode
    case blockQuote, link, footnote
}

struct SearchResult {
    let sceneId: UUID
    let sceneTitle: String
    let chapterTitle: String
    let matchRange: Range<Int>           // Character range in scene content
    let contextSnippet: String           // ~50 chars surrounding the match
    let matchText: String                // The actual matched text
}

struct ReplaceReport {
    let replacementCount: Int
    let scenesAffected: Int
    let errors: [ReplaceError]           // Scenes that couldn't be modified
}
```

---

## 3. Behavioral Specification

### 3.1 Inline Search (Cmd+F)
- **Given** user presses Cmd+F in the editor
- **When** the search bar appears
- **Then** a text field is shown inline at the top of the editor. As the user types, all matches in the current scene are highlighted (yellow background). The current match (navigated to) has a distinct highlight (orange). Match count is displayed (e.g., "3 of 12"). Enter moves to the next match; Shift+Enter moves to the previous match.

### 3.2 Project-Wide Search (Cmd+Shift+F)
- **Given** user presses Cmd+Shift+F
- **When** the project search panel opens
- **Then** a search input is shown with scope controls (dropdown: Current Scene, Current Chapter, Entire Project). Results are grouped by chapter → scene. Each result shows the scene title and a context snippet with the match highlighted. Clicking a result navigates to that scene and positions the cursor at the match.

### 3.3 Regex Search
- **Given** the regex toggle is enabled and the user enters `\b[A-Z]{2,}\b`
- **When** search executes
- **Then** all sequences of 2+ uppercase letters bounded by word boundaries are matched. Invalid regex patterns show an inline error message ("Invalid regex: [error details]") without crashing.

### 3.4 Replace All
- **Given** a project-wide search for "colour" with replacement "color"
- **When** Replace All is clicked
- **Then** a preview shows: "42 replacements across 15 scenes. Proceed?" On confirm, all replacements are made, all affected scenes are saved, and the entire Replace All operation is a single undo entry (undoing reverts ALL 42 replacements).

### 3.5 Find by Formatting
- **Given** scope set to `markdownFormatting(.italic)`
- **When** search executes
- **Then** all text wrapped in `*...*` or `_..._` is matched across the specified scope. Results show the formatted text with its location.

### 3.6 Search Index
- **Given** a project is opened
- **When** the search index builds asynchronously
- **Then** project-wide search is available once indexing completes. Before indexing completes, project-wide search falls back to sequential file scanning (slower but functional). A subtle indicator shows "Indexing... (75%)" during build.

- **Given** a scene is saved
- **When** `updateIndex` is called
- **Then** only that scene's index entries are updated (incremental, not full rebuild).

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Empty search string | Disable search button. Show no results. |
| Search string matches inside Markdown syntax (e.g., searching for "**" finds bold markers) | Plain text search operates on raw Markdown content — it will find syntax characters. Find by formatting (`MarkdownElement`) should be recommended for structural searches. |
| Replace in a regex search with capture groups | Support `$1`, `$2`, etc. in replacement strings. Example: search `(\w+)-(\w+)` replace `$2-$1` swaps hyphenated words. |
| Replace All across 100+ scenes | Batch operation. Load each affected scene, apply replacements, save. Progress indicator. All changes are saved atomically per scene. If any scene fails, report the error and continue with remaining scenes. |
| Concurrent search while editing | Search results are based on the last saved content + current unsaved content for the active scene. Other scenes use their on-disk content. |
| Search result in deleted (trashed) scene | Trash is not searchable. Only active manuscript content is indexed. |
| Very large scene (50K chars) with 500 matches | All matches are found but only the first 100 are highlighted in the editor for performance. A "Show all highlights" option overrides. |

---

## 5. Test Cases

```
TEST: Inline search highlights all matches
  GIVEN a scene with content "the cat sat on the mat near the cat"
  WHEN Cmd+F and "the" is typed (case-insensitive)
  THEN 3 matches are highlighted
  AND match counter shows "1 of 3"

TEST: Project-wide search returns grouped results
  GIVEN S1 contains "dragon" twice and S3 contains "dragon" once
  WHEN project-wide search for "dragon" executes
  THEN results include 3 entries: 2 under S1, 1 under S3
  AND each result has a context snippet

TEST: Regex search works
  GIVEN a scene with "Phone: 555-1234 and 555-5678"
  WHEN regex search `\d{3}-\d{4}` executes
  THEN 2 matches: "555-1234" and "555-5678"

TEST: Invalid regex shows error
  GIVEN user enters "[unclosed" with regex enabled
  WHEN search executes
  THEN an error message is shown inline
  AND no crash occurs

TEST: Replace All is single undo operation
  GIVEN "color" appears in 3 scenes (5 total occurrences)
  WHEN Replace All "color" → "colour" is confirmed
  THEN 5 replacements are made across 3 scenes
  AND one Cmd+Z reverts all 5 replacements

TEST: Replace with regex capture groups
  GIVEN content "John-Smith"
  WHEN regex search `(\w+)-(\w+)` replace `$2, $1`
  THEN result is "Smith, John"

TEST: Search index incremental update
  GIVEN index is built and S1 is modified
  WHEN updateIndex(S1.id, newContent) is called
  THEN searching for new content in S1 returns results
  AND searching for removed content returns no results for S1

TEST: Find by formatting (italic)
  GIVEN scene content: "She was *absolutely* certain about the _plan_."
  WHEN search for markdownFormatting(.italic) executes
  THEN 2 matches: "absolutely" and "plan"
```

---

## 6. Implementation Notes

- For the search index, consider an inverted index (word → set of scene IDs + character offsets). Build from all scene content at project open. Store in memory only (not persisted — rebuilt on each open for simplicity).
- Inline search highlighting: work with the editor's attributed string layer to add temporary background color attributes to match ranges. These are display-only and not part of the content.
- For Replace All across multiple scenes: load each scene's content, apply replacements using `String.replacingOccurrences` (or regex equivalent), save, update index. Process sequentially to avoid file I/O contention.
- The "single undo entry" for Replace All: record the inverse operation (all original texts at their positions) as one undo group. On undo, restore all affected scenes' content from the recorded state.
- Whole-word matching: wrap the search pattern in word boundary anchors `\b...\b` when the option is enabled.
