import Combine
import Foundation

@MainActor
final class ModeController: ObservableObject {
    @Published var activeMode: ViewMode
    @Published private(set) var toastMessage: String?

    private let projectManager: ProjectManager
    private let navigationState: NavigationState
    private let editorState: EditorState
    private let linearState: LinearModeState
    private let modularState: ModularModeState

    private var linearPositions: [UUID: LinearPosition] = [:]
    private var modularPositions: [UUID: ModularPosition] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(
        projectManager: ProjectManager,
        navigationState: NavigationState,
        editorState: EditorState,
        linearState: LinearModeState,
        modularState: ModularModeState,
        initialMode: ViewMode = .linear
    ) {
        self.projectManager = projectManager
        self.navigationState = navigationState
        self.editorState = editorState
        self.linearState = linearState
        self.modularState = modularState
        self.activeMode = initialMode

        editorState.$cursorPosition
            .sink { [weak self] cursor in
                guard let self, let sceneId = self.editorState.currentSceneId else { return }
                self.linearPositions[sceneId] = LinearPosition(sceneId: sceneId, cursorOffset: cursor)
            }
            .store(in: &cancellables)
    }

    func switchMode() {
        switchTo(activeMode == .linear ? .modular : .linear)
    }

    func switchTo(_ mode: ViewMode) {
        guard activeMode != mode else { return }

        switch (activeMode, mode) {
        case (.linear, .modular):
            switchLinearToModular()
        case (.modular, .linear):
            switchModularToLinear()
        default:
            break
        }

        activeMode = mode
    }

    func positionInLinearMode(for sceneId: UUID) -> LinearPosition {
        linearPositions[sceneId] ?? LinearPosition(sceneId: sceneId, cursorOffset: nil)
    }

    func positionInModularMode(for sceneId: UUID) -> ModularPosition {
        modularPositions[sceneId] ?? ModularPosition(sceneId: sceneId, groupScrollOffset: nil)
    }

    func clearToast() {
        toastMessage = nil
    }

    private func switchLinearToModular() {
        if editorState.isModified {
            try? editorState.autosaveIfNeeded(projectManager: projectManager)
        }

        guard let sceneId = editorState.currentSceneId else { return }
        modularState.selectCard(sceneId: sceneId)
        navigationState.navigateTo(sceneId: sceneId)
        modularPositions[sceneId] = ModularPosition(sceneId: sceneId, groupScrollOffset: nil)
    }

    private func switchModularToLinear() {
        let selected = modularState.selectedSceneIds.first ?? navigationState.selectedSceneId
        let linearSceneSet = Set(linearState.orderedSceneIds)

        guard let selected else {
            if let first = linearState.orderedSceneIds.first {
                linearState.goToScene(id: first)
                restoreCursorIfKnown(for: first)
            }
            return
        }

        guard linearSceneSet.contains(selected) else {
            if let first = linearState.orderedSceneIds.first {
                linearState.goToScene(id: first)
                restoreCursorIfKnown(for: first)
                toastMessage = "Staging scenes are not visible in linear mode."
            }
            return
        }

        linearState.goToScene(id: selected)
        restoreCursorIfKnown(for: selected)
    }

    private func restoreCursorIfKnown(for sceneId: UUID) {
        guard let pos = linearPositions[sceneId], let offset = pos.cursorOffset else {
            editorState.cursorPosition = 0
            return
        }
        editorState.cursorPosition = max(0, min(offset, editorState.getCurrentContent().count))
    }
}

enum ViewMode {
    case linear
    case modular
}

struct LinearPosition {
    let sceneId: UUID
    let cursorOffset: Int?
}

struct ModularPosition {
    let sceneId: UUID
    let groupScrollOffset: CGFloat?
}
