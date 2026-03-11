import SwiftUI

struct SplitEditorView: View {
    @ObservedObject var state: SplitEditorState
    var presentation = EditorPresentationSettings.default

    var body: some View {
        Group {
            if state.isSplit, let _ = state.secondarySceneId {
                if state.orientation == .vertical {
                    HStack(spacing: 0) {
                        EditorView(state: state.primaryEditor, presentation: presentation)
                        Divider()
                        EditorView(state: state.secondaryEditor, presentation: presentation)
                    }
                } else {
                    VStack(spacing: 0) {
                        EditorView(state: state.primaryEditor, presentation: presentation)
                        Divider()
                        EditorView(state: state.secondaryEditor, presentation: presentation)
                    }
                }
            } else {
                EditorView(state: state.primaryEditor, presentation: presentation)
            }
        }
    }
}
