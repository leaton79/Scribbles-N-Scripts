import SwiftUI

struct LinearModeView: View {
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var editorState: EditorState
    @ObservedObject var linearState: LinearModeState
    var presentation = EditorPresentationSettings.default

    func goToNextScene() {
        linearState.goToNextScene()
    }

    func goToPreviousScene() {
        linearState.goToPreviousScene()
    }

    func goToScene(id: UUID) {
        linearState.goToScene(id: id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if linearState.beginningIndicatorVisible {
                Text("Beginning of manuscript")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            EditorView(state: editorState, presentation: presentation)

            ForEach(linearState.boundaries, id: \.followingSceneId) { boundary in
                Divider()
                if boundary.chapterBreak, let chapterTitle = boundary.chapterTitle {
                    Text("Chapter: \(chapterTitle)")
                        .font(.headline)
                }
            }
        }
    }
}
