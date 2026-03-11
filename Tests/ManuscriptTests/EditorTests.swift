import XCTest
@testable import ScribblesNScripts

@MainActor
final class EditorTests: XCTestCase {
    func testMarkdownHeadingRendersCorrectly() {
        let parser = SimpleMarkdownParser()
        let blocks = parser.parse("## Test Heading\n")

        guard case let .heading(level, text, _) = blocks.first else {
            return XCTFail("Expected heading block")
        }

        XCTAssertEqual(level, 2)
        XCTAssertEqual(String(text.characters), "Test Heading")
        XCTAssertTrue(SimpleMarkdownParser.shouldRevealRawMarkdown(cursorPosition: 1, block: blocks[0]))
    }

    func testIncrementalParseOnKeystrokeReparsesLimitedScope() {
        let parser = SimpleMarkdownParser()
        let paragraphs = (0..<200).map { "Paragraph \($0)" }.joined(separator: "\n")
        var blocks = parser.parse(paragraphs)

        let targetText = "Paragraph 100"
        let pos = paragraphs.range(of: targetText)?.lowerBound
        let offset = paragraphs.distance(from: paragraphs.startIndex, to: pos!)

        blocks = parser.incrementalUpdate(editRange: offset..<offset, newText: "X", existingBlocks: blocks)

        _ = blocks
        XCTAssertNotNil(parser.lastIncrementalReparseRange)
        XCTAssertLessThanOrEqual(parser.lastIncrementalReparsedBlockCount, 3)
    }

    func testBlockBasedRenderingLimitsNodeCount() {
        let parser = SimpleMarkdownParser()
        let text = (0..<500).map { "Paragraph \($0)" }.joined(separator: "\n")
        let blocks = parser.parse(text)

        let visible = BlockRenderer.visibleBlocks(allBlocks: blocks, centeredAt: 250, visibleCount: 10, buffer: 10, maxRendered: 30)
        XCTAssertLessThanOrEqual(visible.count, 30)
    }

    func testPasteIsSingleUndoOperation() {
        let state = EditorState(initialContent: "Hello")
        state.pasteRichText("World", at: 5)
        XCTAssertEqual(state.getCurrentContent(), "HelloWorld")

        state.undo()
        XCTAssertEqual(state.getCurrentContent(), "Hello")
    }

    func testContiguousTypingGroupsForUndo() {
        let state = EditorState(initialContent: "")
        for ch in "Hello World" {
            state.insertText(String(ch), at: state.cursorPosition)
        }
        XCTAssertEqual(state.getCurrentContent(), "Hello World")

        state.undo()
        XCTAssertEqual(state.getCurrentContent(), "")
    }

    func testFocusModeHidesChrome() {
        let state = EditorState(initialContent: "Hello")
        let normal = state.chromeVisibility()
        XCTAssertTrue(normal.showSidebar)
        XCTAssertTrue(normal.showInspector)

        state.toggleFocusMode()
        let focus = state.chromeVisibility()
        XCTAssertFalse(focus.showSidebar)
        XCTAssertFalse(focus.showInspector)
        XCTAssertTrue(focus.showFloatingWordCount)

        state.toggleFocusMode()
        XCTAssertTrue(state.chromeVisibility().showSidebar)
    }

    func testWordCountHandlesCJKText() {
        XCTAssertEqual(WordCounter.count("Hello 世界 test"), 4)
    }

    func testEmptySceneShowsPlaceholder() {
        let state = EditorState(initialContent: "")
        XCTAssertTrue(state.placeholderVisible)

        state.insertText("A", at: 0)
        XCTAssertFalse(state.placeholderVisible)
    }

    func testExternalRichTextPasteStripsFormatting() {
        let state = EditorState(initialContent: "")
        state.pasteRichText("<b>Hello</b> <span style=\"color:red\">World</span>", at: 0)
        XCTAssertEqual(state.getCurrentContent(), "Hello World")
    }
}
