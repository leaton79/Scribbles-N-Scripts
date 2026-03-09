# Module 02: Editor
## Manuscript — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 01 (Project I/O) — consumes `ProjectManager.loadSceneContent()`, `saveSceneContent()`
> **Exposes**: `EditorView`, `EditorState`, Markdown parser, word count computation

---

## 1. Purpose

The core text editing surface. Plain text input with live inline Markdown rendering. Must handle scenes up to 50,000 characters with zero perceptible lag. This is the component users interact with 95% of the time.

---

## 2. Interface Specification

```swift
// State published to other modules
class EditorState: ObservableObject {
    @Published var currentSceneId: UUID?
    @Published var cursorPosition: Int           // Character offset
    @Published var selection: Range<Int>?         // nil = no selection
    @Published var wordCount: Int                 // Current scene
    @Published var characterCount: Int
    @Published var isModified: Bool               // Unsaved changes in current scene
    @Published var isFocusMode: Bool
    
    func navigateToScene(id: UUID)
    func insertText(_ text: String, at position: Int)
    func replaceText(in range: Range<Int>, with text: String)
    func getCurrentContent() -> String
}

// Markdown parser interface
protocol MarkdownParser {
    func parse(_ text: String) -> [MarkdownBlock]
    func incrementalUpdate(editRange: Range<Int>, newText: String, existingBlocks: [MarkdownBlock]) -> [MarkdownBlock]
}

enum MarkdownBlock {
    case heading(level: Int, text: AttributedString, sourceRange: Range<Int>)
    case paragraph(text: AttributedString, sourceRange: Range<Int>)
    case blockQuote(blocks: [MarkdownBlock], sourceRange: Range<Int>)
    case codeBlock(language: String?, code: String, sourceRange: Range<Int>)
    case horizontalRule(sourceRange: Range<Int>)
    case footnote(id: String, content: AttributedString, sourceRange: Range<Int>)
}

// Word count utility
struct WordCounter {
    static func count(_ text: String) -> Int
    static func readingTimeMinutes(_ wordCount: Int) -> Int  // Assumes 250 WPM
}
```

---

## 3. Behavioral Specification

### 3.1 Markdown Rendering
- **Given** the user types `## My Chapter Title`
- **When** the line is committed (cursor moves away or a newline is entered)
- **Then** the text renders inline as a styled heading: larger font size, bold, styled per H2 definition. The raw Markdown syntax characters (`##`) are either hidden or dimmed (configurable). The user can place their cursor back on the line to see/edit the raw syntax.

- **Given** the user types `**bold text**`
- **When** the closing `**` is typed
- **Then** the text between markers renders as bold. Markers dim or hide. Cursor placement on the text reveals markers.

**Supported Markdown elements and their rendering:**

| Syntax | Rendering | Notes |
|--------|-----------|-------|
| `# H1` through `###### H6` | Scaled heading sizes, bold | Dimmed `#` markers |
| `**bold**` | Bold | Dimmed markers |
| `*italic*` or `_italic_` | Italic | Dimmed markers |
| `~~strikethrough~~` | Strikethrough | Dimmed markers |
| `` `inline code` `` | Monospace with subtle background | |
| ` ``` ` code blocks | Syntax-highlighted monospace block | Language hint after opening fence |
| `> blockquote` | Indented with left border | |
| `---` or `***` | Horizontal rule | |
| `[text](url)` | Styled link text, Cmd+click opens URL | URL portion dimmed |
| `[^1]` footnote markers | Superscript number, hover shows footnote content | Footnote content at bottom of scene |

### 3.2 Block-Based Rendering
- **Given** a scene with 500 paragraphs
- **When** the editor is displaying paragraph 250
- **Then** only paragraphs ~240–260 (visible + 10-block buffer) are rendered to the view. Scrolling loads new blocks and unloads distant ones.

- **Performance constraint**: Scrolling through the document at maximum trackpad velocity shall not produce blank/unrendered areas visible for more than 1 frame (16ms).

### 3.3 Editing Operations
- **Given** the user types a character
- **When** the keystroke is processed
- **Then** the character is inserted at the cursor position, the Markdown parser runs an incremental update (not a full reparse), the word count updates, and `EditorState.isModified` becomes true.
- **Performance**: Total time from keystroke to rendered output ≤ 16ms.

- **Given** the user pastes 10,000 characters
- **When** the paste operation is processed
- **Then** the text is inserted, a full reparse of affected blocks occurs (not the entire document), word count updates, and the operation is recorded as a single undo entry.

### 3.4 Undo/Redo
- **Given** a series of typing operations
- **When** the user presses Cmd+Z
- **Then** the most recent contiguous typing operation is undone as a group (characters typed without repositioning the cursor are grouped). Structural operations (paste, find/replace) are individual undo entries.

- Undo stack depth: minimum 500 operations.
- Undo stack persists in memory for the session. NOT persisted to disk (cleared on scene close/reopen).

### 3.5 Focus Mode
- **Given** the user activates focus mode (Cmd+Shift+F)
- **When** focus mode is active
- **Then** all UI chrome (sidebar, inspector, toolbar, status bar) is hidden. Only the editor and a minimal floating word count are visible. Text outside the current paragraph (or current scene, configurable) is dimmed to 30% opacity. Optional typewriter scrolling keeps the active line vertically centered.

### 3.6 Autosave Integration
- **Given** `EditorState.isModified` is true
- **When** the autosave timer fires (from Module 01)
- **Then** `ProjectManager.saveSceneContent(sceneId:, content:)` is called with the current content, the word count in the manifest is updated, and `isModified` is set to false.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| Scene content is empty | Render placeholder text ("Start writing...") dimmed. First keystroke replaces placeholder. |
| Extremely long line (10,000+ chars, no line breaks) | Soft-wrap at editor width. Never horizontal scroll for prose. |
| Invalid Markdown (e.g., unclosed `**`) | Render as plain text. Never crash or produce broken rendering. The parser must be error-tolerant. |
| Cursor at Markdown boundary | When cursor is adjacent to a Markdown marker (e.g., right after `**`), always show the raw markers for the enclosing element to allow editing. |
| Copy/paste from external rich text | Strip all formatting. Paste as plain text only. Preserve line breaks. |
| Tab key | Insert configurable spaces (default: 4 spaces for code blocks, or trigger indentation). Never insert literal tab character in prose. In code blocks, insert tab/spaces per preference. |
| Scene with 50,000+ characters | Must remain responsive. This is the upper bound for a single scene — the app should suggest splitting but not enforce it. |
| Right-to-left text | Respect system BiDi settings. Paragraph direction follows the first strong character. |
| Emoji and CJK characters | Full Unicode support. Word count treats CJK characters as 1 word per character (industry standard for CJK word count). |

---

## 5. Test Cases

```
TEST: Markdown heading renders correctly
  GIVEN an empty scene
  WHEN the user types "## Test Heading\n"
  THEN the text "Test Heading" is rendered at H2 size
  AND the "## " prefix is visually dimmed or hidden
  AND placing the cursor on the heading line reveals the raw "## " prefix

TEST: Incremental parse on keystroke
  GIVEN a scene with 200 paragraphs
  WHEN the user types one character in paragraph 100
  THEN only paragraph 100 is reparsed (verify by checking parse call scope)
  AND total keystroke-to-render time is ≤16ms

TEST: Block-based rendering limits DOM nodes
  GIVEN a scene with 500 paragraphs
  WHEN scrolled to paragraph 250
  THEN rendered block count is ≤30 (visible + buffer)
  AND memory usage does not scale linearly with paragraph count

TEST: Paste is a single undo operation
  GIVEN a scene with content "Hello"
  WHEN the user pastes "World" at the end
  AND then presses Cmd+Z
  THEN the content reverts to "Hello" (not "HelloWorl")

TEST: Contiguous typing groups for undo
  GIVEN an empty scene
  WHEN the user types "Hello World" (11 keystrokes, no cursor repositioning)
  AND then presses Cmd+Z
  THEN the content reverts to empty (entire typing burst undone as one group)

TEST: Focus mode hides chrome
  GIVEN the app is in normal mode with sidebar and inspector visible
  WHEN Cmd+Shift+F is pressed
  THEN sidebar, inspector, toolbar, and status bar are hidden
  AND only the editor and a minimal word count display remain
  AND pressing Cmd+Shift+F again restores all chrome

TEST: Word count handles CJK text
  GIVEN a scene with content "Hello 世界 test"
  WHEN word count is computed
  THEN word count is 4 (Hello, 世, 界, test)

TEST: Empty scene shows placeholder
  GIVEN a newly created scene with no content
  WHEN the editor displays the scene
  THEN placeholder text is visible and dimmed
  AND typing the first character replaces the placeholder entirely

TEST: External rich text paste strips formatting
  GIVEN rich text on the clipboard (HTML with bold, colors, etc.)
  WHEN the user pastes into the editor
  THEN only plain text is inserted
  AND Markdown syntax is not auto-generated from the formatting
```

---

## 6. Implementation Notes

- Consider building on `NSTextView` (AppKit) rather than SwiftUI `TextEditor` for the level of control needed (block rendering, custom Markdown styling, performance). Wrap in `NSViewRepresentable` for SwiftUI integration.
- The Markdown parser should operate on a per-block basis. Use a two-pass approach: (1) block-level parse to identify headings, paragraphs, code blocks, etc., (2) inline-level parse within each block for bold, italic, links, etc.
- For incremental parsing: maintain a mapping from character ranges to blocks. On edit, identify which blocks' source ranges are affected, reparse only those blocks.
- Syntax highlighting for code blocks: use a lightweight library like `Highlightr` or `TreeSitter` bindings. Limit to the top 10 languages by default; extensible.
- Typewriter scrolling in focus mode: after each keystroke, animate the scroll position so the cursor line is at a fixed vertical position (e.g., 40% from top).
