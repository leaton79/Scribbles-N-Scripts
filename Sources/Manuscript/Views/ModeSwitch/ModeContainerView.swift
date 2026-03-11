import SwiftUI

struct ModeContainerView: View {
    @ObservedObject var modeController: ModeController
    @ObservedObject var linearState: LinearModeState
    @ObservedObject var modularState: ModularModeState
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var editorState: EditorState
    @ObservedObject var splitState: SplitEditorState
    var editorPresentation = EditorPresentationSettings.default

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if modeController.activeMode == .linear {
                Group {
                    if splitState.isSplit {
                        SplitEditorView(state: splitState, presentation: editorPresentation)
                    } else {
                        LinearModeView(
                            navigationState: navigationState,
                            editorState: editorState,
                            linearState: linearState,
                            presentation: editorPresentation
                        )
                    }
                }
                .transition(.opacity)
            } else {
                ModularModeView(
                    navigationState: navigationState,
                    editorState: editorState,
                    grouping: modularState.grouping,
                    activeFilters: modularState.activeFilters,
                    modularState: modularState
                )
                .transition(.opacity)
            }

            Button(modeController.activeMode == .linear ? "Modular" : "Linear") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    modeController.switchMode()
                }
            }
            .padding()
        }
    }
}
