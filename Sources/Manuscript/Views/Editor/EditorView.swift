import SwiftUI

struct EditorView: View {
    @ObservedObject var state: EditorState

    var body: some View {
        ZStack(alignment: .topLeading) {
            if state.placeholderVisible {
                Text("Start writing...")
                    .foregroundStyle(.secondary)
                    .padding(8)
            }

            TextEditor(
                text: Binding(
                    get: { state.getCurrentContent() },
                    set: { newValue in
                        let old = state.getCurrentContent()
                        state.replaceText(in: 0..<old.count, with: newValue)
                    }
                )
            )
        }
    }
}
