import SwiftUI

struct ModeContainerView: View {
    @ObservedObject var modeController: ModeController
    @ObservedObject var linearState: LinearModeState
    @ObservedObject var modularState: ModularModeState
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var editorState: EditorState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if modeController.activeMode == .linear {
                LinearModeView(
                    navigationState: navigationState,
                    editorState: editorState,
                    linearState: linearState
                )
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
