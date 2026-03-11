import SwiftUI

struct SplitEditorView: View {
    @ObservedObject var state: SplitEditorState
    var presentation = EditorPresentationSettings.default

    var body: some View {
        Group {
            if state.isSplit, let _ = state.secondarySceneId {
                if state.orientation == .vertical {
                    HStack(spacing: 0) {
                        centeredEditor(EditorView(state: state.primaryEditor, presentation: presentation))
                        Divider()
                        centeredEditor(EditorView(state: state.secondaryEditor, presentation: presentation))
                    }
                } else {
                    VStack(spacing: 0) {
                        centeredEditor(EditorView(state: state.primaryEditor, presentation: presentation))
                        Divider()
                        centeredEditor(EditorView(state: state.secondaryEditor, presentation: presentation))
                    }
                }
            } else {
                centeredEditor(EditorView(state: state.primaryEditor, presentation: presentation))
            }
        }
    }

    @ViewBuilder
    private func centeredEditor<Content: View>(_ content: Content) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content
                .frame(maxWidth: presentation.contentWidth, maxHeight: .infinity)
            Spacer(minLength: 0)
        }
    }
}
