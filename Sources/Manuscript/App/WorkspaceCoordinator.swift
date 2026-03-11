import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct RecentProjectEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL
}

struct RecentProjectsSnapshot: Equatable {
    let paths: [String]
    let lastOpenedPath: String?
}

enum ReplaceSceneSelectionMode: String, CaseIterable, Identifiable {
    case resetOnSearch
    case keepManualSelection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resetOnSearch:
            return "Reset on Search"
        case .keepManualSelection:
            return "Keep Manual Selection"
        }
    }
}

@MainActor
final class WorkspaceCoordinator: ObservableObject {
    private static let lastOpenedProjectPathKey = "workspace.lastOpenedProjectPath"
    private static let recentProjectsKey = "workspace.recentProjects"
    private static let searchHighlightCapKey = "workspace.searchHighlightCap"
    private static let searchHighlightSafetyThresholdKey = "workspace.searchHighlightSafetyThreshold"
    private static let replaceSceneSelectionModeKey = "workspace.replaceSceneSelectionMode"
    private static let sidebarTextSizeKey = "workspace.sidebarTextSize"
    private static let inspectorTextSizeKey = "workspace.inspectorTextSize"
    private static let searchChapterPresetKeyPrefix = "workspace.searchChapterPresets"
    private static let maxRecentProjects = 10
    private static let maxSearchChapterPresets = 5
    private static let defaultSearchHighlightCap = 100
    private static let defaultSearchHighlightSafetyThreshold = 2_000
    private static let minSearchHighlightCap = 10
    private static let maxSearchHighlightCap = 1_000
    private static let minSearchHighlightSafetyThreshold = 100
    private static let maxSearchHighlightSafetyThreshold = 20_000
    private static let defaultSidebarTextSize = 15.0
    private static let defaultInspectorTextSize = 14.0
    private static let minPeripheralTextSize = 11.0
    private static let maxPeripheralTextSize = 24.0
    private static let exportTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    let projectManager: FileSystemProjectManager
    let navigationState: NavigationState
    let editorState: EditorState
    let linearState: LinearModeState
    let modularState: ModularModeState
    let modeController: ModeController
    let splitEditorState: SplitEditorState
    let goalsManager: GoalsManager
    let tagManager: TagManager
    let metadataManager: MetadataManager
    private let recentProjectStore: UserDefaults
    private let searchPreferenceStore: UserDefaults
    private lazy var searchEngine = makeSearchEngine()
    private var editorObservationCancellables: Set<AnyCancellable> = []

    @Published var loadError: String?
    @Published var isInspectorVisible = true
    @Published var isSearchPanelVisible = false
    @Published var searchQueryText = ""
    @Published var searchReplacementText = ""
    @Published var searchScope: WorkspaceSearchScope = .currentScene
    @Published var selectedSearchChapterIDs: Set<UUID> = []
    @Published private(set) var searchChapterPresets: [SearchChapterScopePreset] = []
    @Published var searchIsRegex = false
    @Published var searchIsCaseSensitive = false
    @Published var searchIsWholeWord = false
    @Published var searchShowAllHighlights = false
    @Published var isSearchHighlightHelpVisible = false
    @Published private(set) var isReplacingAll = false
    @Published private(set) var replaceProgressStatus = ReplaceProgressStatus(
        completedScenes: 0,
        totalScenes: 0,
        replacementsCompleted: 0,
        currentSceneTitle: nil
    )
    @Published private(set) var isSearchIndexing = false
    @Published private(set) var searchIndexStatus = SearchIndexStatus(completed: 0, total: 0)
    @Published private(set) var searchHighlightCap: Int
    @Published private(set) var searchHighlightSafetyThreshold: Int
    @Published private(set) var searchResults: [SearchResult] = []
    @Published private(set) var searchErrorMessage: String?
    @Published private(set) var currentSearchResultIndex: Int?
    @Published private(set) var includedReplaceSceneIDs: Set<UUID> = []
    @Published private(set) var sidebarTextSize: CGFloat
    @Published private(set) var inspectorTextSize: CGFloat
    @Published private(set) var recoveryCandidateURL: URL?
    @Published private(set) var recoveryCandidateDetails: String?
    @Published var notesFocusSceneID: UUID?
    @Published var notesFocusEntityID: UUID?
    @Published var replaceSceneSelectionMode: ReplaceSceneSelectionMode = .resetOnSearch {
        didSet {
            persistReplaceSceneSelectionModePreference()
        }
    }
    private var replaceSceneUniverse: Set<UUID> = []

    var hasOpenProject: Bool {
        projectManager.currentProject != nil
    }

    var isRecoveryMode: Bool {
        projectManager.isReadOnlyRecoveryMode
    }

    var recoveryModeDetails: String? {
        projectManager.recoveryModeDetails
    }

    var canReopenLastProject: Bool {
        lastOpenedProjectURL() != nil
    }

    var recentProjects: [RecentProjectEntry] {
        recentProjectURLs().map { url in
            RecentProjectEntry(id: url.path, name: url.lastPathComponent, url: url)
        }
    }

    var switchableProjects: [RecentProjectEntry] {
        var entries: [RecentProjectEntry] = []
        var seen = Set<String>()

        if let current = currentProjectEntry {
            entries.append(current)
            seen.insert(current.id)
        }
        for recent in recentProjects where !seen.contains(recent.id) {
            entries.append(recent)
            seen.insert(recent.id)
        }
        return entries
    }

    var hasStaleRecentProjects: Bool {
        let stored = recentProjectPaths()
        let valid = Set(recentProjectURLs().map(\.path))
        return stored.contains { !valid.contains($0) }
    }

    var canClearRecentProjects: Bool {
        !recentProjects.isEmpty
    }

    var canSaveProjectAs: Bool {
        hasOpenProject && !isRecoveryMode
    }

    var canRenameProject: Bool {
        hasOpenProject && !isRecoveryMode
    }

    var projectDisplayName: String {
        projectManager.currentProject?.name ?? "Scribbles-N-Scripts"
    }

    var recoveryDiagnostics: [RecoveryDiagnostic] {
        projectManager.recoveryDiagnostics
    }

    var recoverySummary: String? {
        guard isRecoveryMode else { return nil }
        let sceneCount = projectManager.currentProject?.manuscript.chapters.reduce(0) { $0 + $1.scenes.count } ?? 0
        let stagingCount = projectManager.currentProject?.manuscript.stagingArea.count ?? 0
        return "Recovered \(sceneCount) scene(s), found \(stagingCount) staging scene(s), and logged \(recoveryDiagnostics.count) recovery note(s)."
    }

    var canShowImportExport: Bool {
        hasOpenProject
    }

    var hasUnsavedChanges: Bool {
        guard projectManager.currentProject != nil else {
            return false
        }
        if projectManager.isDirty || editorState.isModified {
            return true
        }
        if splitEditorState.isSplit && (splitEditorState.primaryEditor.isModified || splitEditorState.secondaryEditor.isModified) {
            return true
        }
        return false
    }

    var canSaveProject: Bool {
        hasUnsavedChanges && !isRecoveryMode
    }

    var canNavigateToNextScene: Bool {
        guard projectManager.currentProject != nil,
              modeController.activeMode == .linear,
              let current = editorState.currentSceneId,
              let index = linearState.orderedSceneIds.firstIndex(of: current) else {
            return false
        }
        return index + 1 < linearState.orderedSceneIds.count
    }

    var canNavigateToPreviousScene: Bool {
        guard projectManager.currentProject != nil,
              modeController.activeMode == .linear,
              let current = editorState.currentSceneId,
              let index = linearState.orderedSceneIds.firstIndex(of: current) else {
            return false
        }
        return index > 0
    }

    var canToggleSplitEditor: Bool {
        guard projectManager.currentProject != nil else {
            return false
        }
        if splitEditorState.isSplit {
            return true
        }
        guard modeController.activeMode == .linear else {
            return false
        }
        return resolveSceneForSplitOpen() != nil
    }

    var canUseModularPresentationControls: Bool {
        hasOpenProject && modeController.activeMode == .modular
    }

    var canCreateSceneBelow: Bool {
        projectManager.currentProject != nil && !isRecoveryMode && modeController.activeMode == .linear && editorState.currentSceneId != nil
    }

    var canDuplicateSelectedScene: Bool {
        guard projectManager.currentProject != nil, !isRecoveryMode, modeController.activeMode == .linear else {
            return false
        }
        guard let sceneID = selectedSceneForContextualActions() else {
            return false
        }
        return sceneExists(sceneID)
    }

    var canMoveSelectedSceneUp: Bool {
        guard !isRecoveryMode, let context = selectedSceneContext() else {
            return false
        }
        guard context.chapter != nil else {
            return false
        }
        return context.sceneIndex > 0
    }

    var canMoveSelectedSceneDown: Bool {
        guard !isRecoveryMode, let context = selectedSceneContext() else {
            return false
        }
        guard let chapter = context.chapter else {
            return false
        }
        return context.sceneIndex + 1 < chapter.scenes.count
    }

    var canRevealSelectionInSidebar: Bool {
        guard let sceneID = selectedSceneForContextualActions() else {
            return false
        }
        return sceneExists(sceneID)
    }

    var canSendSelectedSceneToStaging: Bool {
        guard !isRecoveryMode, let context = selectedSceneContext() else {
            return false
        }
        return context.scene.parentChapterId != nil
    }

    var selectedModularSceneCount: Int {
        modularState.selectedSceneIds.count
    }

    var canBatchStageSelectedScenes: Bool {
        !isRecoveryMode && modeController.activeMode == .modular && modularState.selectedSceneIds.contains { sceneID in
            projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })?.parentChapterId != nil
        }
    }

    var canBatchMoveSelectedScenesToChapter: Bool {
        !isRecoveryMode && modeController.activeMode == .modular && !modularState.selectedSceneIds.isEmpty && !stagingRecoveryTargetChapters.isEmpty
    }

    var canMoveSelectedSceneToAnotherChapter: Bool {
        guard let context = selectedSceneContext() else {
            return false
        }
        let chapters = projectManager.getManifest().hierarchy.chapters
        if context.scene.parentChapterId == nil {
            return !chapters.isEmpty
        }
        return chapters.contains(where: { $0.id != context.chapter?.id })
    }

    var canOpenSelectionInSplit: Bool {
        guard projectManager.currentProject != nil,
              modeController.activeMode == .linear,
              let targetSceneID = navigationState.selectedSceneId ?? editorState.currentSceneId else {
            return false
        }
        if splitEditorState.isSplit {
            return true
        }
        return sceneExists(targetSceneID)
    }

    var canSwitchToLinearMode: Bool {
        hasOpenProject && modeController.activeMode != .linear
    }

    var canSwitchToModularMode: Bool {
        hasOpenProject && modeController.activeMode != .modular
    }

    var canToggleInspector: Bool {
        hasOpenProject
    }

    var inspectorToggleTitle: String {
        isInspectorVisible ? "Hide Inspector" : "Show Inspector"
    }

    init(
        projectManager manager: FileSystemProjectManager = FileSystemProjectManager(),
        bootstrapRootURL: URL? = nil,
        bootstrapProjectName: String = "Sandbox",
        splitSettingsStore: UserDefaults = .standard,
        recentProjectStore: UserDefaults = .standard,
        searchPreferenceStore: UserDefaults = .standard
    ) {
        self.projectManager = manager
        self.tagManager = TagManager(projectManager: manager)
        self.metadataManager = MetadataManager(projectManager: manager)
        self.recentProjectStore = recentProjectStore
        self.searchPreferenceStore = searchPreferenceStore
        let storedCap = searchPreferenceStore.object(forKey: Self.searchHighlightCapKey) != nil
            ? searchPreferenceStore.integer(forKey: Self.searchHighlightCapKey)
            : Self.defaultSearchHighlightCap
        let storedThreshold = searchPreferenceStore.object(forKey: Self.searchHighlightSafetyThresholdKey) != nil
            ? searchPreferenceStore.integer(forKey: Self.searchHighlightSafetyThresholdKey)
            : Self.defaultSearchHighlightSafetyThreshold
        let normalized = Self.normalizeSearchHighlightPreferences(cap: storedCap, threshold: storedThreshold)
        self.searchHighlightCap = normalized.cap
        self.searchHighlightSafetyThreshold = normalized.threshold
        let storedSidebarTextSize = searchPreferenceStore.object(forKey: Self.sidebarTextSizeKey) != nil
            ? searchPreferenceStore.double(forKey: Self.sidebarTextSizeKey)
            : Self.defaultSidebarTextSize
        let storedInspectorTextSize = searchPreferenceStore.object(forKey: Self.inspectorTextSizeKey) != nil
            ? searchPreferenceStore.double(forKey: Self.inspectorTextSizeKey)
            : Self.defaultInspectorTextSize
        self.sidebarTextSize = Self.normalizePeripheralTextSize(storedSidebarTextSize)
        self.inspectorTextSize = Self.normalizePeripheralTextSize(storedInspectorTextSize)
        if let storedModeRawValue = searchPreferenceStore.string(forKey: Self.replaceSceneSelectionModeKey),
           let storedMode = ReplaceSceneSelectionMode(rawValue: storedModeRawValue) {
            self.replaceSceneSelectionMode = storedMode
        }

        do {
            try Self.bootstrapProject(
                using: manager,
                rootURL: bootstrapRootURL,
                projectName: bootstrapProjectName,
                recentProjectStore: recentProjectStore
            )
            let dependencies = Self.makeDependencies(
                manager: manager,
                splitSettingsStore: splitSettingsStore,
                splitSettingsNamespace: Self.splitSettingsNamespace(for: manager)
            )
            self.navigationState = dependencies.navigationState
            self.editorState = dependencies.editorState
            self.linearState = dependencies.linearState
            self.modularState = dependencies.modularState
            self.modeController = dependencies.modeController
            self.splitEditorState = dependencies.splitEditorState
            self.goalsManager = dependencies.goalsManager
            self.goalsManager.bind(to: self.editorState)
            self.tagManager.reloadFromProject()
            self.metadataManager.reloadFromProject()
            configureEditorEntityHighlighting()
            persistLastOpenedProject()
            loadSearchChapterPresets()

            if dependencies.editorState.currentSceneId == nil, let first = dependencies.linearState.orderedSceneIds.first {
                dependencies.linearState.goToScene(id: first)
                dependencies.splitEditorState.primarySceneId = first
            }
            startSearchIndexing()
        } catch {
            self.loadError = error.localizedDescription
            if case let ProjectIOError.corruptManifest(details) = error,
               let bootstrapRootURL {
                self.recoveryCandidateURL = bootstrapRootURL.appendingPathComponent(bootstrapProjectName, isDirectory: true)
                self.recoveryCandidateDetails = details
            }
            let dependencies = Self.makeDependencies(
                manager: manager,
                splitSettingsStore: splitSettingsStore,
                splitSettingsNamespace: Self.splitSettingsNamespace(for: manager)
            )
            self.navigationState = dependencies.navigationState
            self.editorState = dependencies.editorState
            self.linearState = dependencies.linearState
            self.modularState = dependencies.modularState
            self.modeController = dependencies.modeController
            self.splitEditorState = dependencies.splitEditorState
            self.goalsManager = dependencies.goalsManager
            self.goalsManager.bind(to: self.editorState)
            self.tagManager.reloadFromProject()
            self.metadataManager.reloadFromProject()
            configureEditorEntityHighlighting()
            persistSearchHighlightPreferences()
        }
    }

    func select(node: SidebarNode) {
        guard hasOpenProject else { return }
        switch node.level {
        case .scene:
            guard sceneExists(node.id) else { return }
            navigateToSceneInActivePane(node.id)
        case .chapter:
            guard chapterExists(node.id) else { return }
            navigationState.navigateTo(chapterId: node.id)
        case .part, .manuscript:
            break
        }
    }

    func select(breadcrumb: BreadcrumbItem) {
        guard hasOpenProject else { return }
        switch breadcrumb.type {
        case .scene:
            guard sceneExists(breadcrumb.id) else { return }
            navigateToSceneInActivePane(breadcrumb.id)
        case .chapter:
            guard chapterExists(breadcrumb.id) else { return }
            navigationState.navigateTo(chapterId: breadcrumb.id)
        case .part, .manuscript:
            break
        }
    }

    func navigateToScene(_ sceneID: UUID) {
        guard hasOpenProject, sceneExists(sceneID) else { return }
        navigateToSceneInActivePane(sceneID)
    }

    func navigateToChapter(_ chapterID: UUID) {
        guard hasOpenProject, chapterExists(chapterID) else { return }
        navigationState.navigateTo(chapterId: chapterID)
    }

    func toggleInspector() {
        guard hasOpenProject else { return }
        isInspectorVisible.toggle()
    }

    @discardableResult
    func createSceneBelowCurrent(title: String? = nil) -> String? {
        guard hasOpenProject else {
            return "Could not create scene: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard modeController.activeMode == .linear else {
            return "New Scene Below is only available in linear mode."
        }
        let resolvedTitle: String
        if let title {
            let normalized = normalizeTitle(title, fallback: "")
            resolvedTitle = normalized.isEmpty ? nextGeneratedSceneTitle() : normalized
        } else {
            resolvedTitle = nextGeneratedSceneTitle()
        }
        do {
            try linearState.createNewSceneBelowCurrent(title: resolvedTitle)
            refreshDerivedStates()
            if let current = editorState.currentSceneId {
                if splitEditorState.activePaneIndex == 1, splitEditorState.isSplit {
                    splitEditorState.secondarySceneId = current
                } else {
                    splitEditorState.primarySceneId = current
                }
            }
            return nil
        } catch {
            return "Could not create scene below: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func duplicateSelectedScene() -> String? {
        guard hasOpenProject else {
            return "Could not duplicate scene: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard let context = selectedSceneContext() else {
            return "Could not duplicate scene: No scene selected."
        }

        do {
            autosaveOpenEditors()
            let sourceContent = try projectManager.loadSceneContent(sceneId: context.scene.id)
            guard let chapter = context.chapter else {
                return "Could not duplicate scene: Staging scenes must be moved into a chapter before duplication."
            }
            let duplicated = try projectManager.addScene(
                to: chapter.id,
                at: context.sceneIndex + 1,
                title: nextDuplicateSceneTitle(for: context.scene.title)
            )
            try projectManager.saveSceneContent(sceneId: duplicated.id, content: sourceContent)
            try projectManager.updateSceneMetadata(
                sceneId: duplicated.id,
                updates: SceneMetadataUpdate(
                    title: duplicated.title,
                    synopsis: context.scene.synopsis,
                    status: context.scene.status,
                    tags: context.scene.tags,
                    colorLabel: context.scene.colorLabel,
                    clearColorLabel: context.scene.colorLabel == nil,
                    metadata: context.scene.metadata
                )
            )
            refreshDerivedStates()
            navigateToSceneInActivePane(duplicated.id)
            return nil
        } catch {
            return "Could not duplicate scene: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func moveSelectedSceneUp() -> String? {
        moveSelectedScene(offset: -1)
    }

    @discardableResult
    func moveSelectedSceneDown() -> String? {
        moveSelectedScene(offset: 1)
    }

    func setModularPresentationMode(_ mode: ModularPresentationMode) {
        guard canUseModularPresentationControls else { return }
        modularState.presentationMode = mode
    }

    func setModularGrouping(_ grouping: CardGrouping) {
        guard canUseModularPresentationControls else { return }
        modularState.grouping = grouping
    }

    func setCorkboardDensity(_ density: CorkboardDensity) {
        guard canUseModularPresentationControls else { return }
        modularState.corkboardDensity = density
    }

    func collapseAllModularGroups() {
        guard canUseModularPresentationControls else { return }
        modularState.collapseAllGroups()
    }

    func expandAllModularGroups() {
        guard canUseModularPresentationControls else { return }
        modularState.expandAllGroups()
    }

    @discardableResult
    func revealSelectionInSidebar() -> String? {
        guard hasOpenProject else {
            return ProjectIOError.noOpenProject.localizedDescription
        }
        guard let context = selectedSceneContext() else {
            return "No scene selected to reveal."
        }
        if let chapter = context.chapter {
            navigationState.expandedNodes.insert(chapter.id)
            if let partID = chapter.parentPartId {
                navigationState.expandedNodes.insert(partID)
            }
        }
        navigationState.navigateTo(sceneId: context.scene.id)
        return nil
    }

    var moveSceneTargetChapters: [ManifestChapter] {
        let manifest = projectManager.getManifest()
        let currentChapterID = selectedSceneContext()?.chapter?.id
        return manifest.hierarchy.chapters
            .filter { chapter in
                guard let currentChapterID else { return true }
                return chapter.id != currentChapterID || selectedSceneContext()?.scene.parentChapterId == nil
            }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
    }

    @discardableResult
    func moveSelectedScene(toChapter chapterID: UUID) -> String? {
        guard hasOpenProject else {
            return "Could not move scene: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard let context = selectedSceneContext() else {
            return "Could not move scene: No scene selected."
        }
        guard chapterExists(chapterID) else {
            return "Could not move scene: Target chapter not found."
        }
        do {
            let destinationCount = projectManager.getManifest().hierarchy.chapters.first(where: { $0.id == chapterID })?.scenes.count ?? 0
            try projectManager.moveScene(sceneId: context.scene.id, toChapterId: chapterID, atIndex: destinationCount)
            refreshDerivedStates()
            navigateToSceneInActivePane(context.scene.id)
            return nil
        } catch {
            return "Could not move scene: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func sendSelectedSceneToStaging() -> String? {
        guard hasOpenProject else {
            return "Could not send scene to staging: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard let sceneID = selectedSceneForContextualActions(), sceneExists(sceneID) else {
            return "Could not send scene to staging: No scene selected."
        }
        do {
            try projectManager.moveToStaging(sceneId: sceneID)
            refreshDerivedStates()
            navigateToSceneInActivePane(sceneID)
            return nil
        } catch {
            return "Could not send scene to staging: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func moveSelectedSceneOutOfStaging(toChapter chapterID: UUID? = nil) -> String? {
        guard let context = selectedSceneContext() else {
            return "Could not move scene out of staging: No scene selected."
        }
        guard context.chapter == nil else {
            return "Selected scene is not in staging."
        }
        let targetChapterID = chapterID ?? stagingRecoveryTargetChapters.first?.id
        guard let targetChapterID else {
            return "Could not move scene out of staging: No chapters available."
        }
        return moveSelectedScene(toChapter: targetChapterID)
    }

    @discardableResult
    func moveAllStagingScenes(toChapter chapterID: UUID) -> String? {
        guard hasOpenProject else {
            return "Could not move scenes out of staging: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard chapterExists(chapterID) else {
            return "Could not move scenes out of staging: Target chapter not found."
        }
        let stagedSceneIDs = projectManager.getManifest().hierarchy.stagingScenes
        guard !stagedSceneIDs.isEmpty else {
            return "No staging scenes to move."
        }
        do {
            for sceneID in stagedSceneIDs {
                let destinationCount = projectManager.getManifest().hierarchy.chapters.first(where: { $0.id == chapterID })?.scenes.count ?? 0
                try projectManager.moveScene(sceneId: sceneID, toChapterId: chapterID, atIndex: destinationCount)
            }
            refreshDerivedStates()
            if let firstMovedID = stagedSceneIDs.first {
                navigateToSceneInActivePane(firstMovedID)
            }
            return nil
        } catch {
            return "Could not move scenes out of staging: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func openSelectionInSplit(windowWidth: CGFloat = 1200) -> String? {
        guard hasOpenProject else {
            return ProjectIOError.noOpenProject.localizedDescription
        }
        guard modeController.activeMode == .linear else {
            return "Open in Split is only available in linear mode."
        }
        guard let targetSceneID = navigationState.selectedSceneId ?? editorState.currentSceneId,
              sceneExists(targetSceneID) else {
            return "No scene selected for split."
        }
        if splitEditorState.isSplit {
            splitEditorState.secondarySceneId = targetSceneID
            splitEditorState.secondaryEditor.navigateToScene(id: targetSceneID)
            splitEditorState.setActivePane(1)
            navigationState.navigateTo(sceneId: targetSceneID)
            return nil
        }
        let primarySceneCandidates: [UUID?] = [
            editorState.currentSceneId,
            splitEditorState.primarySceneId,
            linearState.orderedSceneIds.first
        ]
        guard let primarySceneID = primarySceneCandidates.first(where: { candidate in
            guard let candidate else {
                return false
            }
            return sceneExists(candidate)
        }) ?? nil else {
            return nil
        }
        let applied = splitEditorState.openSplit(
            sceneId: targetSceneID,
            preferredOrientation: .vertical,
            windowWidth: windowWidth
        )
        splitEditorState.primarySceneId = primarySceneID
        splitEditorState.primaryEditor.navigateToScene(id: primarySceneID)
        splitEditorState.secondarySceneId = targetSceneID
        splitEditorState.secondaryEditor.navigateToScene(id: targetSceneID)
        splitEditorState.setActivePane(1)
        navigationState.navigateTo(sceneId: targetSceneID)
        if applied == .horizontal {
            return "Window too narrow for side-by-side split. Using stacked layout."
        }
        return nil
    }

    func openSplitFromCurrentContext(windowWidth: CGFloat, preferredOrientation: SplitOrientation = .vertical) -> String? {
        guard projectManager.currentProject != nil else {
            return nil
        }
        guard modeController.activeMode == .linear else { return nil }
        guard let targetSceneId = resolveSceneForSplitOpen() else {
            return nil
        }

        let applied = splitEditorState.openSplit(
            sceneId: targetSceneId,
            preferredOrientation: preferredOrientation,
            windowWidth: windowWidth
        )
        splitEditorState.setActivePane(1)

        if preferredOrientation == .vertical, applied == .horizontal {
            return "Window too narrow for side-by-side split. Using stacked layout."
        }
        return nil
    }

    func toggleSplit(windowWidth: CGFloat, preferredOrientation: SplitOrientation = .vertical) -> String? {
        guard projectManager.currentProject != nil else {
            return ProjectIOError.noOpenProject.localizedDescription
        }
        if splitEditorState.isSplit {
            splitEditorState.closeSplit()
            return nil
        }
        return openSplitFromCurrentContext(windowWidth: windowWidth, preferredOrientation: preferredOrientation)
    }

    func handleModeChange(_ mode: ViewMode) {
        if mode == .modular, splitEditorState.isSplit {
            splitEditorState.closeSplit()
        }
    }

    func setMode(_ mode: ViewMode) {
        guard hasOpenProject else {
            return
        }
        modeController.switchTo(mode)
        handleModeChange(mode)
    }

    @discardableResult
    func createAndOpenProject(named rawName: String) -> String? {
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else {
            return "Could not create project: Project name cannot be empty."
        }

        do {
            if hasOpenProject {
                autosaveOpenEditors()
                try projectManager.saveManifest()
            }
            let rootURL = try projectRootForNewProjects()
            _ = try projectManager.createProject(name: name, at: rootURL)
            didOpenProject()
            return "Created project \"\(projectDisplayName)\"."
        } catch {
            return "Could not create project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func openProject(at projectURL: URL) -> String? {
        do {
            if hasOpenProject {
                autosaveOpenEditors()
                try projectManager.saveManifest()
            }
            _ = try projectManager.openProject(at: projectURL)
            recoveryCandidateURL = nil
            recoveryCandidateDetails = nil
            didOpenProject()
            return "Opened project \"\(projectDisplayName)\"."
        } catch {
            if case let ProjectIOError.corruptManifest(details) = error {
                recoveryCandidateURL = projectURL
                recoveryCandidateDetails = details
            } else {
                recoveryCandidateURL = nil
                recoveryCandidateDetails = nil
            }
            return projectOpenFailureMessage(for: error)
        }
    }

    @discardableResult
    func openRecoveryModeForFailedProject() -> String? {
        guard let recoveryCandidateURL, let recoveryCandidateDetails else {
            return "No recoverable project is pending."
        }
        do {
            _ = try projectManager.openProjectInRecoveryMode(at: recoveryCandidateURL, details: recoveryCandidateDetails)
            didOpenProject()
            return "Opened \(projectManager.currentProject?.name ?? recoveryCandidateURL.lastPathComponent) as a read-only recovery copy."
        } catch {
            return "Could not open recovery mode: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func reopenLastProject() -> String? {
        guard let projectURL = lastOpenedProjectURL() else {
            return "Could not reopen project: No recent project found."
        }
        let result = openProject(at: projectURL)
        if result?.hasPrefix("Opened project ") == true {
            return "Reopened project \"\(projectDisplayName)\"."
        }
        return result
    }

    func clearRecentProjects() {
        recentProjectStore.removeObject(forKey: Self.recentProjectsKey)
        recentProjectStore.removeObject(forKey: Self.lastOpenedProjectPathKey)
    }

    func snapshotRecentProjects() -> RecentProjectsSnapshot {
        RecentProjectsSnapshot(
            paths: recentProjectPaths(),
            lastOpenedPath: recentProjectStore.string(forKey: Self.lastOpenedProjectPathKey)
        )
    }

    func restoreRecentProjects(from snapshot: RecentProjectsSnapshot) {
        recentProjectStore.set(snapshot.paths, forKey: Self.recentProjectsKey)
        if let lastOpenedPath = snapshot.lastOpenedPath {
            recentProjectStore.set(lastOpenedPath, forKey: Self.lastOpenedProjectPathKey)
        } else {
            recentProjectStore.removeObject(forKey: Self.lastOpenedProjectPathKey)
        }
    }

    func cleanupMissingRecentProjects() {
        let cleaned = recentProjectPaths().filter { path in
            let url = URL(fileURLWithPath: path, isDirectory: true)
            return FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path)
        }
        recentProjectStore.set(cleaned, forKey: Self.recentProjectsKey)

        if let last = recentProjectStore.string(forKey: Self.lastOpenedProjectPathKey), !cleaned.contains(last) {
            recentProjectStore.removeObject(forKey: Self.lastOpenedProjectPathKey)
        }
    }

    func showInlineSearchPanel() {
        guard hasOpenProject else { return }
        isSearchPanelVisible = true
        searchScope = .currentScene
        runSearch()
    }

    func showProjectSearchPanel() {
        guard hasOpenProject else { return }
        isSearchPanelVisible = true
        searchScope = .entireProject
        runSearch()
    }

    func hideSearchPanel() {
        isSearchPanelVisible = false
        searchShowAllHighlights = false
        isSearchHighlightHelpVisible = false
        includedReplaceSceneIDs = []
        replaceSceneUniverse = []
        clearEditorSearchHighlights()
    }

    func runSearch() {
        guard hasOpenProject else {
            searchResults = []
            searchErrorMessage = nil
            currentSearchResultIndex = nil
            return
        }
        let query = makeSearchQuery()
        searchResults = searchEngine.search(query: query)
        searchErrorMessage = searchEngine.lastErrorMessage
        if searchShowAllHighlights && !canUseShowAllHighlightsForCurrentContext() {
            searchShowAllHighlights = false
        }
        if searchResults.isEmpty {
            currentSearchResultIndex = nil
        } else if let currentSearchResultIndex, currentSearchResultIndex < searchResults.count {
            self.currentSearchResultIndex = currentSearchResultIndex
        } else {
            currentSearchResultIndex = 0
        }
        synchronizeReplaceSceneSelection()
        updateEditorSearchHighlights()
    }

    @discardableResult
    func replaceAllSearchResults() -> String? {
        guard hasOpenProject else {
            return "Could not replace: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard !searchQueryText.isEmpty else {
            return "Could not replace: Search text cannot be empty."
        }
        let selectedSceneIDs = Array(includedReplaceSceneIDs)
        guard !selectedSceneIDs.isEmpty else {
            return "No scenes selected for replace."
        }
        do {
            isReplacingAll = true
            replaceProgressStatus = ReplaceProgressStatus(
                completedScenes: 0,
                totalScenes: selectedSceneIDs.count,
                replacementsCompleted: 0,
                currentSceneTitle: nil
            )
            let report = try searchEngine.replaceAll(
                query: makeSearchQuery(),
                replacement: searchReplacementText,
                inSceneIDs: selectedSceneIDs,
                progress: { [weak self] progress in
                    self?.replaceProgressStatus = ReplaceProgressStatus(
                        completedScenes: progress.completedScenes,
                        totalScenes: progress.totalScenes,
                        replacementsCompleted: progress.replacementsCompleted,
                        currentSceneTitle: progress.currentSceneTitle
                    )
                }
            )
            refreshDerivedStates()
            reloadOpenEditorScenes()
            runSearch()
            isReplacingAll = false
            replaceProgressStatus = ReplaceProgressStatus(
                completedScenes: 0,
                totalScenes: 0,
                replacementsCompleted: 0,
                currentSceneTitle: nil
            )
            return "Replaced \(report.replacementCount) matches across \(report.scenesAffected) scenes."
        } catch {
            isReplacingAll = false
            replaceProgressStatus = ReplaceProgressStatus(
                completedScenes: 0,
                totalScenes: 0,
                replacementsCompleted: 0,
                currentSceneTitle: nil
            )
            return "Could not replace: \(error.localizedDescription)"
        }
    }

    var selectedReplaceSceneCount: Int {
        includedReplaceSceneIDs.count
    }

    func isSceneIncludedForReplace(_ sceneID: UUID) -> Bool {
        includedReplaceSceneIDs.contains(sceneID)
    }

    func setSceneIncludedForReplace(_ sceneID: UUID, included: Bool) {
        guard replaceSceneUniverse.contains(sceneID) else { return }
        if included {
            includedReplaceSceneIDs.insert(sceneID)
        } else {
            includedReplaceSceneIDs.remove(sceneID)
        }
    }

    func includeAllReplaceScenes() {
        includedReplaceSceneIDs = replaceSceneUniverse
    }

    func excludeAllReplaceScenes() {
        includedReplaceSceneIDs = []
    }

    var canBulkSelectReplaceScenes: Bool {
        !replaceSceneUniverse.isEmpty
    }

    var activeEditorChromeVisibility: EditorChromeVisibility {
        activeEditorState().chromeVisibility()
    }

    var inspectorScene: ManifestScene? {
        guard let sceneID = navigationState.selectedSceneId ?? editorState.currentSceneId else { return nil }
        return projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })
    }

    var inspectorChapter: ManifestChapter? {
        let manifest = projectManager.getManifest()
        if let chapterID = navigationState.selectedChapterId {
            return manifest.hierarchy.chapters.first(where: { $0.id == chapterID })
        }
        if let parentChapterID = inspectorScene?.parentChapterId {
            return manifest.hierarchy.chapters.first(where: { $0.id == parentChapterID })
        }
        return nil
    }

    var inspectorAvailableTags: [Tag] {
        tagManager.allTags
    }

    var projectSettings: ProjectSettings? {
        projectManager.currentProject?.settings
    }

    var editorPresentationSettings: EditorPresentationSettings {
        guard let settings = projectSettings else { return .default }
        return EditorPresentationSettings(
            fontName: settings.editorFont,
            fontSize: CGFloat(settings.editorFontSize),
            lineHeight: CGFloat(settings.editorLineHeight),
            contentWidth: CGFloat(settings.editorContentWidth),
            theme: settings.theme
        )
    }

    var preferredColorScheme: ColorScheme? {
        themePalette.colorScheme
    }

    var themePalette: AppThemePalette {
        AppThemePalette.forTheme(projectSettings?.theme ?? .system)
    }

    var appearancePresets: [AppearancePreset] {
        (projectSettings?.appearancePresets ?? []).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var inspectorCustomFields: [CustomMetadataField] {
        metadataManager.customFields.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var inspectorSelectedMetadataFieldOptions: [String] {
        inspectorCustomFields.first(where: { $0.fieldType == .singleSelect })?.options ?? []
    }

    var inspectorColorLabelNames: [ColorLabel: String] {
        projectManager.currentProject?.settings.defaultColorLabelNames ?? [:]
    }

    var stagingScenes: [ManifestScene] {
        let manifest = projectManager.getManifest()
        let scenesByID = Dictionary(uniqueKeysWithValues: manifest.hierarchy.scenes.map { ($0.id, $0) })
        return manifest.hierarchy.stagingScenes.compactMap { scenesByID[$0] }
    }

    var stagingSceneCount: Int {
        projectManager.getManifest().hierarchy.stagingScenes.count
    }

    var stagingRecoveryTargetChapters: [ManifestChapter] {
        searchableChapters
    }

    var compilePresets: [CompilePreset] {
        (projectManager.currentProject?.compilePresets ?? []).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var entities: [Entity] {
        (projectManager.currentProject?.entities ?? []).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var sources: [Source] {
        (projectManager.currentProject?.sources ?? []).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var timelineEvents: [TimelineEvent] {
        (projectManager.currentProject?.timelineEvents ?? []).sorted { lhs, rhs in
            if lhs.track.localizedCaseInsensitiveCompare(rhs.track) != .orderedSame {
                return lhs.track.localizedCaseInsensitiveCompare(rhs.track) == .orderedAscending
            }
            switch (lhs.position, rhs.position) {
            case let (.absolute(left), .absolute(right)):
                return left < right
            case let (.relative(order: left), .relative(order: right)):
                return left < right
            case (.absolute, .relative):
                return true
            case (.relative, .absolute):
                return false
            }
        }
    }

    var notes: [Note] {
        (projectManager.currentProject?.notes ?? []).sorted {
            if $0.modifiedAt == $1.modifiedAt {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.modifiedAt > $1.modifiedAt
        }
    }

    var scratchpadItems: [ScratchpadItem] {
        (projectManager.currentProject?.scratchpadItems ?? []).sorted { lhs, rhs in
            let leftDate = lhs.lastUsedAt ?? lhs.modifiedAt
            let rightDate = rhs.lastUsedAt ?? rhs.modifiedAt
            if leftDate == rightDate {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return leftDate > rightDate
        }
    }

    var searchableChapters: [ManifestChapter] {
        projectManager.getManifest().hierarchy.chapters.sorted { lhs, rhs in
            if lhs.sequenceIndex == rhs.sequenceIndex {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.sequenceIndex < rhs.sequenceIndex
        }
    }

    var hasSelectedSearchChapters: Bool {
        !selectedSearchChapterIDs.isEmpty
    }

    var canUndoLastReplaceBatch: Bool {
        searchEngine.canUndoLastReplaceAll
    }

    var canRedoLastReplaceBatch: Bool {
        searchEngine.canRedoLastReplaceAll
    }

    var regexReplacementHelpText: String? {
        guard searchIsRegex else { return nil }
        let captureCount = regexCaptureGroupCount()
        if captureCount > 0 {
            return "Regex replace supports capture groups like $1 through $\(captureCount)."
        }
        return "Regex replace is enabled. Use capture groups like (pattern) and reference them as $1, $2."
    }

    var regexReplacementWarning: String? {
        guard searchIsRegex else { return nil }
        let referencedGroups = referencedReplacementCaptureGroups()
        guard !referencedGroups.isEmpty else { return nil }
        let captureCount = regexCaptureGroupCount()
        if let highest = referencedGroups.max(), highest > captureCount {
            return "Replacement references $\(highest), but the current regex exposes only \(captureCount) capture group(s)."
        }
        return nil
    }

    var replaceUndoDepth: Int {
        searchEngine.replaceUndoDepth
    }

    var replaceRedoDepth: Int {
        searchEngine.replaceRedoDepth
    }

    var replaceUndoHistory: [ReplaceBatchHistoryItem] {
        searchEngine.replaceUndoHistory
    }

    var replaceRedoHistory: [ReplaceBatchHistoryItem] {
        searchEngine.replaceRedoHistory
    }

    var groupedSearchResults: [SearchResultSection] {
        let groupedByChapter = Dictionary(grouping: Array(searchResults.enumerated()), by: { $0.element.chapterTitle })
        let orderedChapters = groupedByChapter.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        return orderedChapters.map { chapterTitle in
            let chapterEntries = groupedByChapter[chapterTitle] ?? []
            let groupedByScene = Dictionary(grouping: chapterEntries, by: { $0.element.sceneId })
            let scenes = groupedByScene.values.compactMap { entries -> SearchResultSceneGroup? in
                guard let first = entries.first?.element else { return nil }
                let items = entries.map { entry in
                    SearchResultListItem(
                        id: "\(first.sceneId.uuidString)-\(entry.offset)",
                        resultIndex: entry.offset,
                        result: entry.element
                    )
                }
                return SearchResultSceneGroup(
                    id: first.sceneId,
                    sceneTitle: first.sceneTitle,
                    results: items,
                    matchCount: items.count
                )
            }
            .sorted { lhs, rhs in
                lhs.sceneTitle.localizedCaseInsensitiveCompare(rhs.sceneTitle) == .orderedAscending
            }

            return SearchResultSection(
                id: chapterTitle,
                chapterTitle: chapterTitle,
                scenes: scenes,
                matchCount: chapterEntries.count
            )
        }
    }

    func replacePreviewItems(
        filter: ReplacePreviewFilter = .all,
        sort: ReplacePreviewSort = .manuscriptOrder
    ) -> [ReplacePreviewSceneItem] {
        var orderedIds: [UUID] = []
        var counts: [UUID: Int] = [:]
        var metadata: [UUID: (chapterTitle: String, sceneTitle: String)] = [:]
        var matchTargets: [UUID: [ReplacePreviewMatchTarget]] = [:]

        for (index, result) in searchResults.enumerated() {
            if counts[result.sceneId] == nil {
                orderedIds.append(result.sceneId)
                metadata[result.sceneId] = (result.chapterTitle, result.sceneTitle)
            }
            counts[result.sceneId, default: 0] += 1
            let candidate = result.contextSnippet
            var sceneTargets = matchTargets[result.sceneId, default: []]
            if !candidate.isEmpty,
               !sceneTargets.contains(where: { $0.snippet == candidate }),
               sceneTargets.count < 3 {
                sceneTargets.append(
                    ReplacePreviewMatchTarget(
                        id: "\(result.sceneId.uuidString)-\(index)",
                        resultIndex: index,
                        snippet: candidate,
                        matchText: result.matchText
                    )
                )
                matchTargets[result.sceneId] = sceneTargets
            }
        }

        let orderMap = Dictionary(uniqueKeysWithValues: orderedIds.enumerated().map { ($0.element, $0.offset) })
        let items = orderedIds.compactMap { sceneId -> ReplacePreviewSceneItem? in
            guard let matchCount = counts[sceneId],
                  let details = metadata[sceneId],
                  let manuscriptOrder = orderMap[sceneId] else {
                return nil
            }
            return ReplacePreviewSceneItem(
                id: sceneId,
                chapterTitle: details.chapterTitle,
                sceneTitle: details.sceneTitle,
                matchCount: matchCount,
                matchTargets: matchTargets[sceneId] ?? [],
                isIncluded: isSceneIncludedForReplace(sceneId),
                manuscriptOrder: manuscriptOrder
            )
        }

        let filtered = items.filter { item in
            switch filter {
            case .all:
                return true
            case .included:
                return item.isIncluded
            case .excluded:
                return !item.isIncluded
            }
        }

        switch sort {
        case .manuscriptOrder:
            return filtered.sorted { $0.manuscriptOrder < $1.manuscriptOrder }
        case .matchCountDescending:
            return filtered.sorted {
                if $0.matchCount == $1.matchCount {
                    return $0.sceneTitle.localizedCaseInsensitiveCompare($1.sceneTitle) == .orderedAscending
                }
                return $0.matchCount > $1.matchCount
            }
        case .sceneTitle:
            return filtered.sorted {
                $0.sceneTitle.localizedCaseInsensitiveCompare($1.sceneTitle) == .orderedAscending
            }
        }
    }

    func includeReplaceScenes(withMatchCountGreaterThan threshold: Int) {
        guard canBulkSelectReplaceScenes else { return }
        let minimum = max(0, threshold)
        var counts: [UUID: Int] = [:]
        for result in searchResults {
            counts[result.sceneId, default: 0] += 1
        }
        includedReplaceSceneIDs = Set(counts.compactMap { sceneID, count in
            count > minimum ? sceneID : nil
        })
    }

    func setChapterSelectedForSearch(_ chapterID: UUID, isSelected: Bool) {
        if isSelected {
            selectedSearchChapterIDs.insert(chapterID)
        } else {
            selectedSearchChapterIDs.remove(chapterID)
        }
    }

    func selectAllSearchChapters() {
        selectedSearchChapterIDs = Set(searchableChapters.map(\.id))
    }

    func clearSearchChapterSelection() {
        selectedSearchChapterIDs = []
    }

    func saveSelectedSearchChapterPreset() -> String? {
        let selectedChapters = searchableChapters
            .filter { selectedSearchChapterIDs.contains($0.id) }
            .sorted {
                if $0.sequenceIndex == $1.sequenceIndex {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.sequenceIndex < $1.sequenceIndex
            }

        guard !selectedChapters.isEmpty else {
            return "Select at least one chapter before saving a scope preset."
        }

        let chapterIDs = selectedChapters.map(\.id)
        let chapterTitles = selectedChapters.map(\.title)
        let preset = SearchChapterScopePreset(
            id: UUID(),
            name: makeSearchChapterPresetName(from: chapterTitles),
            chapterIDs: chapterIDs,
            chapterTitles: chapterTitles,
            createdAt: Date()
        )

        searchChapterPresets.removeAll { Set($0.chapterIDs) == Set(chapterIDs) }
        searchChapterPresets.insert(preset, at: 0)
        if searchChapterPresets.count > Self.maxSearchChapterPresets {
            searchChapterPresets = Array(searchChapterPresets.prefix(Self.maxSearchChapterPresets))
        }
        persistSearchChapterPresets()
        return "Saved chapter scope preset: \(preset.name)."
    }

    func applySearchChapterPreset(_ presetID: UUID) {
        guard let preset = searchChapterPresets.first(where: { $0.id == presetID }) else { return }
        let available = Set(searchableChapters.map(\.id))
        selectedSearchChapterIDs = Set(preset.chapterIDs.filter { available.contains($0) })
    }

    func deleteSearchChapterPreset(_ presetID: UUID) {
        searchChapterPresets.removeAll { $0.id == presetID }
        persistSearchChapterPresets()
    }

    @discardableResult
    func setInspectorSceneTitle(_ rawTitle: String) -> String? {
        guard let scene = inspectorScene else { return "No scene selected." }
        let title = normalizeTitle(rawTitle, fallback: "")
        guard !title.isEmpty else { return "Scene title cannot be empty." }
        do {
            try projectManager.updateSceneMetadata(
                sceneId: scene.id,
                updates: SceneMetadataUpdate(title: title, synopsis: nil, status: nil, tags: nil, colorLabel: nil, metadata: nil)
            )
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update scene title: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorSceneStatus(_ status: ContentStatus) -> String? {
        guard let scene = inspectorScene else { return "No scene selected." }
        do {
            try projectManager.updateSceneMetadata(
                sceneId: scene.id,
                updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: status, tags: nil, colorLabel: nil, metadata: nil)
            )
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update scene status: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorSceneSynopsis(_ synopsis: String) -> String? {
        guard let scene = inspectorScene else { return "No scene selected." }
        do {
            try projectManager.updateSceneMetadata(
                sceneId: scene.id,
                updates: SceneMetadataUpdate(title: nil, synopsis: synopsis, status: nil, tags: nil, colorLabel: nil, metadata: nil)
            )
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update scene synopsis: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorSceneColorLabel(_ colorLabel: ColorLabel?) -> String? {
        guard let scene = inspectorScene else { return "No scene selected." }
        do {
            try projectManager.updateSceneMetadata(
                sceneId: scene.id,
                updates: SceneMetadataUpdate(
                    title: nil,
                    synopsis: nil,
                    status: nil,
                    tags: nil,
                    colorLabel: colorLabel,
                    clearColorLabel: colorLabel == nil,
                    metadata: nil
                )
            )
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update color label: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addInspectorTag(named rawName: String) -> String? {
        guard let scene = inspectorScene else { return "No scene selected." }
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter a tag name." }
        do {
            let tag: Tag
            if let existing = tagManager.allTags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                tag = existing
            } else {
                tag = try tagManager.createTag(name: trimmed, color: nil)
            }
            try tagManager.addTag(tag.id, to: scene.id)
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add tag: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func removeInspectorTag(_ tagID: UUID) -> String? {
        guard let scene = inspectorScene else { return "No scene selected." }
        do {
            try tagManager.removeTag(tagID, from: scene.id)
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not remove tag: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorSceneMetadata(field: String, value: String) -> String? {
        guard let scene = inspectorScene else { return "No scene selected." }
        do {
            try metadataManager.setSceneMetadata(sceneId: scene.id, field: field, value: value)
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update metadata: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addInspectorMetadataField(named rawName: String) -> String? {
        addInspectorMetadataField(named: rawName, type: .text, options: [])
    }

    @discardableResult
    func addInspectorMetadataField(named rawName: String, type: MetadataFieldType, options: [String]) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter a metadata field name." }
        do {
            let cleanedOptions = options
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let usesOptions = type == .singleSelect || type == .multiSelect
            let field = CustomMetadataField(id: UUID(), name: trimmed, fieldType: type, options: usesOptions ? cleanedOptions : [])
            try metadataManager.addField(field)
            if usesOptions {
                metadataManager.configureOptions(fieldId: field.id, options: cleanedOptions)
            }
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add metadata field: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func renameInspectorMetadataField(_ fieldID: UUID, to rawName: String) -> String? {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter a metadata field name." }
        do {
            try metadataManager.renameField(id: fieldID, newName: trimmed)
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not rename metadata field: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func updateInspectorMetadataFieldOptions(_ fieldID: UUID, options: [String]) -> String? {
        guard let field = metadataManager.customFields.first(where: { $0.id == fieldID }) else {
            return "Metadata field not found."
        }
        guard field.fieldType == .singleSelect || field.fieldType == .multiSelect else {
            return "Only select fields support options."
        }
        metadataManager.configureOptions(fieldId: fieldID, options: options)
        refreshDerivedStates()
        objectWillChange.send()
        return nil
    }

    @discardableResult
    func moveInspectorMetadataField(_ fieldID: UUID, by offset: Int) -> String? {
        do {
            try metadataManager.moveField(id: fieldID, by: offset)
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not reorder metadata field: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteInspectorMetadataField(_ fieldID: UUID) -> String? {
        do {
            try metadataManager.removeField(id: fieldID)
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not remove metadata field: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorChapterTitle(_ rawTitle: String) -> String? {
        guard let chapter = inspectorChapter else { return "No chapter selected." }
        let title = normalizeTitle(rawTitle, fallback: "")
        guard !title.isEmpty else { return "Chapter title cannot be empty." }
        do {
            try projectManager.updateChapterMetadata(
                chapterId: chapter.id,
                updates: ChapterMetadataUpdate(title: title, synopsis: nil, status: nil, goalWordCount: nil)
            )
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update chapter title: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorChapterStatus(_ status: ContentStatus) -> String? {
        guard let chapter = inspectorChapter else { return "No chapter selected." }
        do {
            try projectManager.updateChapterMetadata(
                chapterId: chapter.id,
                updates: ChapterMetadataUpdate(title: nil, synopsis: nil, status: status, goalWordCount: nil)
            )
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update chapter status: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorChapterSynopsis(_ synopsis: String) -> String? {
        guard let chapter = inspectorChapter else { return "No chapter selected." }
        do {
            try projectManager.updateChapterMetadata(
                chapterId: chapter.id,
                updates: ChapterMetadataUpdate(title: nil, synopsis: synopsis, status: nil, goalWordCount: nil)
            )
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update chapter synopsis: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setInspectorChapterGoal(_ wordCount: Int?) -> String? {
        guard let chapter = inspectorChapter else { return "No chapter selected." }
        if let wordCount {
            goalsManager.setChapterGoal(chapterId: chapter.id, wordCount: wordCount)
        } else {
            goalsManager.clearChapterGoal(chapterId: chapter.id)
        }
        refreshDerivedStates()
        objectWillChange.send()
        return nil
    }

    @discardableResult
    func updateProjectSettings(
        autosaveIntervalSeconds: Int,
        backupIntervalMinutes: Int,
        backupRetentionCount: Int,
        editorFont: String,
        editorFontSize: Int,
        editorLineHeight: Double,
        editorContentWidth: Double,
        theme: AppTheme
    ) -> String? {
        guard var settings = projectSettings else { return "No project is currently open." }
        settings.autosaveIntervalSeconds = max(5, autosaveIntervalSeconds)
        settings.backupIntervalMinutes = max(5, backupIntervalMinutes)
        settings.backupRetentionCount = max(1, backupRetentionCount)
        settings.editorFont = normalizeTitle(editorFont, fallback: settings.editorFont)
        settings.editorFontSize = max(8, editorFontSize)
        settings.editorLineHeight = max(1.0, min(editorLineHeight, 3.0))
        settings.editorContentWidth = max(520, min(editorContentWidth, 1600))
        settings.theme = theme
        do {
            try projectManager.updateProjectSettings(settings)
            projectManager.startAutosave(intervalSeconds: settings.autosaveIntervalSeconds)
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update project settings: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setTheme(_ theme: AppTheme) -> String? {
        guard let settings = projectSettings else { return "No project is currently open." }
        return updateProjectSettings(
            autosaveIntervalSeconds: settings.autosaveIntervalSeconds,
            backupIntervalMinutes: settings.backupIntervalMinutes,
            backupRetentionCount: settings.backupRetentionCount,
            editorFont: settings.editorFont,
            editorFontSize: settings.editorFontSize,
            editorLineHeight: settings.editorLineHeight,
            editorContentWidth: settings.editorContentWidth,
            theme: theme
        )
    }

    @discardableResult
    func saveAppearancePreset(id: UUID? = nil, name rawName: String) -> String? {
        guard var settings = projectSettings else { return "No project is currently open." }
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else { return "Give the appearance preset a name." }

        let preset = AppearancePreset(
            id: id ?? UUID(),
            name: name,
            theme: settings.theme,
            fontName: settings.editorFont,
            fontSize: settings.editorFontSize,
            lineHeight: settings.editorLineHeight,
            editorContentWidth: settings.editorContentWidth
        )

        if let existingIndex = settings.appearancePresets.firstIndex(where: { $0.id == preset.id }) {
            settings.appearancePresets[existingIndex] = preset
        } else if let existingIndex = settings.appearancePresets.firstIndex(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            settings.appearancePresets[existingIndex] = preset
        } else {
            settings.appearancePresets.append(preset)
        }
        settings.appearancePresets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        do {
            try projectManager.updateProjectSettings(settings)
            refreshDerivedStates()
            objectWillChange.send()
            return "Saved appearance preset “\(preset.name)”." 
        } catch {
            return "Could not save appearance preset: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func applyAppearancePreset(_ presetID: UUID) -> String? {
        guard let settings = projectSettings else { return "No project is currently open." }
        guard let preset = settings.appearancePresets.first(where: { $0.id == presetID }) else {
            return "That appearance preset could not be found."
        }
        if let error = updateProjectSettings(
            autosaveIntervalSeconds: settings.autosaveIntervalSeconds,
            backupIntervalMinutes: settings.backupIntervalMinutes,
            backupRetentionCount: settings.backupRetentionCount,
            editorFont: preset.fontName,
            editorFontSize: preset.fontSize,
            editorLineHeight: preset.lineHeight,
            editorContentWidth: preset.editorContentWidth,
            theme: preset.theme
        ) {
            return error
        }
        return "Applied appearance preset “\(preset.name)”."
    }

    @discardableResult
    func deleteAppearancePreset(_ presetID: UUID) -> String? {
        guard var settings = projectSettings else { return "No project is currently open." }
        guard let existingIndex = settings.appearancePresets.firstIndex(where: { $0.id == presetID }) else {
            return "That appearance preset could not be found."
        }
        let name = settings.appearancePresets[existingIndex].name
        settings.appearancePresets.remove(at: existingIndex)
        do {
            try projectManager.updateProjectSettings(settings)
            refreshDerivedStates()
            objectWillChange.send()
            return "Deleted appearance preset “\(name)”."
        } catch {
            return "Could not delete appearance preset: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveCompilePreset(
        id: UUID? = nil,
        name rawName: String,
        format: ExportFormat,
        includedSectionIds: [UUID],
        fontFamily: String,
        fontSize: Int,
        lineSpacing: Double,
        chapterHeadingStyle: String = "h2",
        sceneBreakMarker: String = "***",
        htmlTheme: CompileHTMLTheme = .parchment,
        pageSize: CompilePageSize = .letter,
        templateStyle: CompileTemplateStyle = .classic,
        pageMargins: Margins = Margins(top: 1, bottom: 1, left: 1, right: 1),
        subtitle: String = "",
        authorName: String = "",
        includeTitlePage: Bool,
        includeTableOfContents: Bool,
        includeStagingArea: Bool = false,
        languageCode: String = "en",
        publisherName: String = "",
        copyrightText: String = "",
        dedicationText: String = "",
        includeAboutAuthor: Bool = false,
        aboutAuthorText: String = "",
        sectionOrder: CompileSectionOrder = .manuscript,
        bibliographyText: String = "",
        appendixTitle: String = "",
        appendixContent: String = "",
        stylesheetName: String = "",
        customCSS: String = ""
    ) -> String? {
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else { return "Preset name cannot be empty." }
        do {
            var presets = projectManager.currentProject?.compilePresets ?? []
            let preset = compilePresetDraft(
                id: id ?? UUID(),
                name: name,
                format: format,
                includedSectionIds: includedSectionIds,
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                chapterHeadingStyle: chapterHeadingStyle,
                sceneBreakMarker: sceneBreakMarker,
                htmlTheme: htmlTheme,
                pageSize: pageSize,
                templateStyle: templateStyle,
                pageMargins: pageMargins,
                subtitle: subtitle,
                authorName: authorName,
                includeTitlePage: includeTitlePage,
                includeTableOfContents: includeTableOfContents,
                includeStagingArea: includeStagingArea,
                languageCode: languageCode,
                publisherName: publisherName,
                copyrightText: copyrightText,
                dedicationText: dedicationText,
                includeAboutAuthor: includeAboutAuthor,
                aboutAuthorText: aboutAuthorText,
                sectionOrder: sectionOrder,
                bibliographyText: bibliographyText,
                appendixTitle: appendixTitle,
                appendixContent: appendixContent,
                stylesheetName: stylesheetName,
                customCSS: customCSS
            )
            if let index = presets.firstIndex(where: { $0.id == preset.id }) {
                presets[index] = preset
            } else {
                presets.append(preset)
            }
            try projectManager.updateCompilePresets(presets)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not save compile preset: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteCompilePreset(_ presetID: UUID) -> String? {
        do {
            let presets = (projectManager.currentProject?.compilePresets ?? []).filter { $0.id != presetID }
            try projectManager.updateCompilePresets(presets)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not delete compile preset: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func exportProject(using presetID: UUID) -> String? {
        guard let preset = projectManager.currentProject?.compilePresets.first(where: { $0.id == presetID }) else {
            return "Compile preset not found."
        }
        return exportProject(format: preset.format, preset: preset)
    }

    @discardableResult
    func exportProject(format: ExportFormat) -> String? {
        exportProject(format: format, preset: nil)
    }

    @discardableResult
    func exportRecoveryProject(format: ExportFormat) -> String? {
        guard isRecoveryMode else {
            return exportProject(format: format)
        }
        guard let rootURL = projectManager.projectRootURL else {
            return "Could not export recovery project: Missing project root."
        }
        let exportFolderName = "\(normalizedFileStem(rootURL.lastPathComponent))-recovery-exports"
        let exportDirectory = rootURL.deletingLastPathComponent().appendingPathComponent(exportFolderName, isDirectory: true)
        return writeCompiledExport(
            format: format,
            preset: nil,
            outputDirectory: exportDirectory,
            baseName: "\(rootURL.lastPathComponent)-recovery"
        )
    }

    @discardableResult
    func duplicateRecoveryProjectAsWritableCopy() -> String? {
        guard isRecoveryMode else {
            return "Recovery duplication is only available while a project is open in recovery mode."
        }
        guard let rootURL = projectManager.projectRootURL,
              let currentProject = projectManager.currentProject else {
            return "Could not duplicate recovery project: No project is currently open."
        }

        let parentURL = rootURL.deletingLastPathComponent()
        let duplicateName = nextAvailableRecoveredProjectName(baseName: rootURL.lastPathComponent, in: parentURL)
        let destinationURL = parentURL.appendingPathComponent(duplicateName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationURL.appendingPathComponent("content", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationURL.appendingPathComponent("metadata/snapshots/baselines", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationURL.appendingPathComponent("backups", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationURL.appendingPathComponent("exports", isDirectory: true), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destinationURL.appendingPathComponent("research", isDirectory: true), withIntermediateDirectories: true)

            let sourceManifest = projectManager.getManifest()
            var copiedManifest = sourceManifest
            copiedManifest.project.name = duplicateName
            copiedManifest.project.modifiedAt = Date()

            for scene in copiedManifest.hierarchy.scenes {
                let sourceContent = try projectManager.loadSceneContent(sceneId: scene.id)
                let sceneURL = destinationURL.appendingPathComponent(scene.filePath)
                try FileManager.default.createDirectory(at: sceneURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try sourceContent.write(to: sceneURL, atomically: true, encoding: .utf8)
            }

            try ManifestCoder.write(copiedManifest, to: destinationURL.appendingPathComponent("manifest.json"))
            try ManifestCoder.formatVersion.write(to: destinationURL.appendingPathComponent(".manuscript-version"), atomically: true, encoding: .utf8)
            try writeAuxiliaryJSON(currentProject.tags, to: destinationURL.appendingPathComponent("metadata/tags.json"))
            try writeAuxiliaryJSON(currentProject.entities, to: destinationURL.appendingPathComponent("metadata/entities.json"))
            try writeAuxiliaryJSON(currentProject.notes, to: destinationURL.appendingPathComponent("metadata/notes.json"))
            try writeAuxiliaryJSON(currentProject.scratchpadItems, to: destinationURL.appendingPathComponent("metadata/scratchpad.json"))
            try writeAuxiliaryJSON(currentProject.sources, to: destinationURL.appendingPathComponent("metadata/sources.json"))
            try writeAuxiliaryJSON(currentProject.timelineEvents, to: destinationURL.appendingPathComponent("metadata/timeline.json"))
            try writeAuxiliaryJSON([String](), to: destinationURL.appendingPathComponent("metadata/presets.json"))
            try writeAuxiliaryJSON(currentProject.compilePresets, to: destinationURL.appendingPathComponent("metadata/compile-presets.json"))

            _ = try projectManager.openProject(at: destinationURL)
            didOpenProject()
            return "Created writable recovery copy \"\(duplicateName)\"."
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            return "Could not duplicate recovery project: \(error.localizedDescription)"
        }
    }

    func compilePreview(
        format: ExportFormat,
        includedSectionIds: [UUID],
        fontFamily: String,
        fontSize: Int,
        lineSpacing: Double,
        chapterHeadingStyle: String,
        sceneBreakMarker: String,
        htmlTheme: CompileHTMLTheme,
        pageSize: CompilePageSize,
        templateStyle: CompileTemplateStyle,
        pageMargins: Margins,
        subtitle: String,
        authorName: String,
        includeTitlePage: Bool,
        includeTableOfContents: Bool,
        includeStagingArea: Bool,
        languageCode: String = "en",
        publisherName: String = "",
        copyrightText: String,
        dedicationText: String,
        includeAboutAuthor: Bool,
        aboutAuthorText: String,
        sectionOrder: CompileSectionOrder,
        bibliographyText: String,
        appendixTitle: String,
        appendixContent: String,
        stylesheetName: String = "",
        customCSS: String = ""
    ) -> String? {
        do {
            let previewFormat: ExportFormat = (format == .markdown || format == .docx) ? .markdown : .html
            let preset = compilePresetDraft(
                id: UUID(),
                name: "Preview",
                format: format,
                includedSectionIds: includedSectionIds,
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                chapterHeadingStyle: chapterHeadingStyle,
                sceneBreakMarker: sceneBreakMarker,
                htmlTheme: htmlTheme,
                pageSize: pageSize,
                templateStyle: templateStyle,
                pageMargins: pageMargins,
                subtitle: subtitle,
                authorName: authorName,
                includeTitlePage: includeTitlePage,
                includeTableOfContents: includeTableOfContents,
                includeStagingArea: includeStagingArea,
                languageCode: languageCode,
                publisherName: publisherName,
                copyrightText: copyrightText,
                dedicationText: dedicationText,
                includeAboutAuthor: includeAboutAuthor,
                aboutAuthorText: aboutAuthorText,
                sectionOrder: sectionOrder,
                bibliographyText: bibliographyText,
                appendixTitle: appendixTitle,
                appendixContent: appendixContent,
                stylesheetName: stylesheetName,
                customCSS: customCSS
            )
            return try compiledProjectText(format: previewFormat, preset: preset)
        } catch {
            return "Could not generate compile preview: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addEntity(
        name rawName: String,
        type: EntityType,
        aliases: [String] = [],
        fields: [String: String] = [:],
        notes: String,
        linkSelectedScene: Bool
    ) -> String? {
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else { return "Entity name cannot be empty." }
        do {
            var entities = projectManager.currentProject?.entities ?? []
            let linkedScenes = linkSelectedScene ? [selectedSceneForContextualActions()].compactMap { $0 } : []
            entities.append(
                Entity(
                    id: UUID(),
                    entityType: type,
                    name: name,
                    aliases: aliases.map { normalizeTitle($0, fallback: "") }.filter { !$0.isEmpty },
                    fields: fields.filter { !$0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                    sceneMentions: linkedScenes,
                    relationships: [],
                    notes: notes
                )
            )
            try projectManager.updateEntities(entities)
            refreshEntityMentionHighlights()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add entity: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func updateEntity(
        _ entityID: UUID,
        name rawName: String,
        type: EntityType,
        aliases: [String],
        fields: [String: String],
        notes: String
    ) -> String? {
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else { return "Entity name cannot be empty." }
        do {
            var entities = projectManager.currentProject?.entities ?? []
            guard let index = entities.firstIndex(where: { $0.id == entityID }) else {
                return "Entity not found."
            }
            entities[index].name = name
            entities[index].entityType = type
            entities[index].aliases = aliases.map { normalizeTitle($0, fallback: "") }.filter { !$0.isEmpty }
            entities[index].fields = fields.reduce(into: [:]) { result, entry in
                let key = normalizeTitle(entry.key, fallback: "")
                let value = normalizeTitle(entry.value, fallback: "")
                if !key.isEmpty && !value.isEmpty {
                    result[key] = value
                }
            }
            entities[index].notes = notes
            try projectManager.updateEntities(entities)
            refreshEntityMentionHighlights()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update entity: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteEntity(_ entityID: UUID) -> String? {
        do {
            let entities = (projectManager.currentProject?.entities ?? []).filter { $0.id != entityID }
            try projectManager.updateEntities(entities)
            refreshEntityMentionHighlights()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not delete entity: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addSource(
        title rawTitle: String,
        author rawAuthor: String?,
        date rawDate: String?,
        url rawURL: String?,
        publication rawPublication: String? = nil,
        volume rawVolume: String? = nil,
        pages rawPages: String? = nil,
        doi rawDOI: String? = nil,
        notes: String,
        citationKey rawCitationKey: String?,
        linkedSceneIDs: [UUID] = [],
        linkedEntityIDs: [UUID] = [],
        linkedNoteIDs: [UUID] = []
    ) -> String? {
        let title = normalizeTitle(rawTitle, fallback: "")
        guard !title.isEmpty else { return "Source title cannot be empty." }
        do {
            var sources = projectManager.currentProject?.sources ?? []
            let citationKey = uniqueCitationKey(rawCitationKey, title: title, excluding: nil)
            sources.append(
                Source(
                    id: UUID(),
                    title: title,
                    author: normalizedOptionalText(rawAuthor),
                    date: normalizedOptionalText(rawDate),
                    url: normalizedOptionalText(rawURL),
                    publication: normalizedOptionalText(rawPublication),
                    volume: normalizedOptionalText(rawVolume),
                    pages: normalizedOptionalText(rawPages),
                    doi: normalizedOptionalText(rawDOI),
                    notes: notes,
                    citationKey: citationKey,
                    attachments: [],
                    linkedSceneIds: linkedSceneIDs.filter(sceneExists),
                    linkedEntityIds: linkedEntityIDs.filter(entityExists),
                    linkedNoteIds: linkedNoteIDs.filter(noteExists)
                )
            )
            try projectManager.updateSources(sources)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add source: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func updateSource(
        _ sourceID: UUID,
        title rawTitle: String,
        author rawAuthor: String?,
        date rawDate: String?,
        url rawURL: String?,
        publication rawPublication: String? = nil,
        volume rawVolume: String? = nil,
        pages rawPages: String? = nil,
        doi rawDOI: String? = nil,
        notes: String,
        citationKey rawCitationKey: String?,
        linkedSceneIDs: [UUID] = [],
        linkedEntityIDs: [UUID] = [],
        linkedNoteIDs: [UUID] = []
    ) -> String? {
        let title = normalizeTitle(rawTitle, fallback: "")
        guard !title.isEmpty else { return "Source title cannot be empty." }
        do {
            var sources = projectManager.currentProject?.sources ?? []
            guard let index = sources.firstIndex(where: { $0.id == sourceID }) else {
                return "Source not found."
            }
            sources[index].title = title
            sources[index].author = normalizedOptionalText(rawAuthor)
            sources[index].date = normalizedOptionalText(rawDate)
            sources[index].url = normalizedOptionalText(rawURL)
            sources[index].publication = normalizedOptionalText(rawPublication)
            sources[index].volume = normalizedOptionalText(rawVolume)
            sources[index].pages = normalizedOptionalText(rawPages)
            sources[index].doi = normalizedOptionalText(rawDOI)
            sources[index].notes = notes
            sources[index].citationKey = uniqueCitationKey(rawCitationKey, title: title, excluding: sourceID)
            sources[index].linkedSceneIds = linkedSceneIDs.filter(sceneExists)
            sources[index].linkedEntityIds = linkedEntityIDs.filter(entityExists)
            sources[index].linkedNoteIds = linkedNoteIDs.filter(noteExists)
            try projectManager.updateSources(sources)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update source: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteSource(_ sourceID: UUID) -> String? {
        do {
            let sources = (projectManager.currentProject?.sources ?? []).filter { $0.id != sourceID }
            try projectManager.updateSources(sources)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not delete source: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func insertCitation(_ sourceID: UUID) -> String? {
        guard let source = sources.first(where: { $0.id == sourceID }) else {
            return "Source not found."
        }
        let editor = activeEditorState()
        let selection = editor.selection ?? (editor.cursorPosition..<editor.cursorPosition)
        editor.replaceText(in: selection, with: "[@\(source.citationKey)]")
        objectWillChange.send()
        return nil
    }

    @discardableResult
    func importResearchFile(from url: URL, into sourceID: UUID) -> String? {
        guard let rootURL = projectManager.projectRootURL else {
            return "Could not import research file: No project is currently open."
        }
        do {
            var sources = projectManager.currentProject?.sources ?? []
            guard let index = sources.firstIndex(where: { $0.id == sourceID }) else {
                return "Source not found."
            }
            let researchURL = rootURL.appendingPathComponent("research", isDirectory: true)
            try FileManager.default.createDirectory(at: researchURL, withIntermediateDirectories: true)
            let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased()
            let storedFilename = "\(sourceID.uuidString.lowercased())-\(UUID().uuidString.lowercased()).\(ext)"
            let destinationURL = researchURL.appendingPathComponent(storedFilename)
            try FileManager.default.copyItem(at: url, to: destinationURL)
            let attachment = ResearchAttachment(
                id: UUID(),
                filename: url.lastPathComponent,
                storedFilename: storedFilename,
                mimeType: UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream",
                importedAt: Date()
            )
            sources[index].attachments.append(attachment)
            try projectManager.updateSources(sources)
            objectWillChange.send()
            return "Imported research file \(url.lastPathComponent)."
        } catch {
            return "Could not import research file: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func removeResearchAttachment(_ attachmentID: UUID, from sourceID: UUID) -> String? {
        guard let rootURL = projectManager.projectRootURL else {
            return "Could not remove research file: No project is currently open."
        }
        var sources = projectManager.currentProject?.sources ?? []
        guard let sourceIndex = sources.firstIndex(where: { $0.id == sourceID }) else {
            return "Source not found."
        }
        guard let attachmentIndex = sources[sourceIndex].attachments.firstIndex(where: { $0.id == attachmentID }) else {
            return "Research file not found."
        }
        let attachment = sources[sourceIndex].attachments.remove(at: attachmentIndex)
        let fileURL = rootURL.appendingPathComponent("research/\(attachment.storedFilename)")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        do {
            try projectManager.updateSources(sources)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not remove research file: \(error.localizedDescription)"
        }
    }

    func sourceSceneMentions(_ sourceID: UUID) -> [ManifestScene] {
        guard let source = sources.first(where: { $0.id == sourceID }) else { return [] }
        let token = "[@\(source.citationKey)]"
        return projectManager.getManifest().hierarchy.scenes.filter { scene in
            currentContentForScene(scene.id).localizedCaseInsensitiveContains(token)
        }
    }

    func sourceLinkedNotes(_ sourceID: UUID) -> [Note] {
        guard let source = sources.first(where: { $0.id == sourceID }) else { return [] }
        return notes.filter { source.linkedNoteIds.contains($0.id) }
    }

    func sourceLinkedEntities(_ sourceID: UUID) -> [Entity] {
        guard let source = sources.first(where: { $0.id == sourceID }) else { return [] }
        return entities.filter { source.linkedEntityIds.contains($0.id) }
    }

    func sourceLinkedScenes(_ sourceID: UUID) -> [ManifestScene] {
        guard let source = sources.first(where: { $0.id == sourceID }) else { return [] }
        let ids = Set(source.linkedSceneIds)
        return projectManager.getManifest().hierarchy.scenes.filter { ids.contains($0.id) }
    }

    func researchAttachmentURL(sourceID: UUID, attachmentID: UUID) -> URL? {
        guard
            let rootURL = projectManager.projectRootURL,
            let source = sources.first(where: { $0.id == sourceID }),
            let attachment = source.attachments.first(where: { $0.id == attachmentID })
        else {
            return nil
        }
        let url = rootURL.appendingPathComponent("research/\(attachment.storedFilename)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func openResearchAttachment(_ attachmentID: UUID, from sourceID: UUID) -> String? {
        guard let url = researchAttachmentURL(sourceID: sourceID, attachmentID: attachmentID) else {
            return "Research file could not be found on disk."
        }
        NSWorkspace.shared.open(url)
        return nil
    }

    @discardableResult
    func revealResearchAttachment(_ attachmentID: UUID, from sourceID: UUID) -> String? {
        guard let url = researchAttachmentURL(sourceID: sourceID, attachmentID: attachmentID) else {
            return "Research file could not be found on disk."
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return nil
    }

    func compileWarnings(
        includedSectionIds: [UUID],
        pageMargins: Margins,
        format: ExportFormat,
        languageCode: String,
        publisherName: String
    ) -> [String] {
        var warnings: [String] = []
        if includedSectionIds.isEmpty {
            warnings.append("No chapters are selected for export.")
        }
        if pageMargins.left + pageMargins.right >= 4 || pageMargins.top + pageMargins.bottom >= 4 {
            warnings.append("Large page margins may reduce usable page area significantly.")
        }
        if format == .epub {
            if languageCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append("EPUB export should include a language code.")
            }
            if publisherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                warnings.append("EPUB export is missing publisher metadata.")
            }
        }
        return warnings
    }

    @discardableResult
    func exportProjectDraft(
        format: ExportFormat,
        includedSectionIds: [UUID],
        fontFamily: String,
        fontSize: Int,
        lineSpacing: Double,
        chapterHeadingStyle: String,
        sceneBreakMarker: String,
        htmlTheme: CompileHTMLTheme,
        pageSize: CompilePageSize,
        templateStyle: CompileTemplateStyle,
        pageMargins: Margins,
        subtitle: String,
        authorName: String,
        includeTitlePage: Bool,
        includeTableOfContents: Bool,
        includeStagingArea: Bool,
        languageCode: String,
        publisherName: String,
        copyrightText: String,
        dedicationText: String,
        includeAboutAuthor: Bool,
        aboutAuthorText: String,
        sectionOrder: CompileSectionOrder,
        bibliographyText: String,
        appendixTitle: String,
        appendixContent: String,
        stylesheetName: String,
        customCSS: String,
        recoveryMode: Bool = false
    ) -> String? {
        let preset = compilePresetDraft(
            id: UUID(),
            name: "Draft Export",
            format: format,
            includedSectionIds: includedSectionIds,
            fontFamily: fontFamily,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            chapterHeadingStyle: chapterHeadingStyle,
            sceneBreakMarker: sceneBreakMarker,
            htmlTheme: htmlTheme,
            pageSize: pageSize,
            templateStyle: templateStyle,
            pageMargins: pageMargins,
            subtitle: subtitle,
            authorName: authorName,
            includeTitlePage: includeTitlePage,
            includeTableOfContents: includeTableOfContents,
            includeStagingArea: includeStagingArea,
            languageCode: languageCode,
            publisherName: publisherName,
            copyrightText: copyrightText,
            dedicationText: dedicationText,
            includeAboutAuthor: includeAboutAuthor,
            aboutAuthorText: aboutAuthorText,
            sectionOrder: sectionOrder,
            bibliographyText: bibliographyText,
            appendixTitle: appendixTitle,
            appendixContent: appendixContent,
            stylesheetName: stylesheetName,
            customCSS: customCSS
        )
        return exportProject(format: format, preset: preset, recoveryMode: recoveryMode)
    }

    func openFirstCitationMention(for sourceID: UUID) -> String? {
        guard let sceneID = sourceSceneMentions(sourceID).first?.id else {
            return "No citation mentions found for this source."
        }
        navigateToSceneInActivePane(sceneID)
        return nil
    }

    @discardableResult
    func addTimelineEvent(
        title rawTitle: String,
        description: String,
        track rawTrack: String,
        position: TimelinePosition,
        linkedSceneIDs: [UUID],
        color rawColor: String?
    ) -> String? {
        let title = normalizeTitle(rawTitle, fallback: "")
        let track = normalizeTitle(rawTrack, fallback: "")
        guard !title.isEmpty else { return "Timeline event title cannot be empty." }
        guard !track.isEmpty else { return "Timeline track cannot be empty." }
        do {
            var events = projectManager.currentProject?.timelineEvents ?? []
            events.append(
                TimelineEvent(
                    id: UUID(),
                    title: title,
                    description: description,
                    track: track,
                    position: position,
                    linkedSceneIds: linkedSceneIDs.filter(sceneExists),
                    color: normalizedOptionalText(rawColor)
                )
            )
            try projectManager.updateTimelineEvents(events)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add timeline event: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func updateTimelineEvent(
        _ eventID: UUID,
        title rawTitle: String,
        description: String,
        track rawTrack: String,
        position: TimelinePosition,
        linkedSceneIDs: [UUID],
        color rawColor: String?
    ) -> String? {
        let title = normalizeTitle(rawTitle, fallback: "")
        let track = normalizeTitle(rawTrack, fallback: "")
        guard !title.isEmpty else { return "Timeline event title cannot be empty." }
        guard !track.isEmpty else { return "Timeline track cannot be empty." }
        do {
            var events = projectManager.currentProject?.timelineEvents ?? []
            guard let index = events.firstIndex(where: { $0.id == eventID }) else {
                return "Timeline event not found."
            }
            events[index].title = title
            events[index].description = description
            events[index].track = track
            events[index].position = position
            events[index].linkedSceneIds = linkedSceneIDs.filter(sceneExists)
            events[index].color = normalizedOptionalText(rawColor)
            try projectManager.updateTimelineEvents(events)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update timeline event: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteTimelineEvent(_ eventID: UUID) -> String? {
        do {
            let events = (projectManager.currentProject?.timelineEvents ?? []).filter { $0.id != eventID }
            try projectManager.updateTimelineEvents(events)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not delete timeline event: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func linkSelectedSceneToEntity(_ entityID: UUID) -> String? {
        guard let sceneID = selectedSceneForContextualActions() else { return "No scene selected." }
        do {
            var entities = projectManager.currentProject?.entities ?? []
            guard let index = entities.firstIndex(where: { $0.id == entityID }) else {
                return "Entity not found."
            }
            if !entities[index].sceneMentions.contains(sceneID) {
                entities[index].sceneMentions.append(sceneID)
            }
            try projectManager.updateEntities(entities)
            refreshEntityMentionHighlights()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not link entity: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func scanEntityMentions(_ entityID: UUID) -> String? {
        do {
            var entities = projectManager.currentProject?.entities ?? []
            guard let index = entities.firstIndex(where: { $0.id == entityID }) else {
                return "Entity not found."
            }
            let rawTerms = [entities[index].name] + entities[index].aliases
            let terms = Set(
                rawTerms.flatMap { raw -> [String] in
                    let normalized = normalizeTitle(raw, fallback: "")
                    guard !normalized.isEmpty else { return [] }
                    let tokens = normalized
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { $0.count >= 3 }
                    return [normalized] + tokens
                }
            )
            guard !terms.isEmpty else { return "Entity needs a name or alias before scanning." }
            let manifest = projectManager.getManifest()
            let matchedSceneIDs = manifest.hierarchy.scenes.compactMap { scene -> UUID? in
                let haystack = currentContentForScene(scene.id)
                let synopsis = scene.synopsis
                let combined = "\(scene.title)\n\(synopsis)\n\(haystack)".lowercased()
                let found = terms.contains { term in
                    combined.localizedCaseInsensitiveContains(term.lowercased())
                }
                return found ? scene.id : nil
            }
            entities[index].sceneMentions = matchedSceneIDs
            try projectManager.updateEntities(entities)
            refreshEntityMentionHighlights()
            objectWillChange.send()
            return "Found \(matchedSceneIDs.count) scene mention(s) for \(entities[index].name)."
        } catch {
            return "Could not scan entity mentions: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addEntityRelationship(
        from entityID: UUID,
        to targetEntityID: UUID,
        label rawLabel: String,
        bidirectional: Bool
    ) -> String? {
        let label = normalizeTitle(rawLabel, fallback: "")
        guard !label.isEmpty else { return "Relationship label cannot be empty." }
        guard entityID != targetEntityID else { return "An entity cannot relate to itself." }
        do {
            var entities = projectManager.currentProject?.entities ?? []
            guard let sourceIndex = entities.firstIndex(where: { $0.id == entityID }),
                  let targetIndex = entities.firstIndex(where: { $0.id == targetEntityID }) else {
                return "Entity not found."
            }
            if !entities[sourceIndex].relationships.contains(where: { $0.targetEntityId == targetEntityID && $0.label == label }) {
                entities[sourceIndex].relationships.append(
                    EntityRelationship(targetEntityId: targetEntityID, label: label, isBidirectional: bidirectional)
                )
            }
            if bidirectional,
               !entities[targetIndex].relationships.contains(where: { $0.targetEntityId == entityID && $0.label == label }) {
                entities[targetIndex].relationships.append(
                    EntityRelationship(targetEntityId: entityID, label: label, isBidirectional: true)
                )
            }
            try projectManager.updateEntities(entities)
            refreshEntityMentionHighlights()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add entity relationship: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func removeEntityRelationship(from entityID: UUID, to targetEntityID: UUID, label rawLabel: String) -> String? {
        let label = normalizeTitle(rawLabel, fallback: "")
        do {
            var entities = projectManager.currentProject?.entities ?? []
            guard let sourceIndex = entities.firstIndex(where: { $0.id == entityID }) else {
                return "Entity not found."
            }
            let removedRelationship = entities[sourceIndex].relationships.first {
                $0.targetEntityId == targetEntityID && $0.label == label
            }
            entities[sourceIndex].relationships.removeAll { $0.targetEntityId == targetEntityID && $0.label == label }
            if removedRelationship?.isBidirectional == true,
               let targetIndex = entities.firstIndex(where: { $0.id == targetEntityID }) {
                entities[targetIndex].relationships.removeAll { $0.targetEntityId == entityID && $0.label == label }
            }
            try projectManager.updateEntities(entities)
            refreshEntityMentionHighlights()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not remove entity relationship: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addNote(
        title rawTitle: String,
        content: String,
        folder rawFolder: String?,
        linkedSceneIDs: [UUID],
        linkedEntityIDs: [UUID]
    ) -> String? {
        let title = normalizeTitle(rawTitle, fallback: "")
        guard !title.isEmpty else { return "Note title cannot be empty." }
        do {
            var notes = projectManager.currentProject?.notes ?? []
            let now = Date()
            notes.append(
                Note(
                    id: UUID(),
                    title: title,
                    content: content,
                    folder: normalizeTitle(rawFolder ?? "", fallback: "").isEmpty ? nil : normalizeTitle(rawFolder ?? "", fallback: ""),
                    tags: [],
                    linkedSceneIds: linkedSceneIDs.filter(sceneExists),
                    linkedEntityIds: linkedEntityIDs.filter(entityExists),
                    attachments: [],
                    createdAt: now,
                    modifiedAt: now
                )
            )
            try projectManager.updateNotes(notes)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add note: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func updateNote(
        _ noteID: UUID,
        title rawTitle: String,
        content: String,
        folder rawFolder: String?,
        linkedSceneIDs: [UUID],
        linkedEntityIDs: [UUID]
    ) -> String? {
        let title = normalizeTitle(rawTitle, fallback: "")
        guard !title.isEmpty else { return "Note title cannot be empty." }
        do {
            var notes = projectManager.currentProject?.notes ?? []
            guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else {
                return "Note not found."
            }
            notes[noteIndex].title = title
            notes[noteIndex].content = content
            let normalizedFolder = normalizeTitle(rawFolder ?? "", fallback: "")
            notes[noteIndex].folder = normalizedFolder.isEmpty ? nil : normalizedFolder
            notes[noteIndex].linkedSceneIds = linkedSceneIDs.filter(sceneExists)
            notes[noteIndex].linkedEntityIds = linkedEntityIDs.filter(entityExists)
            notes[noteIndex].modifiedAt = Date()
            try projectManager.updateNotes(notes)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update note: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteNote(_ noteID: UUID) -> String? {
        do {
            let notes = (projectManager.currentProject?.notes ?? []).filter { $0.id != noteID }
            try projectManager.updateNotes(notes)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not delete note: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addScratchpadItem(title rawTitle: String, content: String, kind: ScratchpadItemKind) -> String? {
        let title = normalizeTitle(rawTitle, fallback: kind == .clipboard ? "Clipboard Snippet" : "Scratchpad Note")
        do {
            var items = projectManager.currentProject?.scratchpadItems ?? []
            items.append(
                ScratchpadItem(
                    id: UUID(),
                    title: title,
                    content: content,
                    kind: kind,
                    createdAt: Date(),
                    modifiedAt: Date(),
                    lastUsedAt: nil
                )
            )
            try projectManager.updateScratchpadItems(items)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not add scratchpad item: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func updateScratchpadItem(_ itemID: UUID, title rawTitle: String, content: String, kind: ScratchpadItemKind) -> String? {
        let title = normalizeTitle(rawTitle, fallback: kind == .clipboard ? "Clipboard Snippet" : "Scratchpad Note")
        do {
            var items = projectManager.currentProject?.scratchpadItems ?? []
            guard let index = items.firstIndex(where: { $0.id == itemID }) else {
                return "Scratchpad item not found."
            }
            items[index].title = title
            items[index].content = content
            items[index].kind = kind
            items[index].modifiedAt = Date()
            try projectManager.updateScratchpadItems(items)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not update scratchpad item: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func deleteScratchpadItem(_ itemID: UUID) -> String? {
        do {
            let items = (projectManager.currentProject?.scratchpadItems ?? []).filter { $0.id != itemID }
            try projectManager.updateScratchpadItems(items)
            objectWillChange.send()
            return nil
        } catch {
            return "Could not delete scratchpad item: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func insertScratchpadItem(_ itemID: UUID) -> String? {
        guard let item = (projectManager.currentProject?.scratchpadItems ?? []).first(where: { $0.id == itemID }) else {
            return "Scratchpad item not found."
        }
        let editor = activeEditorState()
        let selection = editor.selection ?? (editor.cursorPosition..<editor.cursorPosition)
        editor.replaceText(in: selection, with: item.content)
        do {
            var items = projectManager.currentProject?.scratchpadItems ?? []
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index].lastUsedAt = Date()
                items[index].modifiedAt = Date()
                try projectManager.updateScratchpadItems(items)
            }
            objectWillChange.send()
            return nil
        } catch {
            return "Inserted text, but could not update scratchpad history: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func captureSelectionToScratchpad(title rawTitle: String, as kind: ScratchpadItemKind) -> String? {
        let editor = activeEditorState()
        guard let selection = editor.selection, selection.lowerBound < selection.upperBound else {
            return "Select text before sending it to the scratchpad."
        }
        let content = editor.getCurrentContent()
        let start = content.index(content.startIndex, offsetBy: selection.lowerBound)
        let end = content.index(content.startIndex, offsetBy: selection.upperBound)
        return addScratchpadItem(title: rawTitle, content: String(content[start..<end]), kind: kind)
    }

    func entityLinkedScenes(_ entityID: UUID) -> [ManifestScene] {
        guard let entity = entities.first(where: { $0.id == entityID }) else { return [] }
        let scenesByID = Dictionary(uniqueKeysWithValues: projectManager.getManifest().hierarchy.scenes.map { ($0.id, $0) })
        return entity.sceneMentions.compactMap { scenesByID[$0] }
    }

    func entityRelationships(_ entityID: UUID) -> [(relationship: EntityRelationship, target: Entity)] {
        guard let entity = entities.first(where: { $0.id == entityID }) else { return [] }
        let entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        return entity.relationships.compactMap { relationship in
            guard let target = entitiesByID[relationship.targetEntityId] else { return nil }
            return (relationship, target)
        }
    }

    func notesLinkedToScene(_ sceneID: UUID) -> [Note] {
        notes.filter { $0.linkedSceneIds.contains(sceneID) }
    }

    func notesLinkedToEntity(_ entityID: UUID) -> [Note] {
        notes.filter { $0.linkedEntityIds.contains(entityID) }
    }

    func sceneTitleForDisplay(_ sceneID: UUID) -> String {
        sceneTitle(sceneID)
    }

    func entityNameForDisplay(_ entityID: UUID) -> String {
        entities.first(where: { $0.id == entityID })?.name ?? "Unknown Entity"
    }

    func sourceTitleForDisplay(_ sourceID: UUID) -> String {
        sources.first(where: { $0.id == sourceID })?.title ?? "Unknown Source"
    }

    @discardableResult
    func insertEntityMention(_ entityID: UUID) -> String? {
        guard let entity = entities.first(where: { $0.id == entityID }) else {
            return "Entity not found."
        }
        let editor = activeEditorState()
        let selection = editor.selection ?? (editor.cursorPosition..<editor.cursorPosition)
        editor.replaceText(in: selection, with: entity.name)
        refreshEntityMentionHighlights()
        objectWillChange.send()
        return nil
    }

    @discardableResult
    func navigateToEntityPrimaryScene(_ entityID: UUID) -> String? {
        guard let sceneID = entityLinkedScenes(entityID).first?.id else {
            return "No linked scenes found for this entity."
        }
        navigateToScene(sceneID)
        return nil
    }

    func focusNotes(onScene sceneID: UUID?) {
        notesFocusSceneID = sceneID
        notesFocusEntityID = nil
    }

    func focusNotes(onEntity entityID: UUID?) {
        notesFocusEntityID = entityID
        notesFocusSceneID = nil
    }

    func clearNotesFocus() {
        notesFocusSceneID = nil
        notesFocusEntityID = nil
    }

    func entitiesMentioned(in sceneID: UUID) -> [Entity] {
        entities.filter { $0.sceneMentions.contains(sceneID) }
    }

    func highlightedEntityMentions(in sceneID: UUID) -> [(entity: Entity, snippet: String)] {
        guard let scene = projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID }) else { return [] }
        let sceneContent = currentContentForScene(sceneID)
        let haystack = "\(scene.title)\n\(scene.synopsis)\n\(sceneContent)"
        return entitiesMentioned(in: sceneID).compactMap { entity in
            let terms = ([entity.name] + entity.aliases)
                .map { normalizeTitle($0, fallback: "") }
                .filter { !$0.isEmpty }
            guard let term = terms.first(where: { haystack.localizedCaseInsensitiveContains($0) }),
                  let snippet = mentionSnippet(in: haystack, term: term) else {
                return nil
            }
            return (entity, snippet)
        }
    }

    func relationshipDescription(source: Entity, relationship: EntityRelationship, target: Entity) -> String {
        if relationship.isBidirectional {
            return "\(source.name) ↔ \(target.name): \(relationship.label)"
        }
        return "\(source.name) → \(target.name): \(relationship.label)"
    }

    @discardableResult
    func batchSendSelectedScenesToStaging() -> String? {
        guard canBatchStageSelectedScenes else { return "No movable chapter scenes selected." }
        do {
            for sceneID in modularState.selectedSceneIds {
                if projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })?.parentChapterId != nil {
                    try projectManager.moveToStaging(sceneId: sceneID)
                }
            }
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not send selected scenes to staging: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func batchMoveSelectedScenes(toChapter chapterID: UUID) -> String? {
        guard canBatchMoveSelectedScenesToChapter else { return "No scenes selected for batch move." }
        guard chapterExists(chapterID) else { return "Target chapter not found." }
        do {
            for sceneID in modularState.selectedSceneIds {
                let destinationCount = projectManager.getManifest().hierarchy.chapters.first(where: { $0.id == chapterID })?.scenes.count ?? 0
                try projectManager.moveScene(sceneId: sceneID, toChapterId: chapterID, atIndex: destinationCount)
            }
            refreshDerivedStates()
            objectWillChange.send()
            return nil
        } catch {
            return "Could not move selected scenes: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func exportProject(format: ExportFormat, preset: CompilePreset?, recoveryMode: Bool? = nil) -> String? {
        let shouldUseRecoveryDirectory = recoveryMode ?? isRecoveryMode
        guard hasOpenProject else {
            return "Could not export project: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard let rootURL = projectManager.projectRootURL else {
            return "Could not export project: Missing project root."
        }
        let exportsURL = shouldUseRecoveryDirectory
            ? rootURL.deletingLastPathComponent().appendingPathComponent("\(projectDisplayName)-recovery-exports", isDirectory: true)
            : rootURL.appendingPathComponent("exports", isDirectory: true)
        return writeCompiledExport(
            format: format,
            preset: preset,
            outputDirectory: exportsURL,
            baseName: preset?.name ?? projectDisplayName
        )
    }

    @discardableResult
    func importScenes(from url: URL) -> String? {
        guard hasOpenProject else {
            return "Could not import scenes: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        do {
            let importedText = try String(contentsOf: url, encoding: .utf8)
            let scenes = parseImportedScenes(from: importedText, sourceName: url.deletingPathExtension().lastPathComponent)
            guard !scenes.isEmpty else {
                return "No scenes were found in \(url.lastPathComponent)."
            }
            let targetChapterID = try resolveImportTargetChapter()
            var createdSceneIDs: [UUID] = []
            let startingIndex = projectManager.getManifest().hierarchy.chapters.first(where: { $0.id == targetChapterID })?.scenes.count ?? 0
            for (offset, sceneDraft) in scenes.enumerated() {
                let created = try projectManager.addScene(to: targetChapterID, at: startingIndex + offset, title: sceneDraft.title)
                try projectManager.saveSceneContent(sceneId: created.id, content: sceneDraft.content)
                if !sceneDraft.synopsis.isEmpty {
                    try projectManager.updateSceneMetadata(
                        sceneId: created.id,
                        updates: SceneMetadataUpdate(title: nil, synopsis: sceneDraft.synopsis, status: nil, tags: nil, colorLabel: nil, metadata: nil)
                    )
                }
                createdSceneIDs.append(created.id)
            }
            refreshDerivedStates()
            if let firstSceneID = createdSceneIDs.first {
                navigateToSceneInActivePane(firstSceneID)
            }
            return "Imported \(createdSceneIDs.count) scene(s) from \(url.lastPathComponent)."
        } catch {
            return "Could not import scenes: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func undoLastReplaceBatch() -> String? {
        guard hasOpenProject else {
            return "Could not undo replace: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard canUndoLastReplaceBatch else {
            return "No replace batch to undo."
        }
        do {
            try searchEngine.undoLastReplaceAll()
            refreshDerivedStates()
            reloadOpenEditorScenes()
            runSearch()
            let remaining = replaceUndoDepth
            if remaining == 0 {
                return "Undid last replace batch."
            }
            return "Undid last replace batch. \(remaining) batch(es) still available."
        } catch {
            return "Could not undo replace: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func redoLastReplaceBatch() -> String? {
        guard hasOpenProject else {
            return "Could not redo replace: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard canRedoLastReplaceBatch else {
            return "No replace batch to redo."
        }
        do {
            try searchEngine.redoLastReplaceAll()
            refreshDerivedStates()
            reloadOpenEditorScenes()
            runSearch()
            let remaining = replaceRedoDepth
            if remaining == 0 {
                return "Redid last replace batch."
            }
            return "Redid last replace batch. \(remaining) batch(es) still available."
        } catch {
            return "Could not redo replace: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func replaceNextSearchResult() -> String? {
        guard hasOpenProject else {
            return "Could not replace: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard !searchQueryText.isEmpty else {
            return "Could not replace: Search text cannot be empty."
        }
        runSearch()
        guard let currentSearchResultIndex, searchResults.indices.contains(currentSearchResultIndex) else {
            return "No search matches to replace."
        }
        let result = searchResults[currentSearchResultIndex]
        selectSearchResult(at: currentSearchResultIndex)

        let editor = activeEditorState()
        let before = editor.getCurrentContent()
        let range = clamp(range: result.matchRange, maxLength: before.count)
        guard range.lowerBound < range.upperBound else {
            return "No search matches to replace."
        }
        let replacement = replacementTextForNextMatch(in: before, range: range)
        editor.replaceText(in: range, with: replacement)
        let after = editor.getCurrentContent()
        guard before != after else {
            return "No search matches to replace."
        }

        if let sceneId = editor.currentSceneId {
            try? projectManager.saveSceneContent(sceneId: sceneId, content: after)
            searchEngine.updateIndex(sceneId: sceneId, content: after)
        }

        runSearch()
        return "Replaced next match."
    }

    var searchResultPositionText: String {
        guard let currentSearchResultIndex, !searchResults.isEmpty else {
            return "0 of 0"
        }
        return "\(currentSearchResultIndex + 1) of \(searchResults.count)"
    }

    func selectSearchResult(at index: Int) {
        guard searchResults.indices.contains(index) else { return }
        currentSearchResultIndex = index
        applySearchResult(searchResults[index])
        updateEditorSearchHighlights()
    }

    func selectReplacePreviewMatch(sceneID: UUID, resultIndex: Int) {
        guard searchResults.indices.contains(resultIndex) else { return }
        let result = searchResults[resultIndex]
        guard result.sceneId == sceneID else { return }
        selectSearchResult(at: resultIndex)
    }

    func navigateToNextSearchResult() {
        guard !searchResults.isEmpty else { return }
        let next: Int
        if let currentSearchResultIndex {
            next = (currentSearchResultIndex + 1) % searchResults.count
        } else {
            next = 0
        }
        selectSearchResult(at: next)
    }

    func navigateToPreviousSearchResult() {
        guard !searchResults.isEmpty else { return }
        let previous: Int
        if let currentSearchResultIndex {
            previous = (currentSearchResultIndex - 1 + searchResults.count) % searchResults.count
        } else {
            previous = searchResults.count - 1
        }
        selectSearchResult(at: previous)
    }

    var searchHighlightCapRange: ClosedRange<Int> {
        Self.minSearchHighlightCap...Self.maxSearchHighlightCap
    }

    var searchHighlightSafetyThresholdRange: ClosedRange<Int> {
        Self.minSearchHighlightSafetyThreshold...Self.maxSearchHighlightSafetyThreshold
    }

    var usesDefaultSearchHighlightPreferences: Bool {
        searchHighlightCap == Self.defaultSearchHighlightCap
            && searchHighlightSafetyThreshold == Self.defaultSearchHighlightSafetyThreshold
    }

    var hiddenSearchHighlightCount: Int {
        guard !searchShowAllHighlights else { return 0 }
        let total = activeSceneMatchCountForHighlights()
        return max(0, total - searchHighlightCap)
    }

    var canEnableShowAllSearchHighlights: Bool {
        guard isSearchPanelVisible, !searchShowAllHighlights else { return false }
        let total = activeSceneMatchCountForHighlights()
        guard total > searchHighlightCap else { return false }
        return total <= searchHighlightSafetyThreshold
    }

    var canToggleSearchHighlightMode: Bool {
        if searchShowAllHighlights {
            return isSearchPanelVisible && activeSceneMatchCountForHighlights() > searchHighlightCap
        }
        return canEnableShowAllSearchHighlights
    }

    var searchHighlightSafetyMessage: String? {
        let total = activeSceneMatchCountForHighlights()
        guard !searchShowAllHighlights,
              total > searchHighlightSafetyThreshold,
              total > searchHighlightCap else {
            return nil
        }
        return "Show-all disabled for active scene (\(total) matches; limit \(searchHighlightSafetyThreshold))."
    }

    func toggleShowAllSearchHighlights() {
        if searchShowAllHighlights {
            searchShowAllHighlights = false
            updateEditorSearchHighlights()
            return
        }
        guard canEnableShowAllSearchHighlights else { return }
        searchShowAllHighlights = true
        updateEditorSearchHighlights()
    }

    func updateSearchHighlightCap(_ value: Int) {
        let normalized = Self.normalizeSearchHighlightPreferences(cap: value, threshold: searchHighlightSafetyThreshold)
        searchHighlightCap = normalized.cap
        searchHighlightSafetyThreshold = normalized.threshold
        persistSearchHighlightPreferences()
        if searchShowAllHighlights && !canUseShowAllHighlightsForCurrentContext() {
            searchShowAllHighlights = false
        }
        updateEditorSearchHighlights()
    }

    func updateSearchHighlightSafetyThreshold(_ value: Int) {
        let normalized = Self.normalizeSearchHighlightPreferences(cap: searchHighlightCap, threshold: value)
        searchHighlightCap = normalized.cap
        searchHighlightSafetyThreshold = normalized.threshold
        persistSearchHighlightPreferences()
        if searchShowAllHighlights && !canUseShowAllHighlightsForCurrentContext() {
            searchShowAllHighlights = false
        }
        updateEditorSearchHighlights()
    }

    func resetSearchHighlightPreferencesToDefaults() {
        let normalized = Self.normalizeSearchHighlightPreferences(
            cap: Self.defaultSearchHighlightCap,
            threshold: Self.defaultSearchHighlightSafetyThreshold
        )
        searchHighlightCap = normalized.cap
        searchHighlightSafetyThreshold = normalized.threshold
        persistSearchHighlightPreferences()
        if searchShowAllHighlights && !canUseShowAllHighlightsForCurrentContext() {
            searchShowAllHighlights = false
        }
        updateEditorSearchHighlights()
    }

    func showSearchHighlightHelp() {
        guard isSearchPanelVisible else { return }
        isSearchHighlightHelpVisible = true
    }

    func hideSearchHighlightHelp() {
        isSearchHighlightHelpVisible = false
    }

    @discardableResult
    func saveProjectAs(named rawName: String) -> String? {
        guard hasOpenProject else {
            return "Could not save project as: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else {
            return "Could not save project as: Project name cannot be empty."
        }

        let sourceURL = projectManager.projectRootURL!
        let destinationURL: URL
        do {
            destinationURL = try destinationProjectURL(forName: name)
        } catch {
            return "Could not save project as: \(error.localizedDescription)"
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return "Could not save project as: A project named \"\(name)\" already exists."
        }

        var copied = false
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            copied = true
            let copiedLock = destinationURL.appendingPathComponent(".lock")
            if FileManager.default.fileExists(atPath: copiedLock.path) {
                try? FileManager.default.removeItem(at: copiedLock)
            }
            _ = try projectManager.openProject(at: destinationURL)
            try projectManager.updateProjectName(name)
            try projectManager.saveManifest()
            didOpenProject()
            return "Saved project as \"\(projectDisplayName)\"."
        } catch {
            if copied {
                try? FileManager.default.removeItem(at: destinationURL)
                if projectManager.currentProject == nil {
                    _ = try? projectManager.openProject(at: sourceURL)
                    didOpenProject()
                }
            }
            return "Could not save project as: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func renameCurrentProject(to rawName: String) -> String? {
        guard hasOpenProject else {
            return "Could not rename project: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else {
            return "Could not rename project: Project name cannot be empty."
        }

        let sourceURL = projectManager.projectRootURL!
        if sourceURL.lastPathComponent == name {
            return nil
        }

        let destinationURL: URL
        do {
            destinationURL = try destinationProjectURL(forName: name)
        } catch {
            return "Could not rename project: \(error.localizedDescription)"
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return "Could not rename project: A project named \"\(name)\" already exists."
        }

        var closed = false
        var moved = false
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            try projectManager.closeProject()
            closed = true
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            moved = true
            _ = try projectManager.openProject(at: destinationURL)
            try projectManager.updateProjectName(name)
            try projectManager.saveManifest()
            didOpenProject()
            return "Renamed project to \"\(projectDisplayName)\"."
        } catch {
            if moved {
                _ = try? projectManager.openProject(at: destinationURL)
                didOpenProject()
            } else if closed {
                _ = try? projectManager.openProject(at: sourceURL)
                didOpenProject()
            }
            return "Could not rename project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createChapter(title: String? = nil) -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not create chapter: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let resolvedTitle: String
        if let title {
            let normalized = normalizeTitle(title, fallback: "")
            if !normalized.isEmpty {
                resolvedTitle = normalized
            } else {
                resolvedTitle = nextGeneratedChapterTitle()
            }
        } else {
            resolvedTitle = nextGeneratedChapterTitle()
        }

        do {
            let chapter = try projectManager.addChapter(to: nil, at: nil, title: resolvedTitle)
            refreshDerivedStates()
            navigationState.navigateTo(chapterId: chapter.id)
            return nil
        } catch {
            return "Could not create chapter: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createScene(title: String? = nil) -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not create scene: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let resolvedTitle: String
        if let title {
            let normalized = normalizeTitle(title, fallback: "")
            if !normalized.isEmpty {
                resolvedTitle = normalized
            } else {
                resolvedTitle = nextGeneratedSceneTitle()
            }
        } else {
            resolvedTitle = nextGeneratedSceneTitle()
        }
        do {
            let chapterId = try resolveChapterForSceneCreation()
            let scene = try projectManager.addScene(to: chapterId, at: nil, title: resolvedTitle)
            refreshDerivedStates()
            navigateToSceneInActivePane(scene.id)
            return nil
        } catch {
            return "Could not create scene: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func toggleSplitForCommand(defaultWindowWidth: CGFloat = 1200) -> String? {
        toggleSplit(windowWidth: defaultWindowWidth)
    }

    @discardableResult
    func navigateToNextScene() -> Bool {
        guard projectManager.currentProject != nil, modeController.activeMode == .linear else { return false }
        let before = editorState.currentSceneId
        linearState.goToNextScene()
        return editorState.currentSceneId != before
    }

    @discardableResult
    func navigateToPreviousScene() -> Bool {
        guard projectManager.currentProject != nil, modeController.activeMode == .linear else { return false }
        let before = editorState.currentSceneId
        linearState.goToPreviousScene()
        return editorState.currentSceneId != before
    }

    @discardableResult
    func saveProjectNow() -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not save project: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            return nil
        } catch {
            return "Could not save project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createBackupNow() -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not create backup: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let beforeCount = projectManager.listBackups().count
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            try projectManager.createBackup()
            let backups = projectManager.listBackups()
            if let latest = backups.first, backups.count >= beforeCount {
                return "Backup created: \(latest.filename)"
            }
            return "Backup created."
        } catch {
            return "Could not create backup: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveAndBackupNow() -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not save and back up project: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            let beforeCount = projectManager.listBackups().count
            try projectManager.createBackup()
            let backups = projectManager.listBackups()
            if let latest = backups.first, backups.count >= beforeCount {
                return "Project saved and backup created: \(latest.filename)"
            }
            return "Project saved and backup created."
        } catch {
            return "Could not save and back up project: \(error.localizedDescription)"
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard hasOpenProject else {
            goalsManager.handleAppFocusChanged(isFocused: false)
            return
        }
        switch phase {
        case .active:
            if goalsManager.sessionStartTime == nil {
                goalsManager.startSession(goal: nil)
            }
            goalsManager.handleAppFocusChanged(isFocused: true)
        case .inactive:
            goalsManager.handleAppFocusChanged(isFocused: false)
            autosaveOpenEditors()
        case .background:
            goalsManager.handleAppFocusChanged(isFocused: false)
            autosaveOpenEditors()
            try? projectManager.saveManifest()
        @unknown default:
            break
        }
    }

    private static func bootstrapProject(
        using manager: FileSystemProjectManager,
        rootURL: URL?,
        projectName: String,
        recentProjectStore: UserDefaults
    ) throws {
        let fm = FileManager.default
        if rootURL == nil {
            let storedRecent = recentProjectStore.array(forKey: recentProjectsKey) as? [String] ?? []
            for path in storedRecent {
                let url = URL(fileURLWithPath: path, isDirectory: true)
                if fm.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
                    _ = try manager.openProject(at: url)
                    return
                }
            }

            if let lastPath = recentProjectStore.string(forKey: lastOpenedProjectPathKey) {
                let lastURL = URL(fileURLWithPath: lastPath, isDirectory: true)
                if fm.fileExists(atPath: lastURL.appendingPathComponent("manifest.json").path) {
                    _ = try manager.openProject(at: lastURL)
                    return
                }
                recentProjectStore.removeObject(forKey: lastOpenedProjectPathKey)
            }
        }

        let root: URL
        if let rootURL {
            root = rootURL
        } else {
            let appSupport = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            root = appSupport.appendingPathComponent("Scribbles-N-Scripts", isDirectory: true)
        }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let projectRoot = root.appendingPathComponent(projectName, isDirectory: true)
        if fm.fileExists(atPath: projectRoot.path) {
            _ = try manager.openProject(at: projectRoot)
        } else {
            _ = try manager.createProject(name: projectName, at: root)
        }
    }

    private static func defaultProjectContainerURL(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("Scribbles-N-Scripts", isDirectory: true)
    }

    private static func makeDependencies(
        manager: FileSystemProjectManager,
        splitSettingsStore: UserDefaults,
        splitSettingsNamespace: String
    ) -> (
        navigationState: NavigationState,
        editorState: EditorState,
        linearState: LinearModeState,
        modularState: ModularModeState,
        modeController: ModeController,
        splitEditorState: SplitEditorState,
        goalsManager: GoalsManager
    ) {
        let navigationState = NavigationState(projectProvider: { manager.currentProject })
        let editorState = EditorState(sceneLoader: { id in
            (try? manager.loadSceneContent(sceneId: id)) ?? ""
        })
        let linearState = LinearModeState(projectManager: manager, navigationState: navigationState, editorState: editorState)
        let modularState = ModularModeState(projectManager: manager, navigationState: navigationState, editorState: editorState)
        let modeController = ModeController(
            projectManager: manager,
            navigationState: navigationState,
            editorState: editorState,
            linearState: linearState,
            modularState: modularState
        )
        let splitEditorState = SplitEditorState(
            projectManager: manager,
            primarySceneId: editorState.currentSceneId,
            settingsStore: splitSettingsStore,
            settingsNamespace: splitSettingsNamespace
        )
        let goalsManager = GoalsManager(projectManager: manager)
        return (navigationState, editorState, linearState, modularState, modeController, splitEditorState, goalsManager)
    }

    private static func splitSettingsNamespace(for manager: FileSystemProjectManager) -> String {
        guard let root = manager.projectRootURL else { return "splitEditor.default" }
        let sanitized = root.path.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        return "splitEditor.\(String(sanitized))"
    }

    private func autosaveOpenEditors() {
        try? editorState.autosaveIfNeeded(projectManager: projectManager)
        splitEditorState.autosaveOpenPanes()
    }

    private func didOpenProject() {
        refreshDerivedStates()
        updateEditorEditability()
        tagManager.reloadFromProject()
        metadataManager.reloadFromProject()
        modeController.switchTo(.linear)
        splitEditorState.closeSplit()
        loadSearchChapterPresets()
        if let interval = projectManager.currentProject?.settings.autosaveIntervalSeconds {
            projectManager.startAutosave(intervalSeconds: interval)
        }

        if let first = linearState.orderedSceneIds.first {
            editorState.navigateToScene(id: first)
            navigationState.navigateTo(sceneId: first)
            splitEditorState.primarySceneId = first
            splitEditorState.secondarySceneId = nil
        } else {
            navigationState.selectedSceneId = nil
            navigationState.selectedChapterId = nil
            navigationState.breadcrumb = []
        }

        persistLastOpenedProject()
        startSearchIndexing()
    }

    private func updateEditorEditability() {
        let editable = !isRecoveryMode
        editorState.isEditable = editable
        splitEditorState.primaryEditor.isEditable = editable
        splitEditorState.secondaryEditor.isEditable = editable
    }

    private func projectRootForNewProjects() throws -> URL {
        if let currentRoot = projectManager.projectRootURL {
            return currentRoot.deletingLastPathComponent()
        }
        return try Self.defaultProjectContainerURL(fileManager: .default)
    }

    private func destinationProjectURL(forName name: String) throws -> URL {
        let root = try projectRootForNewProjects()
        return root.appendingPathComponent(name, isDirectory: true)
    }

    private func persistLastOpenedProject() {
        guard let rootURL = projectManager.projectRootURL else { return }
        recentProjectStore.set(rootURL.path, forKey: Self.lastOpenedProjectPathKey)
        var stored = recentProjectStore.array(forKey: Self.recentProjectsKey) as? [String] ?? []
        stored.removeAll { $0 == rootURL.path }
        stored.insert(rootURL.path, at: 0)
        if stored.count > Self.maxRecentProjects {
            stored.removeLast(stored.count - Self.maxRecentProjects)
        }
        recentProjectStore.set(stored, forKey: Self.recentProjectsKey)
    }

    private func lastOpenedProjectURL() -> URL? {
        guard let path = recentProjectStore.string(forKey: Self.lastOpenedProjectPathKey) else {
            return nil
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) else {
            return nil
        }
        return url
    }

    private func recentProjectURLs() -> [URL] {
        let stored = recentProjectPaths()
        var seen = Set<String>()
        var urls: [URL] = []
        for path in stored {
            guard !seen.contains(path) else { continue }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) else {
                continue
            }
            urls.append(url)
            seen.insert(path)
        }
        return urls
    }

    private var currentProjectEntry: RecentProjectEntry? {
        guard let root = projectManager.projectRootURL else { return nil }
        return RecentProjectEntry(id: root.path, name: projectDisplayName, url: root)
    }

    private func recentProjectPaths() -> [String] {
        recentProjectStore.array(forKey: Self.recentProjectsKey) as? [String] ?? []
    }

    private func synchronizeReplaceSceneSelection() {
        let available = Set(searchResults.map(\.sceneId))
        if replaceSceneUniverse.isEmpty || replaceSceneSelectionMode == .resetOnSearch {
            includedReplaceSceneIDs = available
            replaceSceneUniverse = available
            return
        }

        let removed = replaceSceneUniverse.subtracting(available)
        let added = available.subtracting(replaceSceneUniverse)
        includedReplaceSceneIDs.subtract(removed)
        includedReplaceSceneIDs.formUnion(added)
        replaceSceneUniverse = available
    }

    private static func normalizeSearchHighlightPreferences(cap: Int, threshold: Int) -> (cap: Int, threshold: Int) {
        let normalizedCap = min(max(cap, minSearchHighlightCap), maxSearchHighlightCap)
        let minimumThreshold = max(normalizedCap + 1, minSearchHighlightSafetyThreshold)
        let normalizedThreshold = min(max(threshold, minimumThreshold), maxSearchHighlightSafetyThreshold)
        return (normalizedCap, normalizedThreshold)
    }

    private static func normalizePeripheralTextSize(_ value: CGFloat) -> CGFloat {
        min(max(value, CGFloat(minPeripheralTextSize)), CGFloat(maxPeripheralTextSize))
    }

    private func persistSearchHighlightPreferences() {
        searchPreferenceStore.set(searchHighlightCap, forKey: Self.searchHighlightCapKey)
        searchPreferenceStore.set(searchHighlightSafetyThreshold, forKey: Self.searchHighlightSafetyThresholdKey)
    }

    @discardableResult
    func setSidebarTextSize(_ size: CGFloat) -> String? {
        let normalized = Self.normalizePeripheralTextSize(size)
        guard normalized != sidebarTextSize else { return nil }
        sidebarTextSize = normalized
        searchPreferenceStore.set(Double(normalized), forKey: Self.sidebarTextSizeKey)
        return "Sidebar text is now \(Int(normalized)) pt."
    }

    @discardableResult
    func adjustSidebarTextSize(by delta: CGFloat) -> String? {
        setSidebarTextSize(sidebarTextSize + delta)
    }

    @discardableResult
    func resetSidebarTextSize() -> String? {
        setSidebarTextSize(CGFloat(Self.defaultSidebarTextSize))
    }

    @discardableResult
    func setInspectorTextSize(_ size: CGFloat) -> String? {
        let normalized = Self.normalizePeripheralTextSize(size)
        guard normalized != inspectorTextSize else { return nil }
        inspectorTextSize = normalized
        searchPreferenceStore.set(Double(normalized), forKey: Self.inspectorTextSizeKey)
        return "Inspector text is now \(Int(normalized)) pt."
    }

    @discardableResult
    func adjustInspectorTextSize(by delta: CGFloat) -> String? {
        setInspectorTextSize(inspectorTextSize + delta)
    }

    @discardableResult
    func resetInspectorTextSize() -> String? {
        setInspectorTextSize(CGFloat(Self.defaultInspectorTextSize))
    }

    @discardableResult
    func adjustEditorTextSize(by delta: Int) -> String? {
        guard let settings = projectSettings else { return "No project is currently open." }
        return updateProjectSettings(
            autosaveIntervalSeconds: settings.autosaveIntervalSeconds,
            backupIntervalMinutes: settings.backupIntervalMinutes,
            backupRetentionCount: settings.backupRetentionCount,
            editorFont: settings.editorFont,
            editorFontSize: settings.editorFontSize + delta,
            editorLineHeight: settings.editorLineHeight,
            editorContentWidth: settings.editorContentWidth,
            theme: settings.theme
        )
    }

    @discardableResult
    func resetEditorTextSize() -> String? {
        guard let settings = projectSettings else { return "No project is currently open." }
        return updateProjectSettings(
            autosaveIntervalSeconds: settings.autosaveIntervalSeconds,
            backupIntervalMinutes: settings.backupIntervalMinutes,
            backupRetentionCount: settings.backupRetentionCount,
            editorFont: settings.editorFont,
            editorFontSize: 14,
            editorLineHeight: settings.editorLineHeight,
            editorContentWidth: settings.editorContentWidth,
            theme: settings.theme
        )
    }

    private func persistReplaceSceneSelectionModePreference() {
        searchPreferenceStore.set(replaceSceneSelectionMode.rawValue, forKey: Self.replaceSceneSelectionModeKey)
    }

    private func regexCaptureGroupCount() -> Int {
        guard searchIsRegex else { return 0 }
        guard let regex = try? NSRegularExpression(pattern: searchQueryText) else { return 0 }
        return regex.numberOfCaptureGroups
    }

    private func referencedReplacementCaptureGroups() -> [Int] {
        let pattern = try? NSRegularExpression(pattern: "\\$([0-9]+)")
        let nsRange = NSRange(searchReplacementText.startIndex..<searchReplacementText.endIndex, in: searchReplacementText)
        return pattern?.matches(in: searchReplacementText, range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: searchReplacementText) else { return nil }
            return Int(searchReplacementText[range])
        } ?? []
    }

    private func searchChapterPresetKey() -> String? {
        guard let root = projectManager.projectRootURL else { return nil }
        let sanitized = root.path.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        return "\(Self.searchChapterPresetKeyPrefix).\(String(sanitized))"
    }

    private func loadSearchChapterPresets() {
        guard let key = searchChapterPresetKey(),
              let data = searchPreferenceStore.data(forKey: key),
              let presets = try? JSONDecoder().decode([SearchChapterScopePreset].self, from: data) else {
            searchChapterPresets = []
            return
        }

        let availableTitles = Dictionary(uniqueKeysWithValues: searchableChapters.map { ($0.id, $0.title) })
        searchChapterPresets = presets.compactMap { preset in
            let chapterIDs = preset.chapterIDs.filter { availableTitles[$0] != nil }
            guard !chapterIDs.isEmpty else { return nil }
            return SearchChapterScopePreset(
                id: preset.id,
                name: preset.name,
                chapterIDs: chapterIDs,
                chapterTitles: chapterIDs.compactMap { availableTitles[$0] },
                createdAt: preset.createdAt
            )
        }
    }

    private func persistSearchChapterPresets() {
        guard let key = searchChapterPresetKey() else { return }
        if searchChapterPresets.isEmpty {
            searchPreferenceStore.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(searchChapterPresets) else { return }
        searchPreferenceStore.set(data, forKey: key)
    }

    private func makeSearchChapterPresetName(from chapterTitles: [String]) -> String {
        let cleaned = chapterTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if cleaned.count == 1 {
            return cleaned[0]
        }
        if cleaned.count == 2 {
            return "\(cleaned[0]) + \(cleaned[1])"
        }
        if let first = cleaned.first {
            return "\(first) +\(cleaned.count - 1)"
        }
        return "Selected Chapters"
    }

    private func makeSearchEngine() -> IndexedSearchEngine {
        IndexedSearchEngine(
            projectManager: projectManager,
            currentSceneProvider: { [weak self] in
                self?.editorState.currentSceneId
            },
            currentChapterProvider: { [weak self] in
                self?.navigationState.selectedChapterId
            },
            unsavedSceneProvider: { [weak self] in
                guard let self, let sceneId = self.editorState.currentSceneId else { return nil }
                return (sceneId, self.editorState.getCurrentContent())
            }
        )
    }

    private func configureEditorEntityHighlighting() {
        editorObservationCancellables.removeAll()
        observeEntityHighlights(for: editorState)
        observeEntityHighlights(for: splitEditorState.primaryEditor)
        observeEntityHighlights(for: splitEditorState.secondaryEditor)
        refreshEntityMentionHighlights()
    }

    private func observeEntityHighlights(for editor: EditorState) {
        editor.$characterCount
            .combineLatest(editor.$currentSceneId)
            .sink { [weak self] _, _ in
                self?.applyEntityMentionHighlights(to: editor)
            }
            .store(in: &editorObservationCancellables)
    }

    private func refreshEntityMentionHighlights() {
        applyEntityMentionHighlights(to: editorState)
        applyEntityMentionHighlights(to: splitEditorState.primaryEditor)
        applyEntityMentionHighlights(to: splitEditorState.secondaryEditor)
    }

    private func applyEntityMentionHighlights(to editor: EditorState) {
        guard let sceneID = editor.currentSceneId else {
            editor.clearEntityMentionHighlights()
            return
        }
        let content = editor.getCurrentContent()
        let ranges = entityMentionRanges(in: content)
        editor.setEntityMentionHighlights(ranges: ranges)
        if editor === editorState, notesFocusSceneID == nil, notesFocusEntityID == nil, sceneExists(sceneID) {
            objectWillChange.send()
        }
    }

    private func entityMentionRanges(in content: String) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for entity in entities {
            let terms = ([entity.name] + entity.aliases)
                .map { normalizeTitle($0, fallback: "") }
                .filter { !$0.isEmpty }
            for term in terms {
                var searchStart = content.startIndex
                while searchStart < content.endIndex,
                      let foundRange = content.range(of: term, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<content.endIndex) {
                    let lower = content.distance(from: content.startIndex, to: foundRange.lowerBound)
                    let upper = content.distance(from: content.startIndex, to: foundRange.upperBound)
                    ranges.append(lower..<upper)
                    searchStart = foundRange.upperBound
                }
            }
        }
        return deduplicatedRanges(ranges)
    }

    private func deduplicatedRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
        var seen = Set<String>()
        return ranges.filter { range in
            let key = "\(range.lowerBound)-\(range.upperBound)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
        .sorted { lhs, rhs in
            if lhs.lowerBound == rhs.lowerBound {
                return lhs.upperBound < rhs.upperBound
            }
            return lhs.lowerBound < rhs.lowerBound
        }
    }

    private func makeSearchQuery() -> SearchQuery {
        let scope: SearchScope
        switch searchScope {
        case .currentScene:
            scope = .currentScene
        case .currentChapter:
            scope = .currentChapter
        case .entireProject:
            scope = .entireProject
        case .selectedChapters:
            scope = .selectedChapters(ids: Array(selectedSearchChapterIDs))
        case .formattingItalic:
            scope = .markdownFormatting(.italic)
        case .formattingBold:
            scope = .markdownFormatting(.bold)
        case .formattingHeadings:
            scope = .markdownFormatting(.heading(level: nil))
        case .formattingStrikethrough:
            scope = .markdownFormatting(.strikethrough)
        case .formattingCodeBlocks:
            scope = .markdownFormatting(.codeBlock)
        case .formattingInlineCode:
            scope = .markdownFormatting(.inlineCode)
        case .formattingBlockQuotes:
            scope = .markdownFormatting(.blockQuote)
        case .formattingLinks:
            scope = .markdownFormatting(.link)
        case .formattingFootnotes:
            scope = .markdownFormatting(.footnote)
        }
        return SearchQuery(
            text: searchQueryText,
            isRegex: searchIsRegex,
            isCaseSensitive: searchIsCaseSensitive,
            isWholeWord: searchIsWholeWord,
            scope: scope
        )
    }

    private func startSearchIndexing() {
        Task { @MainActor [weak self] in
            guard let self, let project = self.projectManager.currentProject else { return }
            self.isSearchIndexing = true
            self.searchIndexStatus = SearchIndexStatus(completed: 0, total: self.projectManager.getManifest().hierarchy.scenes.count)
            await self.searchEngine.buildIndex(for: project) { [weak self] status in
                self?.searchIndexStatus = status
                self?.isSearchIndexing = status.isIndexing
            }
            self.isSearchIndexing = false
        }
    }

    private func refreshDerivedStates() {
        linearState.reloadSequence()
        modularState.reload()
    }

    private func applySearchResult(_ result: SearchResult) {
        let activeSceneId = splitEditorState.isSplit && splitEditorState.activePaneIndex == 1
            ? splitEditorState.secondarySceneId
            : splitEditorState.primarySceneId
        if activeSceneId != result.sceneId {
            navigateToSceneInActivePane(result.sceneId)
        }

        let content = editorState.getCurrentContent()
        let clamped = clamp(range: result.matchRange, maxLength: content.count)
        editorState.selection = clamped
        editorState.cursorPosition = clamped.upperBound

        let activeEditor = activeEditorState()
        activeEditor.selection = clamped
        activeEditor.cursorPosition = clamped.upperBound
    }

    private func updateEditorSearchHighlights() {
        guard isSearchPanelVisible else {
            clearEditorSearchHighlights()
            return
        }
        applyHighlights(to: editorState, sceneId: editorState.currentSceneId)
        applyHighlights(to: splitEditorState.primaryEditor, sceneId: splitEditorState.primarySceneId)
        if splitEditorState.isSplit {
            applyHighlights(to: splitEditorState.secondaryEditor, sceneId: splitEditorState.secondarySceneId)
        } else {
            splitEditorState.secondaryEditor.clearSearchHighlights()
        }
    }

    private func applyHighlights(to editor: EditorState, sceneId: UUID?) {
        guard let sceneId else {
            editor.clearSearchHighlights()
            return
        }
        let ranges = searchResults
            .filter { $0.sceneId == sceneId }
            .map(\.matchRange)
        let visibleRanges = searchShowAllHighlights ? ranges : Array(ranges.prefix(searchHighlightCap))
        let activeRange: Range<Int>?
        if let currentSearchResultIndex, searchResults.indices.contains(currentSearchResultIndex) {
            let result = searchResults[currentSearchResultIndex]
            activeRange = result.sceneId == sceneId ? result.matchRange : nil
        } else {
            activeRange = nil
        }
        editor.setSearchHighlights(ranges: visibleRanges, activeRange: activeRange)
    }

    private func clearEditorSearchHighlights() {
        editorState.clearSearchHighlights()
        splitEditorState.primaryEditor.clearSearchHighlights()
        splitEditorState.secondaryEditor.clearSearchHighlights()
    }

    private func activeSceneIdForHighlights() -> UUID? {
        if splitEditorState.isSplit, splitEditorState.activePaneIndex == 1 {
            return splitEditorState.secondarySceneId
        }
        return splitEditorState.primarySceneId ?? editorState.currentSceneId
    }

    private func activeSceneMatchCountForHighlights() -> Int {
        guard let activeSceneId = activeSceneIdForHighlights() else { return 0 }
        return searchResults.filter { $0.sceneId == activeSceneId }.count
    }

    private func canUseShowAllHighlightsForCurrentContext() -> Bool {
        activeSceneMatchCountForHighlights() <= searchHighlightSafetyThreshold
    }

    private func activeEditorState() -> EditorState {
        guard splitEditorState.isSplit else {
            return editorState
        }
        if splitEditorState.activePaneIndex == 1 {
            return splitEditorState.secondaryEditor
        }
        return splitEditorState.primaryEditor
    }

    private func clamp(range: Range<Int>, maxLength: Int) -> Range<Int> {
        let lower = max(0, min(range.lowerBound, maxLength))
        let upper = max(lower, min(range.upperBound, maxLength))
        return lower..<upper
    }

    private func replacementTextForNextMatch(in content: String, range: Range<Int>) -> String {
        guard searchIsRegex else { return searchReplacementText }
        let query = makeSearchQuery()
        var pattern = query.text
        if query.isWholeWord {
            pattern = "\\b(?:\(pattern))\\b"
        }
        let options: NSRegularExpression.Options = query.isCaseSensitive ? [] : [.caseInsensitive]
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return searchReplacementText
        }

        let start = content.index(content.startIndex, offsetBy: range.lowerBound)
        let end = content.index(content.startIndex, offsetBy: range.upperBound)
        let target = String(content[start..<end])
        let nsRange = NSRange(target.startIndex..<target.endIndex, in: target)
        return regex.stringByReplacingMatches(in: target, range: nsRange, withTemplate: searchReplacementText)
    }

    private func reloadOpenEditorScenes() {
        if let primary = splitEditorState.primarySceneId {
            splitEditorState.primaryEditor.navigateToScene(id: primary)
            editorState.navigateToScene(id: primary)
            navigationState.navigateTo(sceneId: primary)
        }
        if splitEditorState.isSplit, let secondary = splitEditorState.secondarySceneId {
            splitEditorState.secondaryEditor.navigateToScene(id: secondary)
        }
    }

    private func resolveChapterForSceneCreation() throws -> UUID {
        guard projectManager.currentProject != nil else {
            throw ProjectIOError.noOpenProject
        }
        let manifest = projectManager.getManifest()
        let validChapterIds = Set(manifest.hierarchy.chapters.map(\.id))
        if let selected = navigationState.selectedChapterId,
           validChapterIds.contains(selected) {
            return selected
        }

        if let selectedScene = navigationState.selectedSceneId,
           let parent = manifest.hierarchy.scenes.first(where: { $0.id == selectedScene })?.parentChapterId,
           validChapterIds.contains(parent) {
            return parent
        }

        if let currentScene = editorState.currentSceneId,
           let parent = manifest.hierarchy.scenes.first(where: { $0.id == currentScene })?.parentChapterId,
           validChapterIds.contains(parent) {
            return parent
        }

        if let firstChapter = manifest.hierarchy.chapters.sorted(by: { $0.sequenceIndex < $1.sequenceIndex }).first {
            return firstChapter.id
        }

        let newChapter = try projectManager.addChapter(to: nil, at: nil, title: nextGeneratedChapterTitle())
        return newChapter.id
    }

    private func resolveSceneForSplitOpen() -> UUID? {
        guard projectManager.currentProject != nil else {
            return nil
        }
        let validSceneIds = Set(projectManager.getManifest().hierarchy.scenes.map(\.id))
        let candidates: [UUID?] = [
            navigationState.selectedSceneId,
            editorState.currentSceneId,
            linearState.orderedSceneIds.first
        ]
        for candidate in candidates {
            if let candidate, validSceneIds.contains(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func selectedSceneForContextualActions() -> UUID? {
        navigationState.selectedSceneId ?? editorState.currentSceneId
    }

    private func selectedSceneContext() -> (scene: ManifestScene, chapter: ManifestChapter?, sceneIndex: Int)? {
        guard let sceneID = selectedSceneForContextualActions() else {
            return nil
        }
        let manifest = projectManager.getManifest()
        guard let scene = manifest.hierarchy.scenes.first(where: { $0.id == sceneID }) else {
            return nil
        }
        if let parentChapterId = scene.parentChapterId,
           let chapter = manifest.hierarchy.chapters.first(where: { $0.id == parentChapterId }),
           let sceneIndex = chapter.scenes.firstIndex(of: sceneID) {
            return (scene, chapter, sceneIndex)
        }
        if let stagingIndex = manifest.hierarchy.stagingScenes.firstIndex(of: sceneID) {
            return (scene, nil, stagingIndex)
        }
        return nil
    }

    private func moveSelectedScene(offset: Int) -> String? {
        guard hasOpenProject else {
            return "Could not move scene: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard let context = selectedSceneContext() else {
            return "Could not move scene: No scene selected."
        }

        let targetIndex: Int
        switch offset {
        case -1:
            guard context.sceneIndex > 0 else {
                return "Scene is already at the top of the chapter."
            }
            targetIndex = context.sceneIndex - 1
        case 1:
            guard let chapter = context.chapter else {
                return "Scene is already in staging."
            }
            guard context.sceneIndex + 1 < chapter.scenes.count else {
                return "Scene is already at the bottom of the chapter."
            }
            targetIndex = context.sceneIndex + 2
        default:
            return "Could not move scene: Unsupported move offset."
        }

        do {
            guard let chapter = context.chapter else {
                return "Could not move scene: Staging scenes must be moved into a chapter first."
            }
            try projectManager.moveScene(
                sceneId: context.scene.id,
                toChapterId: chapter.id,
                atIndex: targetIndex
            )
            refreshDerivedStates()
            navigateToSceneInActivePane(context.scene.id)
            return nil
        } catch {
            return "Could not move scene: \(error.localizedDescription)"
        }
    }

    private func sceneExists(_ id: UUID) -> Bool {
        projectManager.getManifest().hierarchy.scenes.contains(where: { $0.id == id })
    }

    private func navigateToSceneInActivePane(_ sceneId: UUID) {
        navigationState.navigateTo(sceneId: sceneId)
        editorState.navigateToScene(id: sceneId)
        if splitEditorState.activePaneIndex == 1, splitEditorState.isSplit {
            splitEditorState.secondarySceneId = sceneId
            splitEditorState.secondaryEditor.navigateToScene(id: sceneId)
        } else {
            splitEditorState.primarySceneId = sceneId
            splitEditorState.primaryEditor.navigateToScene(id: sceneId)
        }
    }

    private func chapterExists(_ id: UUID) -> Bool {
        projectManager.getManifest().hierarchy.chapters.contains(where: { $0.id == id })
    }

    private func entityExists(_ id: UUID) -> Bool {
        (projectManager.currentProject?.entities ?? []).contains(where: { $0.id == id })
    }

    private func noteExists(_ id: UUID) -> Bool {
        (projectManager.currentProject?.notes ?? []).contains(where: { $0.id == id })
    }

    private func sceneTitle(_ sceneID: UUID) -> String {
        projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })?.title ?? "Unknown Scene"
    }

    private func currentContentForScene(_ sceneID: UUID) -> String {
        if editorState.currentSceneId == sceneID, editorState.isModified {
            return editorState.getCurrentContent()
        }
        if splitEditorState.primarySceneId == sceneID, splitEditorState.primaryEditor.isModified {
            return splitEditorState.primaryEditor.getCurrentContent()
        }
        if splitEditorState.secondarySceneId == sceneID, splitEditorState.secondaryEditor.isModified {
            return splitEditorState.secondaryEditor.getCurrentContent()
        }
        return (try? projectManager.loadSceneContent(sceneId: sceneID)) ?? ""
    }

    private func mentionSnippet(in text: String, term: String) -> String? {
        guard let range = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        let distance = text.distance(from: text.startIndex, to: range.lowerBound)
        let startOffset = max(0, distance - 32)
        let endOffset = min(text.count, distance + term.count + 32)
        let start = text.index(text.startIndex, offsetBy: startOffset)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        let prefix = startOffset > 0 ? "..." : ""
        let suffix = endOffset < text.count ? "..." : ""
        return prefix + text[start..<end].trimmingCharacters(in: .whitespacesAndNewlines) + suffix
    }

    private func normalizeTitle(_ value: String, fallback: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? fallback : collapsed
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        let normalized = normalizeTitle(value ?? "", fallback: "")
        return normalized.isEmpty ? nil : normalized
    }

    private func uniqueCitationKey(_ rawValue: String?, title: String, excluding sourceID: UUID?) -> String {
        let requested = normalizeTitle(rawValue ?? "", fallback: "")
        let baseInput = requested.isEmpty ? title : requested
        let baseStem = normalizedFileStem(baseInput)
        let base = baseStem.isEmpty ? "source" : baseStem.lowercased()
        let existing = Set(
            sources
                .filter { $0.id != sourceID }
                .map { $0.citationKey.lowercased() }
        )
        guard existing.contains(base) else {
            return base
        }
        var suffix = 2
        while existing.contains("\(base)\(suffix)") {
            suffix += 1
        }
        return "\(base)\(suffix)"
    }

    private func normalizedFileStem(_ value: String) -> String {
        let normalized = normalizeTitle(value, fallback: "Project")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = normalized.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let raw = String(scalars)
        let collapsed = raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func fileExtension(for format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return "md"
        case .html:
            return "html"
        case .docx:
            return "docx"
        case .pdf:
            return "pdf"
        case .epub:
            return "epub"
        }
    }

    private func writeCompiledExport(
        format: ExportFormat,
        preset: CompilePreset?,
        outputDirectory: URL,
        baseName: String
    ) -> String? {
        do {
            if !isRecoveryMode {
                autosaveOpenEditors()
                try projectManager.saveManifest()
            }
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let timestamp = Self.exportTimestampFormatter.string(from: Date())
            let filename = "\(normalizedFileStem(baseName))-\(timestamp).\(fileExtension(for: format))"
            let outputURL = outputDirectory.appendingPathComponent(filename)
            switch format {
            case .docx:
                let html = try compiledProjectText(format: .html, preset: preset)
                let data = try docxData(fromHTML: html)
                try data.write(to: outputURL, options: .atomic)
            case .pdf:
                let html = try compiledProjectText(format: .html, preset: preset)
                let data = try pdfData(fromHTML: html, preset: preset)
                try data.write(to: outputURL, options: .atomic)
            case .epub:
                try writeEPUB(to: outputURL, preset: preset)
            default:
                let content = try compiledProjectText(format: format, preset: preset)
                try content.write(to: outputURL, atomically: true, encoding: .utf8)
            }
            return "Exported \(format.rawValue.uppercased()) to \(outputURL.lastPathComponent)."
        } catch {
            return "Could not export project: \(error.localizedDescription)"
        }
    }

    private func nextAvailableRecoveredProjectName(baseName: String, in parentURL: URL) -> String {
        let base = normalizeTitle(baseName, fallback: "Recovered Project")
        let initial = "\(base) Recovered"
        var candidate = initial
        var suffix = 2
        while FileManager.default.fileExists(atPath: parentURL.appendingPathComponent(candidate, isDirectory: true).path) {
            candidate = "\(initial) \(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func writeAuxiliaryJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func writeEPUB(to outputURL: URL, preset: CompilePreset?) throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let payloadRoot = tempRoot.appendingPathComponent("payload", isDirectory: true)
        let metaInfURL = payloadRoot.appendingPathComponent("META-INF", isDirectory: true)
        let oebpsURL = payloadRoot.appendingPathComponent("OEBPS", isDirectory: true)
        try fileManager.createDirectory(at: metaInfURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: oebpsURL, withIntermediateDirectories: true)

        defer { try? fileManager.removeItem(at: tempRoot) }

        try "application/epub+zip".write(to: payloadRoot.appendingPathComponent("mimetype"), atomically: true, encoding: .utf8)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """.write(to: metaInfURL.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        let manifest = projectManager.getManifest()
        let chapterEntries = orderedCompileChapters(from: manifest, preset: preset)
        let stylesheet = compiledStylesheetCSS(preset: preset)
        try stylesheet.write(to: oebpsURL.appendingPathComponent("stylesheet.css"), atomically: true, encoding: .utf8)

        var itemRefs: [String] = []
        var manifestItems: [String] = [
            "<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/>",
            "<item id=\"css\" href=\"stylesheet.css\" media-type=\"text/css\"/>"
        ]

        let titlePage = epubTitlePage(preset: preset)
        try titlePage.write(to: oebpsURL.appendingPathComponent("title.xhtml"), atomically: true, encoding: .utf8)
        manifestItems.append("<item id=\"title\" href=\"title.xhtml\" media-type=\"application/xhtml+xml\"/>")
        itemRefs.append("<itemref idref=\"title\"/>")

        let navContent = epubNavigation(chapters: chapterEntries)
        try navContent.write(to: oebpsURL.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)

        for (index, chapter) in chapterEntries.enumerated() {
            let href = "chapter-\(index + 1).xhtml"
            let id = "chapter\(index + 1)"
            try epubChapterPage(chapter: chapter, preset: preset).write(to: oebpsURL.appendingPathComponent(href), atomically: true, encoding: .utf8)
            manifestItems.append("<item id=\"\(id)\" href=\"\(href)\" media-type=\"application/xhtml+xml\"/>")
            itemRefs.append("<itemref idref=\"\(id)\"/>")
        }

        let metadataTitle = htmlEscape(preset?.frontMatter.titlePageContent?.title ?? projectDisplayName)
        let metadataAuthor = htmlEscape(preset?.frontMatter.titlePageContent?.author ?? projectDisplayName)
        let metadataLanguage = htmlEscape(preset?.frontMatter.languageCode ?? "en")
        let metadataPublisher = htmlEscape(preset?.frontMatter.publisherName ?? projectDisplayName)
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" unique-identifier="bookid" xmlns="http://www.idpf.org/2007/opf">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:\(UUID().uuidString)</dc:identifier>
            <dc:title>\(metadataTitle)</dc:title>
            <dc:language>\(metadataLanguage)</dc:language>
            <dc:creator>\(metadataAuthor)</dc:creator>
            <dc:publisher>\(metadataPublisher)</dc:publisher>
          </metadata>
          <manifest>
            \(manifestItems.joined(separator: "\n            "))
          </manifest>
          <spine>
            \(itemRefs.joined(separator: "\n            "))
          </spine>
        </package>
        """
        try opf.write(to: oebpsURL.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        try zipDirectoryContents(at: payloadRoot, to: outputURL)
    }

    private func zipDirectoryContents(at sourceDirectory: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = sourceDirectory
        process.arguments = ["-X", "-r", destinationURL.path, "."]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "zip failed"
            throw ProjectIOError.invalidHierarchy(details: "Could not package EPUB: \(errorText)")
        }
    }

    private func orderedCompileChapters(from manifest: Manifest, preset: CompilePreset?) -> [(chapter: ManifestChapter, scenes: [ManifestScene])] {
        let sceneLookup = Dictionary(uniqueKeysWithValues: manifest.hierarchy.scenes.map { ($0.id, $0) })
        let included = Set(preset?.includedSectionIds ?? manifest.hierarchy.chapters.map(\.id))
        var chapters = manifest.hierarchy.chapters
            .filter { included.contains($0.id) }
            .sorted { $0.sequenceIndex < $1.sequenceIndex }
        switch preset?.backMatter.sectionOrder ?? .manuscript {
        case .manuscript:
            break
        case .reverse:
            chapters.reverse()
        case .alphabetical:
            chapters.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return chapters.map { chapter in
            let scenes = chapter.scenes.compactMap { sceneLookup[$0] }
            return (chapter, scenes)
        }
    }

    private func compiledStylesheetCSS(preset: CompilePreset?) -> String {
        let theme = htmlThemeCSS(preset?.styleOverrides.htmlTheme ?? .parchment)
        let template = compileTemplateCSS(preset?.styleOverrides.templateStyle ?? .classic)
        let custom = preset?.styleOverrides.customCSS?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stylesheetName = preset?.styleOverrides.stylesheetName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let presetComment = stylesheetName.isEmpty ? "" : "/* Stylesheet: \(stylesheetName) */\n"
        return """
        \(presetComment)\(theme)
        \(template)
        body { margin: 0; padding: 0 5vw 5vh; font-family: "\(preset?.styleOverrides.fontFamily ?? "Menlo")", serif; line-height: \(preset?.styleOverrides.lineSpacing ?? 1.6); color: var(--ink); background: var(--paper); }
        main { max-width: 48rem; margin: 0 auto; }
        section { padding: 1.2rem 0; border-bottom: 1px solid var(--rule); }
        h1, h2, h3 { color: var(--ink); }
        .scene-synopsis, .chapter-synopsis, .meta { color: var(--muted); }
        \(custom)
        """
    }

    private func epubTitlePage(preset: CompilePreset?) -> String {
        let title = htmlEscape(preset?.frontMatter.titlePageContent?.title ?? projectDisplayName)
        let subtitle = htmlEscape(preset?.frontMatter.titlePageContent?.subtitle ?? "")
        let author = htmlEscape(preset?.frontMatter.titlePageContent?.author ?? projectDisplayName)
        return epubDocument(
            title: title,
            body: """
            <section class="title-page">
              <h1>\(title)</h1>
              \(subtitle.isEmpty ? "" : "<p class=\"meta\">\(subtitle)</p>")
              <p class="meta">by \(author)</p>
            </section>
            """
        )
    }

    private func epubNavigation(chapters: [(chapter: ManifestChapter, scenes: [ManifestScene])]) -> String {
        let items = chapters.enumerated().map { index, entry in
            "<li><a href=\"chapter-\(index + 1).xhtml\">\(htmlEscape(entry.chapter.title))</a></li>"
        }.joined()
        return epubDocument(
            title: "Contents",
            body: """
            <nav epub:type="toc" id="toc">
              <h1>Contents</h1>
              <ol>\(items)</ol>
            </nav>
            """
        )
    }

    private func epubChapterPage(chapter: (chapter: ManifestChapter, scenes: [ManifestScene]), preset: CompilePreset?) -> String {
        let sceneSections = chapter.scenes.map { scene in
            """
            <section class="scene">
              <h3>\(htmlEscape(scene.title))</h3>
              \(scene.synopsis.isEmpty ? "" : "<p class=\"scene-synopsis\">\(htmlEscape(scene.synopsis))</p>")
              \(htmlParagraphs(from: currentContentForScene(scene.id)))
            </section>
            """
        }.joined(separator: "\n")
        return epubDocument(
            title: chapter.chapter.title,
            body: """
            <section class="chapter">
              <h2>\(htmlEscape(chapter.chapter.title))</h2>
              \(chapter.chapter.synopsis.isEmpty ? "" : "<p class=\"chapter-synopsis\">\(htmlEscape(chapter.chapter.synopsis))</p>")
              \(sceneSections)
            </section>
            """
        )
    }

    private func epubDocument(title: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <head>
            <title>\(title)</title>
            <link rel="stylesheet" type="text/css" href="stylesheet.css"/>
          </head>
          <body>
            <main>
              \(body)
            </main>
          </body>
        </html>
        """
    }

    private func compiledProjectText(format: ExportFormat, preset: CompilePreset? = nil) throws -> String {
        let manifest = projectManager.getManifest()
        let scenesByID = Dictionary(uniqueKeysWithValues: manifest.hierarchy.scenes.map { ($0.id, $0) })
        var orderedChapters = manifest.hierarchy.chapters.sorted { lhs, rhs in
            if lhs.sequenceIndex == rhs.sequenceIndex {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.sequenceIndex < rhs.sequenceIndex
        }
        if let preset, !preset.includedSectionIds.isEmpty {
            let included = Set(preset.includedSectionIds)
            orderedChapters = orderedChapters.filter { included.contains($0.id) || $0.parentPartId.map(included.contains) == true }
        }
        if let preset {
            switch preset.backMatter.sectionOrder {
            case .reverse:
                orderedChapters.reverse()
            case .alphabetical:
                orderedChapters.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .manuscript:
                break
            }
        }

        switch format {
        case .markdown, .docx:
            var sections: [String] = []
            if preset?.frontMatter.includeTitlePage != false {
                sections.append(markdownTitlePage(from: preset))
            }
            if let copyrightText = preset?.frontMatter.copyrightText,
               preset?.frontMatter.includeCopyright == true,
               !copyrightText.isEmpty {
                sections.append("## Copyright\n\(copyrightText)")
            }
            if let dedication = preset?.frontMatter.dedicationText, !dedication.isEmpty {
                sections.append("## Dedication\n\(dedication)")
            }
            if preset?.frontMatter.includeTableOfContents == true {
                sections.append("## Table of Contents\n" + orderedChapters.enumerated().map { offset, chapter in
                    "\(offset + 1). \(chapter.title)"
                }.joined(separator: "\n"))
            }
            for chapter in orderedChapters {
                let chapterPrefix = preset?.styleOverrides.chapterHeadingStyle == "h1" ? "# " : "## "
                sections.append("\(chapterPrefix)\(chapter.title)")
                if !chapter.synopsis.isEmpty {
                    sections.append("> \(chapter.synopsis)")
                }
                for sceneID in chapter.scenes {
                    guard let scene = scenesByID[sceneID] else { continue }
                    sections.append("### \(scene.title)")
                    if !scene.synopsis.isEmpty {
                        sections.append("_\(scene.synopsis)_")
                    }
                    sections.append(try projectManager.loadSceneContent(sceneId: scene.id))
                    if let marker = preset?.styleOverrides.sceneBreakMarker, !marker.isEmpty {
                        sections.append(marker)
                    }
                }
            }
            if let aboutAuthor = preset?.backMatter.aboutAuthorText,
               preset?.backMatter.includeAboutAuthor == true,
               !aboutAuthor.isEmpty {
                sections.append("## About the Author\n\(aboutAuthor)")
            }
            if let bibliography = preset?.backMatter.bibliographyText,
               preset?.backMatter.includeBibliography == true,
               !bibliography.isEmpty {
                sections.append("## Bibliography\n\(bibliography)")
            }
            if preset?.backMatter.includeAppendices == true {
                for appendix in preset?.backMatter.appendices ?? [] {
                    sections.append("## \(appendix.title)\n\(appendix.content)")
                }
            }
            if (preset?.frontMatter.includeStagingArea == true || preset == nil), !manifest.hierarchy.stagingScenes.isEmpty {
                sections.append("## Staging Area")
                for sceneID in manifest.hierarchy.stagingScenes {
                    guard let scene = scenesByID[sceneID] else { continue }
                    sections.append("### \(scene.title)")
                    sections.append(try projectManager.loadSceneContent(sceneId: scene.id))
                }
            }
            if format == .docx {
                sections.insert("<!-- DOCX groundwork source generated from compile preset -->", at: 0)
            }
            return sections.joined(separator: "\n\n")
        case .html, .pdf:
            let fontFamily = preset?.styleOverrides.fontFamily ?? "Menlo"
            let fontSize = preset?.styleOverrides.fontSize ?? 14
            let lineSpacing = preset?.styleOverrides.lineSpacing ?? 1.6
            let paragraphIndent = preset?.styleOverrides.paragraphIndent ?? 0
            let pageMargins = preset?.styleOverrides.pageMargins ?? Margins(top: 1, bottom: 1, left: 1, right: 1)
            let pageSize = preset?.styleOverrides.pageSize ?? .letter
            let templateStyle = preset?.styleOverrides.templateStyle ?? .classic
            let titlePage = preset?.frontMatter.includeTitlePage != false ? htmlTitlePage(from: preset) : ""
            let theme = preset?.styleOverrides.htmlTheme ?? .parchment
            let htmlThemeVariables = htmlThemeCSS(theme)
            let templateStyleCSS = compileTemplateCSS(templateStyle)
            let cssPageSize = cssPageSizeName(pageSize)
            let copyrightSection: String
            if let copyrightText = preset?.frontMatter.copyrightText,
               preset?.frontMatter.includeCopyright == true,
               !copyrightText.isEmpty {
                copyrightSection = """
                <section class="frontmatter copyright">
                <h2>Copyright</h2>
                \(htmlParagraphs(from: copyrightText))
                </section>
                """
            } else {
                copyrightSection = ""
            }
            let dedicationSection: String
            if let dedication = preset?.frontMatter.dedicationText, !dedication.isEmpty {
                dedicationSection = """
                <section class="frontmatter dedication">
                <h2>Dedication</h2>
                \(htmlParagraphs(from: dedication))
                </section>
                """
            } else {
                dedicationSection = ""
            }
            let tocSection: String
            if preset?.frontMatter.includeTableOfContents == true {
                let items = orderedChapters.map { "<li>\(htmlEscape($0.title))</li>" }.joined()
                tocSection = """
                <nav class="toc">
                <h2>Table of Contents</h2>
                <ol>\(items)</ol>
                </nav>
                """
            } else {
                tocSection = ""
            }
            let chapterHTML = orderedChapters.map { chapter -> String in
                let sceneHTML = chapter.scenes.compactMap { sceneID -> String? in
                    guard let scene = scenesByID[sceneID] else { return nil }
                    let markerHTML: String
                    if let marker = preset?.styleOverrides.sceneBreakMarker, !marker.isEmpty {
                        markerHTML = "<div class=\"scene-break\">\(htmlEscape(marker))</div>"
                    } else {
                        markerHTML = ""
                    }
                    return """
                    <section class="scene">
                    <h3>\(htmlEscape(scene.title))</h3>
                    \(scene.synopsis.isEmpty ? "" : "<p class=\"scene-synopsis\">\(htmlEscape(scene.synopsis))</p>")
                    \(htmlParagraphs(from: try! projectManager.loadSceneContent(sceneId: scene.id)))
                    \(markerHTML)
                    </section>
                    """
                }.joined(separator: "\n")
                return """
                <section class="chapter">
                <h2>\(htmlEscape(chapter.title))</h2>
                \(chapter.synopsis.isEmpty ? "" : "<p class=\"chapter-synopsis\">\(htmlEscape(chapter.synopsis))</p>")
                \(sceneHTML)
                </section>
                """
            }.joined(separator: "\n")
            let aboutAuthorSection: String
            if let aboutAuthor = preset?.backMatter.aboutAuthorText,
               preset?.backMatter.includeAboutAuthor == true,
               !aboutAuthor.isEmpty {
                aboutAuthorSection = """
                <section class="backmatter about-author">
                <h2>About the Author</h2>
                \(htmlParagraphs(from: aboutAuthor))
                </section>
                """
            } else {
                aboutAuthorSection = ""
            }
            let bibliographySection: String
            if let bibliography = preset?.backMatter.bibliographyText,
               preset?.backMatter.includeBibliography == true,
               !bibliography.isEmpty {
                bibliographySection = """
                <section class="backmatter bibliography">
                <h2>Bibliography</h2>
                \(htmlParagraphs(from: bibliography))
                </section>
                """
            } else {
                bibliographySection = ""
            }
            let appendicesHTML = (preset?.backMatter.includeAppendices == true ? (preset?.backMatter.appendices ?? []) : []).map { appendix in
                """
                <section class="backmatter appendix">
                <h2>\(htmlEscape(appendix.title))</h2>
                \(htmlParagraphs(from: appendix.content))
                </section>
                """
            }.joined(separator: "\n")
            let stagingHTML: String
            if (preset?.frontMatter.includeStagingArea == true || preset == nil), !manifest.hierarchy.stagingScenes.isEmpty {
                let stagingScenes = manifest.hierarchy.stagingScenes.compactMap { scenesByID[$0] }.map { scene in
                    """
                    <section class="scene">
                    <h3>\(htmlEscape(scene.title))</h3>
                    \(htmlParagraphs(from: (try? projectManager.loadSceneContent(sceneId: scene.id)) ?? ""))
                    </section>
                    """
                }.joined(separator: "\n")
                stagingHTML = """
                <section class="chapter staging">
                <h2>Staging Area</h2>
                \(stagingScenes)
                </section>
                """
            } else {
                stagingHTML = ""
            }
            let exporterComment = format == .pdf ? "<!-- PDF export HTML generated from compile preset -->" : ""
            return """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(projectDisplayName)</title>
            <style>
            \(htmlThemeVariables)
            \(templateStyleCSS)
            @page {
              size: \(cssPageSize);
              margin: \(pageMargins.top)in \(pageMargins.right)in \(pageMargins.bottom)in \(pageMargins.left)in;
            }
            body {
              margin: 0;
              padding: \(max(24, Int(pageMargins.top * 48)))px \(max(20, Int(pageMargins.right * 36)))px \(max(32, Int(pageMargins.bottom * 48)))px;
              font-family: "\(fontFamily)", ui-monospace, monospace;
              font-size: \(fontSize)px;
              line-height: \(lineSpacing);
              color: var(--ink);
              background:
                radial-gradient(circle at top left, #fff8ef 0, transparent 32%),
                linear-gradient(180deg, #f2ebdf 0%, var(--paper) 45%, #efe7d8 100%);
            }
            main {
              max-width: 860px;
              margin: 0 auto;
              background: var(--panel);
              border: 1px solid var(--rule);
              border-radius: 18px;
              box-shadow: 0 24px 60px rgba(61, 46, 28, 0.12);
              overflow: hidden;
              backdrop-filter: blur(10px);
            }
            .frontmatter,
            .backmatter,
            .chapter,
            .toc {
              padding: 28px 42px;
              border-bottom: 1px solid var(--rule);
            }
            .title-page {
              padding: 72px 42px 56px;
              text-align: center;
              background: linear-gradient(180deg, rgba(255,255,255,0.55), rgba(255,255,255,0.86));
            }
            h1, h2, h3 {
              font-weight: 700;
              letter-spacing: 0.01em;
              margin: 0 0 12px;
            }
            h1 {
              font-size: 2.2em;
            }
            h2 {
              font-size: 1.3em;
            }
            h3 {
              font-size: 1.05em;
              color: var(--muted);
            }
            p {
              margin: 0 0 1em;
              text-indent: \(paragraphIndent)em;
            }
            .chapter-synopsis,
            .scene-synopsis,
            .title-subtitle,
            .title-author {
              color: var(--muted);
              text-indent: 0;
            }
            .scene {
              padding-top: 18px;
            }
            .scene-break {
              margin: 22px auto 0;
              width: fit-content;
              color: var(--muted);
              letter-spacing: 0.22em;
              text-transform: uppercase;
            }
            ol {
              margin: 0;
              padding-left: 1.5em;
            }
            </style>
            </head>
            <body>
            \(exporterComment)
            <main>
            \(titlePage)
            \(copyrightSection)
            \(dedicationSection)
            \(tocSection)
            \(chapterHTML)
            \(stagingHTML)
            \(aboutAuthorSection)
            \(bibliographySection)
            \(appendicesHTML)
            </main>
            </body>
            </html>
            """
        default:
            throw ProjectIOError.invalidHierarchy(details: "Unsupported export format \(format.rawValue)")
        }
    }

    private func markdownTitlePage(from preset: CompilePreset?) -> String {
        let titlePage = preset?.frontMatter.titlePageContent
        let subtitle = titlePage?.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = ["# \(titlePage?.title ?? projectDisplayName)"]
        if let subtitle, !subtitle.isEmpty {
            lines.append("_\(subtitle)_")
        }
        let author = titlePage?.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if let author, !author.isEmpty {
            lines.append("by \(author)")
        }
        return lines.joined(separator: "\n\n")
    }

    private func htmlTitlePage(from preset: CompilePreset?) -> String {
        let titlePage = preset?.frontMatter.titlePageContent
        let title = htmlEscape(titlePage?.title ?? projectDisplayName)
        let subtitle = titlePage?.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let author = titlePage?.author.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return """
        <section class="title-page">
        <h1>\(title)</h1>
        \(subtitle.isEmpty ? "" : "<p class=\"title-subtitle\">\(htmlEscape(subtitle))</p>")
        \(author.isEmpty ? "" : "<p class=\"title-author\">by \(htmlEscape(author))</p>")
        </section>
        """
    }

    private func htmlThemeCSS(_ theme: CompileHTMLTheme) -> String {
        switch theme {
        case .parchment:
            return """
            :root {
              --paper: #f7f2e8;
              --ink: #1d1d1f;
              --muted: #6d675f;
              --rule: #d9cfbe;
              --panel: rgba(255, 255, 255, 0.72);
            }
            """
        case .midnight:
            return """
            :root {
              --paper: #0f1720;
              --ink: #eef2f7;
              --muted: #93a3b8;
              --rule: #243246;
              --panel: rgba(12, 18, 28, 0.88);
            }
            """
        case .editorial:
            return """
            :root {
              --paper: #eef0f3;
              --ink: #1b2430;
              --muted: #5f6b7a;
              --rule: #c7d0db;
              --panel: rgba(255, 255, 255, 0.86);
            }
            """
        }
    }

    private func compileTemplateCSS(_ style: CompileTemplateStyle) -> String {
        switch style {
        case .classic:
            return """
            main {
              border-radius: 18px;
            }
            .chapter h2 {
              border-bottom: 1px solid var(--rule);
              padding-bottom: 8px;
            }
            """
        case .modern:
            return """
            main {
              border-radius: 0;
              box-shadow: none;
            }
            .title-page {
              border-bottom: 6px solid var(--rule);
            }
            .scene-break {
              font-weight: 700;
            }
            """
        case .manuscript:
            return """
            main {
              border-radius: 8px;
              box-shadow: 0 12px 28px rgba(61, 46, 28, 0.08);
            }
            .frontmatter,
            .backmatter,
            .chapter,
            .toc {
              padding-left: 54px;
              padding-right: 54px;
            }
            p {
              max-width: 70ch;
            }
            """
        }
    }

    private func cssPageSizeName(_ pageSize: CompilePageSize) -> String {
        switch pageSize {
        case .letter:
            return "Letter"
        case .a4:
            return "A4"
        case .trade:
            return "6in 9in"
        }
    }

    private func docxData(fromHTML html: String) throws -> Data {
        let attributed = try attributedString(fromHTML: html)
        return try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
        )
    }

    private func pdfData(fromHTML html: String, preset: CompilePreset?) throws -> Data {
        let attributed = try attributedString(fromHTML: html)
        let pageSize = preset?.styleOverrides.pageSize ?? .letter
        let margins = preset?.styleOverrides.pageMargins ?? Margins(top: 1, bottom: 1, left: 1, right: 1)
        let dimensions = pdfPageDimensions(for: pageSize)
        let pageWidth = dimensions.width
        let pageHeight = dimensions.height
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: margins.left * 36, height: margins.top * 36)
        textView.textStorage?.setAttributedString(attributed)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let usedRect = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? textView.bounds
        let verticalPadding = (margins.top + margins.bottom) * 36
        textView.frame = NSRect(x: 0, y: 0, width: pageWidth, height: max(pageHeight, usedRect.height + verticalPadding))
        return textView.dataWithPDF(inside: textView.bounds)
    }

    private func pdfPageDimensions(for pageSize: CompilePageSize) -> CGSize {
        switch pageSize {
        case .letter:
            return CGSize(width: 612, height: 792)
        case .a4:
            return CGSize(width: 595, height: 842)
        case .trade:
            return CGSize(width: 432, height: 648)
        }
    }

    private func attributedString(fromHTML html: String) throws -> NSAttributedString {
        let data = Data(html.utf8)
        return try NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    private func htmlParagraphs(from text: String) -> String {
        text
            .components(separatedBy: "\n\n")
            .map { paragraph in
                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let lineBroken = trimmed
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { htmlEscape(String($0)) }
                    .joined(separator: "<br>")
                return "<p>\(lineBroken)</p>"
            }
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private func htmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func compilePresetDraft(
        id: UUID,
        name: String,
        format: ExportFormat,
        includedSectionIds: [UUID],
        fontFamily: String,
        fontSize: Int,
        lineSpacing: Double,
        chapterHeadingStyle: String,
        sceneBreakMarker: String,
        htmlTheme: CompileHTMLTheme,
        pageSize: CompilePageSize,
        templateStyle: CompileTemplateStyle,
        pageMargins: Margins,
        subtitle: String,
        authorName: String,
        includeTitlePage: Bool,
        includeTableOfContents: Bool,
        includeStagingArea: Bool,
        languageCode: String,
        publisherName: String,
        copyrightText: String,
        dedicationText: String,
        includeAboutAuthor: Bool,
        aboutAuthorText: String,
        sectionOrder: CompileSectionOrder,
        bibliographyText: String,
        appendixTitle: String,
        appendixContent: String,
        stylesheetName: String,
        customCSS: String
    ) -> CompilePreset {
        let normalizedSubtitle = normalizeTitle(subtitle, fallback: "")
        let normalizedAuthor = normalizeTitle(authorName, fallback: projectDisplayName)
        let normalizedCopyright = copyrightText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDedication = dedicationText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBibliography = bibliographyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAppendixTitle = normalizeTitle(appendixTitle, fallback: "")
        let normalizedAppendixContent = appendixContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLanguageCode = normalizeTitle(languageCode, fallback: "en")
        let normalizedPublisherName = normalizeTitle(publisherName, fallback: "")
        let normalizedMargins = Margins(
            top: max(0.25, min(pageMargins.top, 3)),
            bottom: max(0.25, min(pageMargins.bottom, 3)),
            left: max(0.25, min(pageMargins.left, 3)),
            right: max(0.25, min(pageMargins.right, 3))
        )
        return CompilePreset(
            id: id,
            name: name,
            format: format,
            includedSectionIds: includedSectionIds,
            styleOverrides: StyleConfig(
                fontFamily: normalizeTitle(fontFamily, fallback: "Menlo"),
                fontSize: max(8, fontSize),
                lineSpacing: max(1.0, min(lineSpacing, 3.0)),
                paragraphIndent: 0,
                chapterHeadingStyle: normalizeTitle(chapterHeadingStyle, fallback: "h2"),
                sceneBreakMarker: sceneBreakMarker,
                htmlTheme: htmlTheme,
                pageSize: pageSize,
                templateStyle: templateStyle,
                pageMargins: normalizedMargins,
                stylesheetName: normalizedOptionalText(stylesheetName),
                customCSS: customCSS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customCSS
            ),
            frontMatter: FrontMatterConfig(
                includeTitlePage: includeTitlePage,
                includeCopyright: !normalizedCopyright.isEmpty,
                includeDedication: !normalizedDedication.isEmpty,
                includeTableOfContents: includeTableOfContents,
                includeStagingArea: includeStagingArea,
                languageCode: normalizedLanguageCode,
                publisherName: normalizedPublisherName.isEmpty ? nil : normalizedPublisherName,
                titlePageContent: TitlePageContent(
                    title: projectDisplayName,
                    subtitle: normalizedSubtitle.isEmpty ? nil : normalizedSubtitle,
                    author: normalizedAuthor
                ),
                copyrightText: normalizedCopyright.isEmpty ? nil : normalizedCopyright,
                dedicationText: normalizedDedication.isEmpty ? nil : normalizedDedication
            ),
            backMatter: BackMatterConfig(
                includeAppendices: !normalizedAppendixTitle.isEmpty && !normalizedAppendixContent.isEmpty,
                includeAboutAuthor: includeAboutAuthor,
                includeBibliography: !normalizedBibliography.isEmpty,
                sectionOrder: sectionOrder,
                aboutAuthorText: aboutAuthorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : aboutAuthorText,
                bibliographyText: normalizedBibliography.isEmpty ? nil : normalizedBibliography,
                appendices: normalizedAppendixTitle.isEmpty || normalizedAppendixContent.isEmpty ? [] : [
                    AppendixEntry(title: normalizedAppendixTitle, content: normalizedAppendixContent)
                ]
            )
        )
    }

    private func resolveImportTargetChapter() throws -> UUID {
        if let selectedChapterID = navigationState.selectedChapterId, chapterExists(selectedChapterID) {
            return selectedChapterID
        }
        if let chapterID = inspectorChapter?.id {
            return chapterID
        }
        if let firstChapterID = searchableChapters.first?.id {
            return firstChapterID
        }
        let created = try projectManager.addChapter(to: nil, at: nil, title: "Imported")
        refreshDerivedStates()
        return created.id
    }

    private func parseImportedScenes(from text: String, sourceName: String) -> [(title: String, synopsis: String, content: String)] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let headingPattern = try? NSRegularExpression(pattern: "(?m)^##+\\s+(.+)$")
        if let headingPattern {
            let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            let matches = headingPattern.matches(in: normalized, range: nsRange)
            if !matches.isEmpty {
                return matches.enumerated().compactMap { index, match in
                    guard let titleRange = Range(match.range(at: 1), in: normalized),
                          let contentStart = Range(match.range, in: normalized)?.upperBound else {
                        return nil
                    }
                    let contentEnd: String.Index
                    if index + 1 < matches.count, let nextStart = Range(matches[index + 1].range, in: normalized)?.lowerBound {
                        contentEnd = nextStart
                    } else {
                        contentEnd = normalized.endIndex
                    }
                    let title = normalizeTitle(String(normalized[titleRange]), fallback: "Imported Scene")
                    let content = String(normalized[contentStart..<contentEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                    return (title, "", content)
                }
                .filter { !$0.content.isEmpty }
            }
        }

        let dividerScenes = normalized
            .components(separatedBy: "\n---\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if dividerScenes.count > 1 {
            return dividerScenes.enumerated().map { index, content in
                ("\(sourceName) Scene \(index + 1)", "", content)
            }
        }

        let singleContent = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !singleContent.isEmpty else { return [] }
        return [(normalizeTitle(sourceName, fallback: "Imported Scene"), "", singleContent)]
    }

    private func projectOpenFailureMessage(for error: Error) -> String {
        switch error {
        case ProjectIOError.concurrentAccess:
            return "Could not open project: It is already open in another Scribbles-N-Scripts window or process."
        case ProjectIOError.corruptManifest:
            return "Could not open project normally. You can open a read-only recovery copy from this window."
        case ProjectIOError.fileMoved:
            return "Could not open project: The selected project folder is no longer available where Scribbles-N-Scripts last saw it."
        default:
            return "Could not open project: \(error.localizedDescription)"
        }
    }

    private func nextGeneratedChapterTitle() -> String {
        nextGeneratedTitle(
            existingTitles: projectManager.getManifest().hierarchy.chapters.map(\.title),
            parsePrefix: "chapter",
            displayPrefix: "Chapter"
        )
    }

    private func nextGeneratedSceneTitle() -> String {
        nextGeneratedTitle(
            existingTitles: projectManager.getManifest().hierarchy.scenes.map(\.title),
            parsePrefix: "scene",
            displayPrefix: "Scene"
        )
    }

    private func nextDuplicateSceneTitle(for title: String) -> String {
        let existingTitles = Set(projectManager.getManifest().hierarchy.scenes.map(\.title))
        let base = "\(title) Copy"
        guard existingTitles.contains(base) else {
            return base
        }
        var candidate = 2
        while existingTitles.contains("\(base) \(candidate)") {
            candidate += 1
        }
        return "\(base) \(candidate)"
    }

    private func nextGeneratedTitle(existingTitles: [String], parsePrefix: String, displayPrefix: String) -> String {
        let usedNumbers = Set(
            existingTitles.compactMap { title -> Int? in
                parseGeneratedNumber(from: title, prefix: parsePrefix)
            }
        )

        var candidate = 1
        while usedNumbers.contains(candidate) {
            candidate += 1
        }
        return "\(displayPrefix) \(candidate)"
    }

    private func parseGeneratedNumber(from title: String, prefix: String) -> Int? {
        let normalized = title
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        guard lowercased.hasPrefix(prefix) else {
            return nil
        }
        let suffix = normalized.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !suffix.isEmpty, suffix.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains) else {
            return nil
        }
        return Int(suffix)
    }
}
