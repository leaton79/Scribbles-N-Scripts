import Combine
import Foundation

@MainActor
final class EditorState: ObservableObject {
    @Published var currentSceneId: UUID?
    @Published var cursorPosition: Int
    @Published var selection: Range<Int>?
    @Published var wordCount: Int
    @Published var characterCount: Int
    @Published var isModified: Bool
    @Published var isFocusMode: Bool
    @Published private(set) var placeholderVisible: Bool
    @Published private(set) var renderedBlocks: [MarkdownBlock]

    private var content: String
    private let parser: MarkdownParser
    private let sceneLoader: ((UUID) -> String)?

    private var undoStack: [UndoEntry] = []
    private var redoStack: [UndoEntry] = []
    private let maxUndoDepth = 500
    private var lastActionType: ActionType?

    init(initialContent: String = "", parser: MarkdownParser = SimpleMarkdownParser(), sceneLoader: ((UUID) -> String)? = nil) {
        self.content = initialContent
        self.parser = parser
        self.sceneLoader = sceneLoader
        self.currentSceneId = nil
        self.cursorPosition = 0
        self.selection = nil
        self.wordCount = WordCounter.count(initialContent)
        self.characterCount = initialContent.count
        self.isModified = false
        self.isFocusMode = false
        self.placeholderVisible = initialContent.isEmpty
        self.renderedBlocks = parser.parse(initialContent)
    }

    func navigateToScene(id: UUID) {
        currentSceneId = id
        content = sceneLoader?(id) ?? ""
        cursorPosition = 0
        selection = nil
        wordCount = WordCounter.count(content)
        characterCount = content.count
        isModified = false
        placeholderVisible = content.isEmpty
        renderedBlocks = parser.parse(content)
        undoStack.removeAll()
        redoStack.removeAll()
        lastActionType = nil
    }

    func insertText(_ text: String, at position: Int) {
        replaceText(in: clampedRange(position..<position), with: text, actionType: .typing)
    }

    func replaceText(in range: Range<Int>, with text: String) {
        replaceText(in: clampedRange(range), with: text, actionType: .structural)
    }

    func pasteRichText(_ text: String, at position: Int) {
        let plain = Self.stripRichText(text)
        replaceText(in: clampedRange(position..<position), with: plain, actionType: .structural)
    }

    func getCurrentContent() -> String {
        content
    }

    func toggleFocusMode() {
        isFocusMode.toggle()
    }

    func chromeVisibility() -> EditorChromeVisibility {
        if isFocusMode {
            return EditorChromeVisibility(showSidebar: false, showInspector: false, showToolbar: false, showStatusBar: false, showFloatingWordCount: true)
        }
        return EditorChromeVisibility(showSidebar: true, showInspector: true, showToolbar: true, showStatusBar: true, showFloatingWordCount: false)
    }

    func undo() {
        guard let entry = undoStack.popLast() else { return }
        applyContent(entry.beforeContent)
        redoStack.append(entry)
        lastActionType = nil
    }

    func redo() {
        guard let entry = redoStack.popLast() else { return }
        applyContent(entry.afterContent)
        undoStack.append(entry)
        lastActionType = nil
    }

    func autosaveIfNeeded(projectManager: ProjectManager) throws {
        guard isModified, let sceneId = currentSceneId else { return }
        try projectManager.saveSceneContent(sceneId: sceneId, content: content)
        isModified = false
    }

    private func replaceText(in range: Range<Int>, with incomingText: String, actionType: ActionType) {
        let text = sanitizeInput(incomingText)
        let previous = content
        let lower = content.index(content.startIndex, offsetBy: range.lowerBound)
        let upper = content.index(content.startIndex, offsetBy: range.upperBound)
        content.replaceSubrange(lower..<upper, with: text)

        let insertedLength = text.count
        cursorPosition = min(content.count, range.lowerBound + insertedLength)
        selection = nil

        if actionType == .typing,
           range.count == 0,
           text.count == 1,
           lastActionType == .typing,
           var last = undoStack.popLast() {
            last.afterContent = content
            undoStack.append(last)
        } else {
            pushUndo(UndoEntry(beforeContent: previous, afterContent: content, actionType: actionType))
        }

        redoStack.removeAll()
        isModified = true
        lastActionType = actionType
        updateDerivedState(editRange: range, newText: text)
    }

    private func applyContent(_ newContent: String) {
        content = newContent
        cursorPosition = min(cursorPosition, content.count)
        updateDerivedState(editRange: 0..<content.count, newText: content, forceFullParse: true)
        isModified = true
    }

    private func updateDerivedState(editRange: Range<Int>, newText: String, forceFullParse: Bool = false) {
        wordCount = WordCounter.count(content)
        characterCount = content.count
        placeholderVisible = content.isEmpty

        if forceFullParse {
            renderedBlocks = parser.parse(content)
        } else {
            renderedBlocks = parser.incrementalUpdate(editRange: editRange, newText: newText, existingBlocks: renderedBlocks)
        }
    }

    private func sanitizeInput(_ text: String) -> String {
        text.replacingOccurrences(of: "\t", with: String(repeating: " ", count: 4))
    }

    private func pushUndo(_ entry: UndoEntry) {
        undoStack.append(entry)
        if undoStack.count > maxUndoDepth {
            undoStack.removeFirst(undoStack.count - maxUndoDepth)
        }
    }

    private func clampedRange(_ range: Range<Int>) -> Range<Int> {
        let lower = max(0, min(range.lowerBound, content.count))
        let upper = max(lower, min(range.upperBound, content.count))
        return lower..<upper
    }

    private static func stripRichText(_ text: String) -> String {
        let withoutTags = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

struct EditorChromeVisibility {
    var showSidebar: Bool
    var showInspector: Bool
    var showToolbar: Bool
    var showStatusBar: Bool
    var showFloatingWordCount: Bool
}

private struct UndoEntry {
    var beforeContent: String
    var afterContent: String
    var actionType: ActionType
}

private enum ActionType {
    case typing
    case structural
}
