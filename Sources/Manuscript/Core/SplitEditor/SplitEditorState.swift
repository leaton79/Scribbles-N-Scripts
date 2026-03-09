import Combine
import CoreGraphics
import Foundation

enum SplitOrientation {
    case vertical
    case horizontal
}

@MainActor
final class SplitEditorState: ObservableObject {
    @Published var isSplit: Bool
    @Published var orientation: SplitOrientation
    @Published var primarySceneId: UUID?
    @Published var secondarySceneId: UUID?
    @Published var splitRatio: CGFloat
    @Published var activePaneIndex: Int
    @Published private(set) var isPrimarySearchBarVisible = false
    @Published private(set) var isSecondarySearchBarVisible = false

    let primaryEditor: EditorState
    let secondaryEditor: EditorState

    private let projectManager: ProjectManager

    init(
        projectManager: ProjectManager,
        primarySceneId: UUID? = nil,
        orientation: SplitOrientation = .vertical,
        splitRatio: CGFloat = 0.5
    ) {
        self.projectManager = projectManager
        self.isSplit = false
        self.orientation = orientation
        self.primarySceneId = primarySceneId
        self.secondarySceneId = nil
        self.splitRatio = splitRatio
        self.activePaneIndex = 0

        let loader: (UUID) -> String = { id in
            (try? projectManager.loadSceneContent(sceneId: id)) ?? ""
        }
        self.primaryEditor = EditorState(sceneLoader: loader)
        self.secondaryEditor = EditorState(sceneLoader: loader)

        if let primarySceneId {
            self.primaryEditor.navigateToScene(id: primarySceneId)
        }
    }

    func openSplit(sceneId: UUID) {
        isSplit = true
        secondarySceneId = sceneId
        secondaryEditor.navigateToScene(id: sceneId)
        isSecondarySearchBarVisible = false
    }

    func closeSplit() {
        try? autosaveAllPanes()

        if activePaneIndex == 1, let secondary = secondarySceneId {
            primarySceneId = secondary
            primaryEditor.navigateToScene(id: secondary)
        }

        isSplit = false
        secondarySceneId = nil
        activePaneIndex = 0
        isSecondarySearchBarVisible = false
    }

    func autosaveOpenPanes() {
        try? autosaveAllPanes()
    }

    func swapPanes() {
        guard isSplit else { return }
        (primarySceneId, secondarySceneId) = (secondarySceneId, primarySceneId)

        if let primarySceneId {
            primaryEditor.navigateToScene(id: primarySceneId)
        }
        if let secondarySceneId {
            secondaryEditor.navigateToScene(id: secondarySceneId)
        }

        activePaneIndex = activePaneIndex == 0 ? 1 : 0
    }

    func toggleOrientation() {
        orientation = orientation == .vertical ? .horizontal : .vertical
    }

    func setActivePane(_ paneIndex: Int) {
        activePaneIndex = paneIndex == 1 ? 1 : 0
    }

    func handleFindShortcut() {
        if activePaneIndex == 1, isSplit {
            isSecondarySearchBarVisible = true
            isPrimarySearchBarVisible = false
            return
        }
        isPrimarySearchBarVisible = true
        isSecondarySearchBarVisible = false
    }

    func insertText(_ text: String, inPane paneIndex: Int, at position: Int) {
        editor(forPane: paneIndex).insertText(text, at: position)
        syncIfBothPanesShowSameScene(sourcePaneIndex: paneIndex)
    }

    func replaceText(in range: Range<Int>, with text: String, inPane paneIndex: Int) {
        editor(forPane: paneIndex).replaceText(in: range, with: text)
        syncIfBothPanesShowSameScene(sourcePaneIndex: paneIndex)
    }

    func updateSplitRatio(dividerPosition: CGFloat, totalLength: CGFloat, minimumPaneLength: CGFloat = 250) {
        guard totalLength > 0 else { return }
        let minEdge = max(0, minimumPaneLength)
        let clamped = min(max(dividerPosition, minEdge), totalLength - minEdge)
        splitRatio = min(1, max(0, clamped / totalLength))
    }

    func canUseVerticalSplit(windowWidth: CGFloat, minimumPaneWidth: CGFloat = 250) -> Bool {
        windowWidth >= (minimumPaneWidth * 2)
    }

    private func autosaveAllPanes() throws {
        try primaryEditor.autosaveIfNeeded(projectManager: projectManager)
        if isSplit {
            try secondaryEditor.autosaveIfNeeded(projectManager: projectManager)
        }
    }

    private func editor(forPane paneIndex: Int) -> EditorState {
        paneIndex == 1 ? secondaryEditor : primaryEditor
    }

    private func syncIfBothPanesShowSameScene(sourcePaneIndex: Int) {
        guard isSplit,
              let primary = primarySceneId,
              let secondary = secondarySceneId,
              primary == secondary else {
            return
        }

        let source = editor(forPane: sourcePaneIndex)
        let target = editor(forPane: sourcePaneIndex == 0 ? 1 : 0)
        let newContent = source.getCurrentContent()
        let oldContent = target.getCurrentContent()
        target.replaceText(in: 0..<oldContent.count, with: newContent)
    }
}
