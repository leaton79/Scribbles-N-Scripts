import Foundation
import SwiftUI

@MainActor
struct WorkspaceCommandBindings {
    let workspace: WorkspaceCoordinator

    var canSaveProject: Bool {
        workspace.hasOpenProject && workspace.canSaveProject
    }

    var canCreateProjectContent: Bool {
        workspace.hasOpenProject
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
        workspace.hasOpenProject
    }

    var canSaveAndBackup: Bool {
        workspace.hasOpenProject
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

    var canNavigateToPreviousScene: Bool {
        workspace.canNavigateToPreviousScene
    }

    var canNavigateToNextScene: Bool {
        workspace.canNavigateToNextScene
    }

    var canSearchProject: Bool {
        workspace.hasOpenProject
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

    var searchResultPositionText: String {
        workspace.searchResultPositionText
    }

    var currentSearchResultIndex: Int? {
        workspace.currentSearchResultIndex
    }

    var splitToggleTitle: String {
        workspace.splitEditorState.isSplit ? "Close Split" : "Toggle Split"
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
    func createChapter() -> String? {
        workspace.createChapter()
    }

    @discardableResult
    func createScene() -> String? {
        workspace.createScene()
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
}
