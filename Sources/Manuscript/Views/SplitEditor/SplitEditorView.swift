import SwiftUI

struct SplitEditorView: View {
    @ObservedObject var state: SplitEditorState

    var body: some View {
        Group {
            if state.isSplit, let _ = state.secondarySceneId {
                if state.orientation == .vertical {
                    HStack(spacing: 0) {
                        EditorView(state: state.primaryEditor)
                        Divider()
                        EditorView(state: state.secondaryEditor)
                    }
                } else {
                    VStack(spacing: 0) {
                        EditorView(state: state.primaryEditor)
                        Divider()
                        EditorView(state: state.secondaryEditor)
                    }
                }
            } else {
                EditorView(state: state.primaryEditor)
            }
        }
    }
}
