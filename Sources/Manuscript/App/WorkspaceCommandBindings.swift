import Foundation
import SwiftUI

@MainActor
struct WorkspaceCommandBindings {
    let workspace: WorkspaceCoordinator

    var canSaveProject: Bool {
        workspace.hasOpenProject && workspace.canSaveProject
    }

    var canCreateProjectContent: Bool {
        workspace.hasOpenProject && !workspace.isRecoveryMode
    }

    var canShowImportExport: Bool {
        workspace.canShowImportExport
    }

    var canReopenLastProject: Bool {
        workspace.canReopenLastProject
    }

    var recentProjects: [RecentProjectEntry] {
        workspace.recentProjects
    }

    var switchableProjects: [RecentProjectEntry] {
        workspace.switchableProjects
    }

    var canClearRecentProjects: Bool {
        workspace.canClearRecentProjects
    }

    var hasStaleRecentProjects: Bool {
        workspace.hasStaleRecentProjects
    }

    var canSaveProjectAs: Bool {
        workspace.canSaveProjectAs
    }

    var canRenameProject: Bool {
        workspace.canRenameProject
    }

    var canCreateBackup: Bool {
        workspace.hasOpenProject && !workspace.isRecoveryMode
    }

    var canSaveAndBackup: Bool {
        workspace.hasOpenProject && !workspace.isRecoveryMode
    }

    var canSwitchToLinearMode: Bool {
        workspace.canSwitchToLinearMode
    }

    var canSwitchToModularMode: Bool {
        workspace.canSwitchToModularMode
    }

    var canToggleSplitEditor: Bool {
        workspace.canToggleSplitEditor
    }

    var canToggleInspector: Bool {
        workspace.canToggleInspector
    }

    var canNavigateToPreviousScene: Bool {
        workspace.canNavigateToPreviousScene
    }

    var canNavigateToNextScene: Bool {
        workspace.canNavigateToNextScene
    }

    var canSearchProject: Bool {
        workspace.hasOpenProject
    }

    var canUseModularPresentationControls: Bool {
        workspace.canUseModularPresentationControls
    }

    var canCreateSceneBelow: Bool {
        workspace.canCreateSceneBelow
    }

    var canDuplicateSelectedScene: Bool {
        workspace.canDuplicateSelectedScene
    }

    var canMoveSelectedSceneUp: Bool {
        workspace.canMoveSelectedSceneUp
    }

    var canMoveSelectedSceneDown: Bool {
        workspace.canMoveSelectedSceneDown
    }

    var canRevealSelectionInSidebar: Bool {
        workspace.canRevealSelectionInSidebar
    }

    var canSendSelectedSceneToStaging: Bool {
        workspace.canSendSelectedSceneToStaging
    }

    var canMoveSelectedSceneToAnotherChapter: Bool {
        workspace.canMoveSelectedSceneToAnotherChapter
    }

    var canOpenSelectionInSplit: Bool {
        workspace.canOpenSelectionInSplit
    }

    var canToggleSearchHighlightDisplayMode: Bool {
        workspace.canToggleSearchHighlightMode
    }

    var searchHighlightToggleTitle: String {
        workspace.searchShowAllHighlights ? "Use Capped Highlights" : "Show All Highlights"
    }

    var canResetSearchHighlightSettings: Bool {
        !workspace.usesDefaultSearchHighlightPreferences
    }

    var canBulkSelectReplaceScenes: Bool {
        workspace.canBulkSelectReplaceScenes
    }

    var canUndoLastReplaceBatch: Bool {
        workspace.canUndoLastReplaceBatch
    }

    var canRedoLastReplaceBatch: Bool {
        workspace.canRedoLastReplaceBatch
    }

    var replaceUndoMenuTitle: String {
        let depth = workspace.replaceUndoDepth
        if depth > 1 {
            return "Undo Last Replace Batch (\(depth) available)"
        }
        return "Undo Last Replace Batch"
    }

    var replaceRedoMenuTitle: String {
        let depth = workspace.replaceRedoDepth
        if depth > 1 {
            return "Redo Last Replace Batch (\(depth) available)"
        }
        return "Redo Last Replace Batch"
    }

    var searchResultPositionText: String {
        workspace.searchResultPositionText
    }

    var currentSearchResultIndex: Int? {
        workspace.currentSearchResultIndex
    }

    var splitToggleTitle: String {
        workspace.splitEditorState.isSplit ? "Close Split" : "Toggle Split"
    }

    var inspectorToggleTitle: String {
        workspace.inspectorToggleTitle
    }

    @discardableResult
    func createProject(named name: String) -> String? {
        workspace.createAndOpenProject(named: name)
    }

    @discardableResult
    func openProject(at url: URL) -> String? {
        workspace.openProject(at: url)
    }

    @discardableResult
    func reopenLastProject() -> String? {
        workspace.reopenLastProject()
    }

    func clearRecentProjects() {
        workspace.clearRecentProjects()
    }

    func snapshotRecentProjects() -> RecentProjectsSnapshot {
        workspace.snapshotRecentProjects()
    }

    func restoreRecentProjects(from snapshot: RecentProjectsSnapshot) {
        workspace.restoreRecentProjects(from: snapshot)
    }

    func cleanupMissingRecentProjects() {
        workspace.cleanupMissingRecentProjects()
    }

    @discardableResult
    func saveProjectAs(named name: String) -> String? {
        workspace.saveProjectAs(named: name)
    }

    @discardableResult
    func renameProject(to name: String) -> String? {
        workspace.renameCurrentProject(to: name)
    }

    @discardableResult
    func saveProject() -> String? {
        workspace.saveProjectNow()
    }

    @discardableResult
    func exportRecoveryProject(format: ExportFormat) -> String? {
        workspace.exportRecoveryProject(format: format)
    }

    @discardableResult
    func duplicateRecoveryProject() -> String? {
        workspace.duplicateRecoveryProjectAsWritableCopy()
    }

    @discardableResult
    func createChapter() -> String? {
        workspace.createChapter()
    }

    @discardableResult
    func createScene() -> String? {
        workspace.createScene()
    }

    @discardableResult
    func createSceneBelow() -> String? {
        workspace.createSceneBelowCurrent()
    }

    @discardableResult
    func duplicateSelectedScene() -> String? {
        workspace.duplicateSelectedScene()
    }

    @discardableResult
    func moveSelectedSceneUp() -> String? {
        workspace.moveSelectedSceneUp()
    }

    @discardableResult
    func moveSelectedSceneDown() -> String? {
        workspace.moveSelectedSceneDown()
    }

    func showCorkboardMode() {
        workspace.setModularPresentationMode(.corkboard)
    }

    func showOutlinerMode() {
        workspace.setModularPresentationMode(.outliner)
    }

    func groupModularByChapter() {
        workspace.setModularGrouping(.byChapter)
    }

    func groupModularFlat() {
        workspace.setModularGrouping(.flat)
    }

    func groupModularByStatus() {
        workspace.setModularGrouping(.byStatus)
    }

    func setCorkboardDensityComfortable() {
        workspace.setCorkboardDensity(.comfortable)
    }

    func setCorkboardDensityCompact() {
        workspace.setCorkboardDensity(.compact)
    }

    func collapseAllModularGroups() {
        workspace.collapseAllModularGroups()
    }

    func expandAllModularGroups() {
        workspace.expandAllModularGroups()
    }

    @discardableResult
    func revealSelectionInSidebar() -> String? {
        workspace.revealSelectionInSidebar()
    }

    @discardableResult
    func sendSelectedSceneToStaging() -> String? {
        workspace.sendSelectedSceneToStaging()
    }

    @discardableResult
    func moveSelectedScene(toChapter chapterID: UUID) -> String? {
        workspace.moveSelectedScene(toChapter: chapterID)
    }

    @discardableResult
    func createBackup() -> String? {
        workspace.createBackupNow()
    }

    @discardableResult
    func saveAndBackup() -> String? {
        workspace.saveAndBackupNow()
    }

    func setModeLinear() {
        workspace.setMode(.linear)
    }

    func setModeModular() {
        workspace.setMode(.modular)
    }

    @discardableResult
    func toggleSplit(defaultWindowWidth: CGFloat = 1200) -> String? {
        workspace.toggleSplitForCommand(defaultWindowWidth: defaultWindowWidth)
    }

    @discardableResult
    func openSelectionInSplit(defaultWindowWidth: CGFloat = 1200) -> String? {
        workspace.openSelectionInSplit(windowWidth: defaultWindowWidth)
    }

    func toggleInspector() {
        workspace.toggleInspector()
    }

    @discardableResult
    func navigateToPreviousScene() -> Bool {
        workspace.navigateToPreviousScene()
    }

    @discardableResult
    func navigateToNextScene() -> Bool {
        workspace.navigateToNextScene()
    }

    func showInlineSearch() {
        workspace.showInlineSearchPanel()
    }

    func showProjectSearch() {
        workspace.showProjectSearchPanel()
    }

    func hideSearch() {
        workspace.hideSearchPanel()
    }

    func runSearch() {
        workspace.runSearch()
    }

    @discardableResult
    func replaceAllSearchResults() -> String? {
        workspace.replaceAllSearchResults()
    }

    @discardableResult
    func replaceNextSearchResult() -> String? {
        workspace.replaceNextSearchResult()
    }

    func selectSearchResult(at index: Int) {
        workspace.selectSearchResult(at: index)
    }

    func selectReplacePreviewMatch(sceneID: UUID, resultIndex: Int) {
        workspace.selectReplacePreviewMatch(sceneID: sceneID, resultIndex: resultIndex)
    }

    func navigateToNextSearchResult() {
        workspace.navigateToNextSearchResult()
    }

    func navigateToPreviousSearchResult() {
        workspace.navigateToPreviousSearchResult()
    }

    func toggleSearchHighlightDisplayMode() {
        workspace.toggleShowAllSearchHighlights()
    }

    func resetSearchHighlightSettings() {
        workspace.resetSearchHighlightPreferencesToDefaults()
    }

    func includeAllReplaceScenes() {
        workspace.includeAllReplaceScenes()
    }

    func excludeAllReplaceScenes() {
        workspace.excludeAllReplaceScenes()
    }

    @discardableResult
    func saveSelectedSearchChapterPreset() -> String? {
        workspace.saveSelectedSearchChapterPreset()
    }

    func applySearchChapterPreset(_ presetID: UUID) {
        workspace.applySearchChapterPreset(presetID)
    }

    func deleteSearchChapterPreset(_ presetID: UUID) {
        workspace.deleteSearchChapterPreset(presetID)
    }

    @discardableResult
    func undoLastReplaceBatch() -> String? {
        workspace.undoLastReplaceBatch()
    }

    @discardableResult
    func redoLastReplaceBatch() -> String? {
        workspace.redoLastReplaceBatch()
    }
}
