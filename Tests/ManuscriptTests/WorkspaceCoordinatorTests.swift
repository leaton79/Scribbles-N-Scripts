import SwiftUI
import XCTest
@testable import ScribblesNScripts

@MainActor
final class WorkspaceCoordinatorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: "workspace.searchHighlightCap")
        UserDefaults.standard.removeObject(forKey: "workspace.searchHighlightSafetyThreshold")
        UserDefaults.standard.removeObject(forKey: "workspace.replaceSceneSelectionMode")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testHandleScenePhaseActiveStartsSessionAndTimer() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Lifecycle")

        coordinator.handleScenePhase(.active)

        XCTAssertNotNil(coordinator.goalsManager.sessionStartTime)
        XCTAssertTrue(coordinator.goalsManager.isTimerRunning)
    }

    func testHandleScenePhaseInactiveAutosavesDirtyEditor() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Autosave")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("Hello ", at: 0)

        coordinator.handleScenePhase(.inactive)

        let content = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(content, "Hello ")
        XCTAssertFalse(coordinator.goalsManager.isTimerRunning)
    }

    func testSidebarSelectionTargetsSecondaryPaneWhenActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitSelect")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId

        coordinator.select(
            node: SidebarNode(
                id: existingSceneId,
                title: "First",
                level: .scene,
                wordCount: 0,
                colorLabel: nil,
                goalProgressText: nil,
                children: [],
                matchingCount: nil
            )
        )

        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
    }

    func testSidebarSelectionTargetsPrimaryPaneWhenPrimaryIsActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitSelectPrimary")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(0)
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

        coordinator.select(
            node: SidebarNode(
                id: existingSceneId,
                title: "First",
                level: .scene,
                wordCount: 0,
                colorLabel: nil,
                goalProgressText: nil,
                children: [],
                matchingCount: nil
            )
        )

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }

    func testBreadcrumbSelectionTargetsSecondaryPaneWhenActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitBreadcrumbSelect")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId

        coordinator.select(breadcrumb: BreadcrumbItem(id: existingSceneId, title: "First", type: .scene))

        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
    }

    func testBreadcrumbSelectionTargetsPrimaryPaneWhenPrimaryIsActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitBreadcrumbSelectPrimary")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(0)
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

        coordinator.select(breadcrumb: BreadcrumbItem(id: existingSceneId, title: "First", type: .scene))

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }

    func testCreateSceneTargetsSecondaryPaneWhenActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitCreateScene")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene(title: "Split Created")

        XCTAssertNil(message)
        let updatedManifest = coordinator.projectManager.getManifest()
        let createdScene = try XCTUnwrap(updatedManifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(createdScene.title, "Split Created")
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, createdScene.id)
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
    }

    func testCreateSceneTargetsPrimaryPaneWhenPrimaryIsActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitCreateScenePrimary")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(0)
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene(title: "Split Created Primary")

        XCTAssertNil(message)
        let updatedManifest = coordinator.projectManager.getManifest()
        let createdScene = try XCTUnwrap(updatedManifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(createdScene.title, "Split Created Primary")
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, createdScene.id)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }

    func testBackgroundPhasePersistsDirtyManifestToDisk() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackgroundSave")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let beforeCount = coordinator.projectManager.getManifest().hierarchy.scenes.count

        _ = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Unsaved Scene")
        coordinator.handleScenePhase(.background)

        let root = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let diskManifest = try ManifestCoder.read(from: root.appendingPathComponent("manifest.json"))
        XCTAssertEqual(diskManifest.hierarchy.scenes.count, beforeCount + 1)
    }

    func testBootstrapReopensExistingProjectData() throws {
        let projectName = "Reopen"
        var first: WorkspaceCoordinator? = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: projectName)
        let chapterId = try XCTUnwrap(first?.projectManager.getManifest().hierarchy.chapters.first?.id)
        _ = try first?.projectManager.addScene(to: chapterId, at: nil, title: "Persisted Scene")
        try first?.projectManager.saveManifest()
        try first?.projectManager.closeProject()
        first = nil

        let second = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: projectName)
        let titles = second.projectManager.getManifest().hierarchy.scenes.map(\.title)
        XCTAssertTrue(titles.contains("Persisted Scene"))
    }

    func testCreateWriteSaveCloseAndReopenLastProjectWorkflow() throws {
        let suiteName = "WorkspaceCoordinatorTests.Recent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "WorkflowSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "WorkflowMain"))
        let workflowRoot = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)

        coordinator.editorState.insertText("workflow text", at: 0)
        XCTAssertNil(coordinator.saveProjectNow())

        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.hasOpenProject)

        XCTAssertNil(coordinator.reopenLastProject())
        XCTAssertEqual(coordinator.projectManager.projectRootURL, workflowRoot)
        let reopenedContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(reopenedContent, "workflow text")
    }

    func testOpenProjectSwitchesToSelectedProjectAndUpdatesRecentEntry() throws {
        let suiteName = "WorkspaceCoordinatorTests.OpenRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let seed = FileSystemProjectManager()
        _ = try seed.createProject(name: "TargetOpen", at: tempDir)
        try seed.closeProject()

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "CurrentProject",
            recentProjectStore: defaults
        )
        let targetURL = tempDir.appendingPathComponent("TargetOpen", isDirectory: true)

        XCTAssertNil(coordinator.openProject(at: targetURL))
        XCTAssertEqual(coordinator.projectManager.projectRootURL, targetURL)
        XCTAssertEqual(coordinator.projectDisplayName, "TargetOpen")

        try coordinator.projectManager.closeProject()
        XCTAssertNil(coordinator.reopenLastProject())
        XCTAssertEqual(coordinator.projectManager.projectRootURL, targetURL)
    }

    func testCorruptProjectCanOpenInRecoveryMode() throws {
        let creator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RecoverySeed")
        let rootURL = try XCTUnwrap(creator.projectManager.projectRootURL)
        try creator.projectManager.closeProject()
        try FileManager.default.removeItem(at: rootURL.appendingPathComponent("manifest.json"))

        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RecoverySeed")
        XCTAssertNotNil(coordinator.recoveryCandidateURL)
        XCTAssertFalse(coordinator.hasOpenProject)

        let notice = coordinator.openRecoveryModeForFailedProject()
        XCTAssertTrue(notice?.contains("recovery mode") == true)
        XCTAssertTrue(coordinator.hasOpenProject)
        XCTAssertTrue(coordinator.isRecoveryMode)
        XCTAssertFalse(coordinator.editorState.isEditable)
    }

    func testRecoveryModeSurfacesDiagnosticsAndSafeSalvageActions() throws {
        let creator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RecoveryActions")
        let rootURL = try XCTUnwrap(creator.projectManager.projectRootURL)
        let chapterFolder = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: rootURL.appendingPathComponent("content", isDirectory: true),
                includingPropertiesForKeys: [.isDirectoryKey]
            ).first(where: { $0.lastPathComponent != "staging" })
        )
        let strayFileURL = chapterFolder.appendingPathComponent("notes.txt")
        try "ignore me".write(to: strayFileURL, atomically: true, encoding: .utf8)
        try creator.projectManager.closeProject()
        try FileManager.default.removeItem(at: rootURL.appendingPathComponent("manifest.json"))

        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RecoveryActions")
        XCTAssertTrue(coordinator.openRecoveryModeForFailedProject()?.contains("recovery mode") == true)
        XCTAssertFalse(coordinator.recoveryDiagnostics.isEmpty)
        XCTAssertTrue(coordinator.recoveryDiagnostics.contains(where: { $0.message.contains("Skipped") }))

        XCTAssertTrue(coordinator.exportRecoveryProject(format: .markdown)?.contains("Exported MARKDOWN") == true)
        let exportFolder = tempDir.appendingPathComponent("RecoveryActions-recovery-exports", isDirectory: true)
        let exportedFiles = try FileManager.default.contentsOfDirectory(at: exportFolder, includingPropertiesForKeys: nil)
        XCTAssertEqual(exportedFiles.filter { $0.pathExtension == "md" }.count, 1)

        XCTAssertTrue(coordinator.duplicateRecoveryProjectAsWritableCopy()?.contains("writable recovery copy") == true)
        XCTAssertFalse(coordinator.isRecoveryMode)
        XCTAssertTrue(coordinator.projectDisplayName.contains("Recovered"))
        let duplicatedRoot = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        XCTAssertNotEqual(duplicatedRoot, rootURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicatedRoot.appendingPathComponent("manifest.json").path))
    }

    func testRecentProjectsTrackMostRecentFirstAndDeduplicate() throws {
        let suiteName = "WorkspaceCoordinatorTests.RecentList.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "RecentSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "RecentA"))
        let recentA = tempDir.appendingPathComponent("RecentA", isDirectory: true)
        XCTAssertNil(coordinator.createAndOpenProject(named: "RecentB"))
        XCTAssertNil(coordinator.openProject(at: recentA))

        let names = coordinator.recentProjects.map(\.name)
        XCTAssertGreaterThanOrEqual(names.count, 2)
        XCTAssertEqual(names[0], "RecentA")
        XCTAssertEqual(names[1], "RecentB")
        XCTAssertEqual(names.filter { $0 == "RecentA" }.count, 1)
    }

    func testInspectorSceneAndChapterReflectCurrentSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "InspectorSelection")

        let scene = try XCTUnwrap(coordinator.inspectorScene)
        let chapter = try XCTUnwrap(coordinator.inspectorChapter)

        XCTAssertEqual(scene.id, coordinator.navigationState.selectedSceneId)
        XCTAssertTrue(chapter.scenes.contains(scene.id))
    }

    func testInspectorEditsTagsMetadataAndChapterGoal() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "InspectorEdits")
        let sceneID = try XCTUnwrap(coordinator.inspectorScene?.id)
        let chapterID = try XCTUnwrap(coordinator.inspectorChapter?.id)

        XCTAssertNil(coordinator.addInspectorMetadataField(named: "POV", type: .singleSelect, options: ["Alice", "Bob"]))
        XCTAssertNil(coordinator.setInspectorSceneMetadata(field: "POV", value: "Alice"))
        XCTAssertNil(coordinator.addInspectorTag(named: "Action"))
        XCTAssertNil(coordinator.setInspectorSceneTitle("Opening Scene"))
        XCTAssertNil(coordinator.setInspectorSceneStatus(.revised))
        XCTAssertNil(coordinator.setInspectorSceneSynopsis("Scene summary"))
        XCTAssertNil(coordinator.setInspectorSceneColorLabel(.blue))
        XCTAssertNil(coordinator.setInspectorChapterTitle("Act One"))
        XCTAssertNil(coordinator.setInspectorChapterStatus(.inProgress))
        XCTAssertNil(coordinator.setInspectorChapterSynopsis("Chapter summary"))
        XCTAssertNil(coordinator.setInspectorChapterGoal(2400))

        let manifest = coordinator.projectManager.getManifest()
        let scene = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.id == sceneID }))
        let chapter = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.id == chapterID }))
        let tag = try XCTUnwrap(coordinator.tagManager.allTags.first(where: { $0.name == "Action" }))

        XCTAssertEqual(scene.metadata["POV"], "Alice")
        XCTAssertEqual(scene.title, "Opening Scene")
        XCTAssertEqual(scene.status, .revised)
        XCTAssertEqual(scene.synopsis, "Scene summary")
        XCTAssertEqual(scene.colorLabel, .blue)
        XCTAssertTrue(scene.tags.contains(tag.id))
        XCTAssertEqual(chapter.title, "Act One")
        XCTAssertEqual(chapter.status, .inProgress)
        XCTAssertEqual(chapter.synopsis, "Chapter summary")
        XCTAssertEqual(chapter.goalWordCount, 2400)
        XCTAssertEqual(coordinator.projectManager.currentProject?.settings.customMetadataFields.map(\.name), ["POV"])
        XCTAssertEqual(coordinator.projectManager.currentProject?.settings.customMetadataFields.first?.options, ["Alice", "Bob"])

        XCTAssertNil(coordinator.removeInspectorTag(tag.id))
        XCTAssertNil(coordinator.deleteInspectorMetadataField(try XCTUnwrap(coordinator.metadataManager.customFields.first?.id)))
        XCTAssertNil(coordinator.setInspectorChapterGoal(nil))

        let updatedManifest = coordinator.projectManager.getManifest()
        let updatedScene = try XCTUnwrap(updatedManifest.hierarchy.scenes.first(where: { $0.id == sceneID }))
        let updatedChapter = try XCTUnwrap(updatedManifest.hierarchy.chapters.first(where: { $0.id == chapterID }))

        XCTAssertFalse(updatedScene.tags.contains(tag.id))
        XCTAssertNil(updatedScene.metadata["POV"])
        XCTAssertNil(updatedChapter.goalWordCount)
    }

    func testProjectSettingsUpdatePersistsEditorAndBackupPreferences() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ProjectSettings")

        XCTAssertNil(
            coordinator.updateProjectSettings(
                autosaveIntervalSeconds: 45,
                backupIntervalMinutes: 60,
                backupRetentionCount: 12,
                editorFont: "Menlo",
                editorFontSize: 16,
                editorLineHeight: 1.8,
                theme: .dark
            )
        )

        let settings = try XCTUnwrap(coordinator.projectSettings)
        XCTAssertEqual(settings.autosaveIntervalSeconds, 45)
        XCTAssertEqual(settings.backupIntervalMinutes, 60)
        XCTAssertEqual(settings.backupRetentionCount, 12)
        XCTAssertEqual(settings.editorFont, "Menlo")
        XCTAssertEqual(settings.editorFontSize, 16)
        XCTAssertEqual(settings.editorLineHeight, 1.8, accuracy: 0.001)
        XCTAssertEqual(settings.theme, .dark)
        XCTAssertEqual(coordinator.editorPresentationSettings.fontName, "Menlo")
        XCTAssertEqual(coordinator.editorPresentationSettings.fontSize, 16, accuracy: 0.001)
        XCTAssertEqual(coordinator.editorPresentationSettings.lineHeight, 1.8, accuracy: 0.001)
        XCTAssertEqual(coordinator.preferredColorScheme, .dark)
    }

    func testExportProjectWritesMarkdownToExportsFolder() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ExportProject")
        let sceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: sceneID, content: "Hello export world")

        let message = coordinator.exportProject(format: .markdown)

        XCTAssertEqual(message?.contains("Exported MARKDOWN"), true)
        let rootURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(at: exportsURL, includingPropertiesForKeys: nil)
        let exportedFile = try XCTUnwrap(contents.first(where: { $0.pathExtension == "md" }))
        let exportedText = try String(contentsOf: exportedFile, encoding: .utf8)
        XCTAssertTrue(exportedText.contains("# ExportProject"))
        XCTAssertTrue(exportedText.contains("Hello export world"))
    }

    func testImportScenesCreatesMultipleScenesFromMarkdownHeadings() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ImportProject")
        let importURL = tempDir.appendingPathComponent("ImportSource.md")
        try """
        ## Arrival
        First imported scene.

        ## Departure
        Second imported scene.
        """.write(to: importURL, atomically: true, encoding: .utf8)

        let beforeCount = coordinator.projectManager.getManifest().hierarchy.scenes.count
        let message = coordinator.importScenes(from: importURL)

        XCTAssertEqual(message, "Imported 2 scene(s) from ImportSource.md.")
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertEqual(manifest.hierarchy.scenes.count, beforeCount + 2)
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Arrival" }))
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Departure" }))
    }

    func testCompilePresetPersistsAndExportsScopedSections() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CompilePreset")
        let chapterA = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let chapterB = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Chapter B")
        let secondScene = try coordinator.projectManager.addScene(to: chapterB.id, at: nil, title: "Second Chapter Scene")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "Chapter B content")

        XCTAssertNil(
            coordinator.saveCompilePreset(
                name: "Subset",
                format: .markdown,
                includedSectionIds: [chapterA],
                fontFamily: "Menlo",
                fontSize: 14,
                lineSpacing: 1.6,
                includeTitlePage: true,
                includeTableOfContents: false
            )
        )
        let preset = try XCTUnwrap(coordinator.compilePresets.first(where: { $0.name == "Subset" }))
        let message = coordinator.exportProject(using: preset.id)

        XCTAssertEqual(message?.contains("Exported MARKDOWN"), true)
        let rootURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(at: exportsURL, includingPropertiesForKeys: nil)
        let exportedFile = try XCTUnwrap(contents.first(where: { $0.pathExtension == "md" && $0.lastPathComponent.contains("Subset") }))
        let exportedText = try String(contentsOf: exportedFile, encoding: .utf8)
        XCTAssertFalse(exportedText.contains("Chapter B"))

        try coordinator.projectManager.closeProject()
        let reopened = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CompilePreset")
        XCTAssertTrue(reopened.compilePresets.contains(where: { $0.name == "Subset" }))
    }

    func testCompilePresetExportsDedicationAndAboutAuthorContent() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CompileFrontBack")
        let chapterA = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)

        XCTAssertNil(
            coordinator.saveCompilePreset(
                name: "FrontBack",
                format: .markdown,
                includedSectionIds: [chapterA],
                fontFamily: "Menlo",
                fontSize: 14,
                lineSpacing: 1.6,
                chapterHeadingStyle: "h1",
                sceneBreakMarker: "~~~",
                includeTitlePage: true,
                includeTableOfContents: true,
                dedicationText: "For the night shift.",
                includeAboutAuthor: true,
                aboutAuthorText: "Written in Boston."
            )
        )

        let preset = try XCTUnwrap(coordinator.compilePresets.first(where: { $0.name == "FrontBack" }))
        let exportMessage = coordinator.exportProject(using: preset.id)
        XCTAssertTrue(exportMessage?.contains("Exported MARKDOWN") == true)
        let rootURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(at: exportsURL, includingPropertiesForKeys: nil)
        let exportedFile = try XCTUnwrap(contents.first(where: { $0.lastPathComponent.contains("FrontBack") }))
        let exportedText = try String(contentsOf: exportedFile, encoding: .utf8)
        XCTAssertTrue(exportedText.contains("Dedication"))
        XCTAssertTrue(exportedText.contains("For the night shift."))
        XCTAssertTrue(exportedText.contains("About the Author"))
        XCTAssertTrue(exportedText.contains("Written in Boston."))
    }

    func testInspectorMetadataSchemaCanRenameReorderAndUpdateOptions() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "InspectorSchema")
        let sceneID = try XCTUnwrap(coordinator.inspectorScene?.id)

        XCTAssertNil(coordinator.addInspectorMetadataField(named: "POV", type: .singleSelect, options: ["Alice", "Bob"]))
        XCTAssertNil(coordinator.addInspectorMetadataField(named: "Location", type: .text, options: []))
        XCTAssertNil(coordinator.setInspectorSceneMetadata(field: "POV", value: "Bob"))

        let povID = try XCTUnwrap(coordinator.metadataManager.customFields.first(where: { $0.name == "POV" })?.id)
        let locationID = try XCTUnwrap(coordinator.metadataManager.customFields.first(where: { $0.name == "Location" })?.id)

        XCTAssertNil(coordinator.renameInspectorMetadataField(povID, to: "Viewpoint"))
        XCTAssertNil(coordinator.moveInspectorMetadataField(locationID, by: -1))
        XCTAssertNil(coordinator.updateInspectorMetadataFieldOptions(povID, options: ["Alice", "Cara"]))

        XCTAssertEqual(coordinator.projectManager.currentProject?.settings.customMetadataFields.map(\.name), ["Location", "Viewpoint"])
        let scene = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID }))
        XCTAssertEqual(scene.metadata["Viewpoint"], "Alice")
        XCTAssertNil(scene.metadata["POV"])
    }

    func testInspectorSupportsTypedMetadataValues() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "TypedInspectorMetadata")
        let sceneID = try XCTUnwrap(coordinator.inspectorScene?.id)

        XCTAssertNil(coordinator.addInspectorMetadataField(named: "Focus", type: .multiSelect, options: ["Plot", "Theme"]))
        XCTAssertNil(coordinator.addInspectorMetadataField(named: "Draft", type: .number, options: []))
        XCTAssertNil(coordinator.addInspectorMetadataField(named: "Due", type: .date, options: []))

        XCTAssertNil(coordinator.setInspectorSceneMetadata(field: "Focus", value: "Plot, Theme"))
        XCTAssertNil(coordinator.setInspectorSceneMetadata(field: "Draft", value: "3"))
        XCTAssertNil(coordinator.setInspectorSceneMetadata(field: "Due", value: "2026-03-10"))
        XCTAssertNotNil(coordinator.setInspectorSceneMetadata(field: "Draft", value: "three"))
        XCTAssertNotNil(coordinator.setInspectorSceneMetadata(field: "Due", value: "03/10/2026"))

        let scene = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID }))
        XCTAssertEqual(scene.metadata["Focus"], "Plot, Theme")
        XCTAssertEqual(scene.metadata["Draft"], "3")
        XCTAssertEqual(scene.metadata["Due"], "2026-03-10")
    }

    func testCreateSceneBelowCurrentInsertsAfterActiveScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SceneBelow")
        let before = coordinator.linearState.orderedSceneIds
        let current = try XCTUnwrap(coordinator.editorState.currentSceneId)

        XCTAssertNil(coordinator.createSceneBelowCurrent(title: "Inserted Below"))

        let after = coordinator.linearState.orderedSceneIds
        let currentIndex = try XCTUnwrap(before.firstIndex(of: current))
        let insertedID = after[currentIndex + 1]
        let insertedScene = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == insertedID }))
        XCTAssertEqual(insertedScene.title, "Inserted Below")
        XCTAssertEqual(coordinator.editorState.currentSceneId, insertedID)
    }

    func testDuplicateSelectedSceneCopiesContentAndMetadataBelowOriginal() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "DuplicateScene")
        let sourceSceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        XCTAssertNil(coordinator.addInspectorMetadataField(named: "POV", type: .singleSelect, options: ["Alice", "Bob"]))
        XCTAssertNil(coordinator.setInspectorSceneMetadata(field: "POV", value: "Bob"))
        XCTAssertNil(coordinator.addInspectorTag(named: "Action"))
        XCTAssertNil(coordinator.setInspectorSceneStatus(.revised))
        XCTAssertNil(coordinator.setInspectorSceneSynopsis("Original synopsis"))
        XCTAssertNil(coordinator.setInspectorSceneColorLabel(.green))
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "Original content")

        XCTAssertNil(coordinator.duplicateSelectedScene())

        let manifest = coordinator.projectManager.getManifest()
        let chapter = try XCTUnwrap(manifest.hierarchy.chapters.first)
        let sourceIndex = try XCTUnwrap(chapter.scenes.firstIndex(of: sourceSceneID))
        let duplicatedID = chapter.scenes[sourceIndex + 1]
        let duplicatedScene = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.id == duplicatedID }))
        let sourceScene = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.id == sourceSceneID }))

        XCTAssertEqual(duplicatedScene.title, "\(sourceScene.title) Copy")
        XCTAssertEqual(duplicatedScene.synopsis, sourceScene.synopsis)
        XCTAssertEqual(duplicatedScene.status, sourceScene.status)
        XCTAssertEqual(duplicatedScene.colorLabel, sourceScene.colorLabel)
        XCTAssertEqual(duplicatedScene.metadata, sourceScene.metadata)
        XCTAssertEqual(duplicatedScene.tags, sourceScene.tags)
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: duplicatedID), "Original content")
        XCTAssertEqual(coordinator.editorState.currentSceneId, duplicatedID)
    }

    func testMoveSelectedSceneUpAndDownReordersWithinChapter() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "MoveScene")
        let chapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterID, at: nil, title: "Second")
        let thirdScene = try coordinator.projectManager.addScene(to: chapterID, at: nil, title: "Third")
        coordinator.navigateToScene(secondScene.id)

        XCTAssertNil(coordinator.moveSelectedSceneDown())
        var chapter = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first(where: { $0.id == chapterID }))
        XCTAssertEqual(chapter.scenes, [coordinator.linearState.orderedSceneIds[0], thirdScene.id, secondScene.id])

        XCTAssertNil(coordinator.moveSelectedSceneUp())
        chapter = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first(where: { $0.id == chapterID }))
        XCTAssertEqual(chapter.scenes, [coordinator.linearState.orderedSceneIds[0], secondScene.id, thirdScene.id])
        XCTAssertEqual(coordinator.editorState.currentSceneId, secondScene.id)
    }

    func testRevealSelectionInSidebarExpandsParentAndSelectsScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RevealScene")
        let chapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterID, at: nil, title: "Reveal Me")

        XCTAssertNil(coordinator.revealSelectionInSidebar())
        XCTAssertEqual(coordinator.navigationState.selectedSceneId, coordinator.editorState.currentSceneId)

        coordinator.navigationState.selectedSceneId = secondScene.id
        XCTAssertNil(coordinator.revealSelectionInSidebar())
        XCTAssertEqual(coordinator.navigationState.selectedSceneId, secondScene.id)
        XCTAssertTrue(coordinator.navigationState.expandedNodes.contains(chapterID))
    }

    func testSendSelectedSceneToStagingAndMoveBackToChapter() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "StageAndMove")
        let chapterA = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let chapterB = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Chapter B")
        let secondScene = try coordinator.projectManager.addScene(to: chapterA, at: nil, title: "Stage Me")
        coordinator.navigateToScene(secondScene.id)

        XCTAssertNil(coordinator.sendSelectedSceneToStaging())
        XCTAssertTrue(coordinator.projectManager.currentProject?.manuscript.stagingArea.contains(where: { $0.id == secondScene.id }) == true)
        XCTAssertTrue(coordinator.canMoveSelectedSceneToAnotherChapter)

        XCTAssertNil(coordinator.moveSelectedScene(toChapter: chapterB.id))
        XCTAssertTrue(coordinator.projectManager.currentProject?.manuscript.stagingArea.contains(where: { $0.id == secondScene.id }) == false)
        XCTAssertTrue(coordinator.projectManager.currentProject?.manuscript.chapters.first(where: { $0.id == chapterB.id })?.scenes.contains(where: { $0.id == secondScene.id }) == true)
    }

    func testMoveAllStagingScenesToChapterRestoresBatch() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "StageBatchMove")
        let chapterA = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let chapterB = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Chapter B")
        let secondScene = try coordinator.projectManager.addScene(to: chapterA, at: nil, title: "Stage Me Too")
        let thirdScene = try coordinator.projectManager.addScene(to: chapterA, at: nil, title: "Stage Me Three")

        coordinator.navigateToScene(secondScene.id)
        XCTAssertNil(coordinator.sendSelectedSceneToStaging())
        coordinator.navigateToScene(thirdScene.id)
        XCTAssertNil(coordinator.sendSelectedSceneToStaging())
        XCTAssertEqual(coordinator.stagingSceneCount, 2)

        XCTAssertNil(coordinator.moveAllStagingScenes(toChapter: chapterB.id))
        XCTAssertEqual(coordinator.stagingSceneCount, 0)
        let restoredChapter = try XCTUnwrap(coordinator.projectManager.currentProject?.manuscript.chapters.first(where: { $0.id == chapterB.id }))
        XCTAssertTrue(restoredChapter.scenes.contains(where: { $0.id == secondScene.id }))
        XCTAssertTrue(restoredChapter.scenes.contains(where: { $0.id == thirdScene.id }))
    }

    func testBatchSendAndMoveSelectedModularScenes() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ModularBatchStage")
        let chapterA = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let chapterB = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Chapter B")
        let secondScene = try coordinator.projectManager.addScene(to: chapterA, at: nil, title: "Second")
        let thirdScene = try coordinator.projectManager.addScene(to: chapterA, at: nil, title: "Third")
        coordinator.modeController.switchTo(.modular)
        coordinator.modularState.selectCard(sceneId: secondScene.id)
        coordinator.modularState.selectCard(sceneId: thirdScene.id, multiSelect: true)

        XCTAssertNil(coordinator.batchSendSelectedScenesToStaging())
        XCTAssertEqual(coordinator.stagingSceneCount, 2)

        XCTAssertNil(coordinator.batchMoveSelectedScenes(toChapter: chapterB.id))
        XCTAssertEqual(coordinator.stagingSceneCount, 0)
        let restoredChapter = try XCTUnwrap(coordinator.projectManager.currentProject?.manuscript.chapters.first(where: { $0.id == chapterB.id }))
        XCTAssertEqual(restoredChapter.scenes.count, 2)
    }

    func testEntitiesPersistAndLinkSelectedScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Entities")
        let sceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)

        XCTAssertNil(coordinator.addEntity(name: "Ava", type: .character, notes: "Lead", linkSelectedScene: true))
        let entity = try XCTUnwrap(coordinator.entities.first)
        XCTAssertTrue(entity.sceneMentions.contains(sceneID))
        XCTAssertNil(coordinator.linkSelectedSceneToEntity(entity.id))

        try coordinator.projectManager.closeProject()
        let reopened = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Entities")
        XCTAssertTrue(reopened.entities.contains(where: { $0.name == "Ava" }))
    }

    func testEntityUpdateAndMentionScanUseAliasesAndCustomFields() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "EntityScan")
        let chapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterID, at: nil, title: "Second")
        let firstSceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneID, content: "Captain Ava arrives.")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "The commander surveys the room.")

        XCTAssertNil(
            coordinator.addEntity(
                name: "Ava",
                type: .character,
                aliases: ["Commander"],
                fields: ["Role": "Captain"],
                notes: "Lead",
                linkSelectedScene: false
            )
        )
        let entityID = try XCTUnwrap(coordinator.entities.first?.id)
        XCTAssertNil(
            coordinator.updateEntity(
                entityID,
                name: "Ava Mercer",
                type: .character,
                aliases: ["Commander"],
                fields: ["Role": "Captain", "Faction": "Survey"],
                notes: "Updated"
            )
        )
        let scanMessage = coordinator.scanEntityMentions(entityID)

        XCTAssertEqual(scanMessage, "Found 2 scene mention(s) for Ava Mercer.")
        let entity = try XCTUnwrap(coordinator.entities.first(where: { $0.id == entityID }))
        XCTAssertEqual(entity.fields["Role"], "Captain")
        XCTAssertEqual(entity.fields["Faction"], "Survey")
        XCTAssertEqual(Set(entity.sceneMentions), Set([firstSceneID, secondScene.id]))
    }

    func testEntityRelationshipsAndLinkedScenesAreTracked() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "EntityRelations")
        let chapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterID, at: nil, title: "Harbor")
        let firstSceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneID, content: "Ava Mercer arrives in the city.")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "Mercer meets Ilex at the harbor.")

        XCTAssertNil(coordinator.addEntity(name: "Ava Mercer", type: .character, aliases: ["Mercer"], notes: "", linkSelectedScene: false))
        XCTAssertNil(coordinator.addEntity(name: "Ilex", type: .location, aliases: [], notes: "", linkSelectedScene: false))

        let avaID = try XCTUnwrap(coordinator.entities.first(where: { $0.name == "Ava Mercer" })?.id)
        let ilexID = try XCTUnwrap(coordinator.entities.first(where: { $0.name == "Ilex" })?.id)

        XCTAssertEqual(coordinator.scanEntityMentions(avaID), "Found 2 scene mention(s) for Ava Mercer.")
        XCTAssertNil(coordinator.addEntityRelationship(from: avaID, to: ilexID, label: "seeks", bidirectional: true))

        XCTAssertEqual(Set(coordinator.entityLinkedScenes(avaID).map(\.id)), Set([firstSceneID, secondScene.id]))
        XCTAssertEqual(coordinator.entityRelationships(avaID).first?.target.id, ilexID)
        XCTAssertEqual(coordinator.entityRelationships(ilexID).first?.target.id, avaID)
    }

    func testCompilePresetExportsRichFrontAndBackMatterToHtml() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CompileRichHTML")
        let chapterA = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let sceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: sceneID, content: "Opening paragraph.\n\nSecond paragraph.")

        XCTAssertNil(
            coordinator.saveCompilePreset(
                name: "RichHTML",
                format: .html,
                includedSectionIds: [chapterA],
                fontFamily: "Georgia",
                fontSize: 15,
                lineSpacing: 1.8,
                chapterHeadingStyle: "h1",
                sceneBreakMarker: "//",
                subtitle: "A Harbor Novel",
                authorName: "L. Eaton",
                includeTitlePage: true,
                includeTableOfContents: true,
                copyrightText: "Copyright 2026",
                dedicationText: "For the midnight draft.",
                includeAboutAuthor: true,
                aboutAuthorText: "Lives near the harbor.",
                bibliographyText: "Harbor Maps, 1922.",
                appendixTitle: "Appendix A",
                appendixContent: "Tide tables."
            )
        )

        let preset = try XCTUnwrap(coordinator.compilePresets.first(where: { $0.name == "RichHTML" }))
        XCTAssertTrue(coordinator.exportProject(using: preset.id)?.contains("Exported HTML") == true)
        let rootURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(at: exportsURL, includingPropertiesForKeys: nil)
        let exportedFile = try XCTUnwrap(contents.first(where: { $0.pathExtension == "html" && $0.lastPathComponent.contains("RichHTML") }))
        let exportedText = try String(contentsOf: exportedFile, encoding: .utf8)

        XCTAssertTrue(exportedText.contains("<section class=\"title-page\">"))
        XCTAssertTrue(exportedText.contains("A Harbor Novel"))
        XCTAssertTrue(exportedText.contains("Copyright 2026"))
        XCTAssertTrue(exportedText.contains("Bibliography"))
        XCTAssertTrue(exportedText.contains("Appendix A"))
        XCTAssertTrue(exportedText.contains("<section class=\"scene\">"))
        XCTAssertTrue(exportedText.contains("font-family: \"Georgia\""))
    }

    func testNotesPersistAndRetainSceneAndEntityLinks() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ProjectNotes")
        let sceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        XCTAssertNil(coordinator.addEntity(name: "Ava", type: .character, notes: "", linkSelectedScene: false))
        let entityID = try XCTUnwrap(coordinator.entities.first?.id)

        XCTAssertNil(
            coordinator.addNote(
                title: "Scene Fix",
                content: "Tighten the opening beat.",
                folder: "Draft Pass",
                linkedSceneIDs: [sceneID],
                linkedEntityIDs: [entityID]
            )
        )
        let noteID = try XCTUnwrap(coordinator.notes.first?.id)
        XCTAssertNil(
            coordinator.updateNote(
                noteID,
                title: "Scene Fixes",
                content: "Tighten the opening beat and mention Ava earlier.",
                folder: "Revision",
                linkedSceneIDs: [sceneID],
                linkedEntityIDs: [entityID]
            )
        )

        XCTAssertEqual(coordinator.notesLinkedToScene(sceneID).count, 1)
        XCTAssertEqual(coordinator.notesLinkedToEntity(entityID).count, 1)

        try coordinator.projectManager.closeProject()
        let reopened = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ProjectNotes")
        let reopenedNote = try XCTUnwrap(reopened.notes.first)
        XCTAssertEqual(reopenedNote.title, "Scene Fixes")
        XCTAssertEqual(reopenedNote.folder, "Revision")
        XCTAssertEqual(reopenedNote.linkedSceneIds, [sceneID])
        XCTAssertEqual(reopenedNote.linkedEntityIds, [entityID])
    }

    func testTimelineEventsPersistAndRetainLinkedScenes() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Timeline")
        let firstSceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        let chapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterID, at: nil, title: "Harbor")

        XCTAssertNil(
            coordinator.addTimelineEvent(
                title: "Arrival",
                description: "Ava reaches the harbor.",
                track: "Main Plot",
                position: .relative(order: 2),
                linkedSceneIDs: [firstSceneID, secondScene.id],
                color: "#336699"
            )
        )

        let event = try XCTUnwrap(coordinator.timelineEvents.first)
        XCTAssertEqual(Set(event.linkedSceneIds), Set([firstSceneID, secondScene.id]))

        try coordinator.projectManager.closeProject()
        let reopened = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Timeline")
        let reopenedEvent = try XCTUnwrap(reopened.timelineEvents.first)
        XCTAssertEqual(reopenedEvent.title, "Arrival")
        XCTAssertEqual(Set(reopenedEvent.linkedSceneIds), Set([firstSceneID, secondScene.id]))
    }

    func testSourcesPersistAndInsertCitationsIntoEditor() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Sources")

        XCTAssertNil(
            coordinator.addSource(
                title: "Harbor Log",
                author: "M. Vale",
                date: "2025",
                url: "https://example.com/log",
                notes: "Primary harbor reference.",
                citationKey: "harborlog"
            )
        )
        let sourceID = try XCTUnwrap(coordinator.sources.first?.id)
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "Reference ")
        coordinator.editorState.cursorPosition = coordinator.editorState.getCurrentContent().count

        XCTAssertNil(coordinator.insertCitation(sourceID))
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "Reference [@harborlog]")

        try coordinator.projectManager.closeProject()
        let reopened = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Sources")
        let reopenedSource = try XCTUnwrap(reopened.sources.first)
        XCTAssertEqual(reopenedSource.title, "Harbor Log")
        XCTAssertEqual(reopenedSource.citationKey, "harborlog")
    }

    func testSourceLibrarySupportsResearchAttachmentsLinksAndCitationNavigation() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SourceResearch")
        let sceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        XCTAssertNil(coordinator.addNote(title: "Dock Note", content: "Reference note", folder: nil, linkedSceneIDs: [], linkedEntityIDs: []))
        let noteID = try XCTUnwrap(coordinator.notes.first?.id)
        XCTAssertNil(coordinator.addEntity(name: "Harbor", type: .location, aliases: [], notes: "", linkSelectedScene: false))
        let entityID = try XCTUnwrap(coordinator.entities.first?.id)

        XCTAssertNil(
            coordinator.addSource(
                title: "Dock Registry",
                author: "J. North",
                date: "2024",
                url: "https://example.com/dock",
                publication: "Port Archive",
                volume: "7",
                pages: "11-19",
                doi: "10.1234/dock",
                notes: "Tie to harbor scenes",
                citationKey: "dockreg",
                linkedSceneIDs: [sceneID],
                linkedEntityIDs: [entityID],
                linkedNoteIDs: [noteID]
            )
        )

        let sourceID = try XCTUnwrap(coordinator.sources.first?.id)
        let researchFile = tempDir.appendingPathComponent("registry.txt")
        try "harbor ledger".write(to: researchFile, atomically: true, encoding: .utf8)
        XCTAssertTrue(coordinator.importResearchFile(from: researchFile, into: sourceID)?.contains("Imported research file") == true)

        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "Use [@dockreg] in the harbor draft.")
        XCTAssertNil(coordinator.openFirstCitationMention(for: sourceID))
        XCTAssertEqual(coordinator.editorState.currentSceneId, sceneID)

        let updatedSource = try XCTUnwrap(coordinator.sources.first)
        XCTAssertEqual(updatedSource.linkedSceneIds, [sceneID])
        XCTAssertEqual(updatedSource.linkedEntityIds, [entityID])
        XCTAssertEqual(updatedSource.linkedNoteIds, [noteID])
        XCTAssertEqual(updatedSource.attachments.count, 1)
        let attachmentID = try XCTUnwrap(updatedSource.attachments.first?.id)
        let attachmentURL = try XCTUnwrap(coordinator.researchAttachmentURL(sourceID: sourceID, attachmentID: attachmentID))
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentURL.path))

        try coordinator.projectManager.closeProject()
        let reopened = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SourceResearch")
        XCTAssertEqual(reopened.sources.first?.attachments.count, 1)
        XCTAssertEqual(reopened.sources.first?.linkedNoteIds, [noteID])
    }

    func testScratchpadPersistsAndInsertsIntoEditor() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Scratchpad")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "Reusable phrase")
        coordinator.editorState.selection = 0..<8

        XCTAssertNil(coordinator.captureSelectionToScratchpad(title: "Phrase", as: .clipboard))
        let itemID = try XCTUnwrap(coordinator.scratchpadItems.first?.id)

        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "")
        XCTAssertNil(coordinator.insertScratchpadItem(itemID))
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "Reusable")

        try coordinator.projectManager.closeProject()
        let reopened = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Scratchpad")
        XCTAssertEqual(reopened.scratchpadItems.first?.title, "Phrase")
        XCTAssertEqual(reopened.scratchpadItems.first?.kind, .clipboard)
    }

    func testNotesFocusAndEntityMentionHelpersTrackCurrentContext() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NoteFocus")
        let sceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "Ava Mercer studies the chart.")
        XCTAssertNil(coordinator.addEntity(name: "Ava Mercer", type: .character, aliases: ["Mercer"], notes: "", linkSelectedScene: false))
        let entityID = try XCTUnwrap(coordinator.entities.first?.id)
        _ = coordinator.scanEntityMentions(entityID)
        XCTAssertNil(coordinator.addNote(title: "Chart note", content: "Track the harbor chart.", folder: "Research", linkedSceneIDs: [sceneID], linkedEntityIDs: [entityID]))

        coordinator.focusNotes(onScene: sceneID)
        XCTAssertEqual(coordinator.notesFocusSceneID, sceneID)
        XCTAssertNil(coordinator.notesFocusEntityID)

        coordinator.focusNotes(onEntity: entityID)
        XCTAssertEqual(coordinator.notesFocusEntityID, entityID)
        XCTAssertNil(coordinator.notesFocusSceneID)

        let mentions = coordinator.highlightedEntityMentions(in: sceneID)
        XCTAssertEqual(mentions.first?.entity.id, entityID)
        XCTAssertTrue(mentions.first?.snippet.contains("Ava Mercer") == true)
        XCTAssertFalse(coordinator.editorState.entityMentionRanges.isEmpty)
    }

    func testCompilePresetSupportsThemeOrderingAndDocumentFormats() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CompileGroundwork")
        let chapterA = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let chapterB = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Alpha Chapter")
        let sceneB = try coordinator.projectManager.addScene(to: chapterB.id, at: nil, title: "Alpha Scene")
        try coordinator.projectManager.saveSceneContent(sceneId: sceneB.id, content: "Alpha export content.")
        coordinator.navigateToScene(sceneB.id)
        XCTAssertNil(coordinator.sendSelectedSceneToStaging())

        XCTAssertNil(
            coordinator.saveCompilePreset(
                name: "DocxPrep",
                format: .docx,
                includedSectionIds: [chapterA, chapterB.id],
                fontFamily: "Menlo",
                fontSize: 14,
                lineSpacing: 1.6,
                htmlTheme: .midnight,
                pageSize: .a4,
                templateStyle: .modern,
                pageMargins: Margins(top: 1.25, bottom: 1, left: 0.75, right: 0.75),
                includeTitlePage: true,
                includeTableOfContents: false,
                includeStagingArea: true,
                sectionOrder: .alphabetical
            )
        )
        let preset = try XCTUnwrap(coordinator.compilePresets.first(where: { $0.name == "DocxPrep" }))
        XCTAssertEqual(preset.styleOverrides.htmlTheme, .midnight)
        XCTAssertEqual(preset.styleOverrides.pageSize, .a4)
        XCTAssertEqual(preset.styleOverrides.templateStyle, .modern)
        XCTAssertEqual(preset.backMatter.sectionOrder, .alphabetical)
        XCTAssertTrue(coordinator.exportProject(using: preset.id)?.contains("Exported DOCX") == true)
        XCTAssertTrue(coordinator.exportProject(format: .pdf)?.contains("Exported PDF") == true)
        let preview = coordinator.compilePreview(
            format: .pdf,
            includedSectionIds: [chapterA, chapterB.id],
            fontFamily: "Menlo",
            fontSize: 14,
            lineSpacing: 1.6,
            chapterHeadingStyle: "h2",
            sceneBreakMarker: "***",
            htmlTheme: .midnight,
            pageSize: .a4,
            templateStyle: .modern,
            pageMargins: Margins(top: 1.25, bottom: 1, left: 0.75, right: 0.75),
            subtitle: "",
            authorName: coordinator.projectDisplayName,
            includeTitlePage: true,
            includeTableOfContents: false,
            includeStagingArea: true,
            copyrightText: "",
            dedicationText: "",
            includeAboutAuthor: false,
            aboutAuthorText: "",
            sectionOrder: .alphabetical,
            bibliographyText: "",
            appendixTitle: "",
            appendixContent: ""
        )
        XCTAssertTrue(preview?.contains("@page") == true)
        XCTAssertTrue(preview?.contains("size: A4") == true)

        let rootURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let contents = try FileManager.default.contentsOfDirectory(at: exportsURL, includingPropertiesForKeys: nil)
        XCTAssertNotNil(contents.first(where: { $0.lastPathComponent.contains("DocxPrep") && $0.pathExtension == "docx" }))
        XCTAssertNotNil(contents.first(where: { $0.pathExtension == "pdf" }))
    }

    func testCompilePresetSupportsStylesheetOverridesAndEPUBExport() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "EPUBExport")
        let chapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        XCTAssertNil(
            coordinator.saveCompilePreset(
                name: "EPUBPreset",
                format: .epub,
                includedSectionIds: [chapterID],
                fontFamily: "Georgia",
                fontSize: 12,
                lineSpacing: 1.7,
                htmlTheme: .editorial,
                pageSize: .trade,
                templateStyle: .manuscript,
                includeTitlePage: true,
                includeTableOfContents: true,
                stylesheetName: "Bookish",
                customCSS: ".chapter { color: #123456; }"
            )
        )

        let preset = try XCTUnwrap(coordinator.compilePresets.first(where: { $0.name == "EPUBPreset" }))
        XCTAssertEqual(preset.styleOverrides.stylesheetName, "Bookish")
        XCTAssertEqual(preset.styleOverrides.customCSS, ".chapter { color: #123456; }")
        XCTAssertTrue(coordinator.exportProject(using: preset.id)?.contains("Exported EPUB") == true)

        let rootURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let epubURL = try XCTUnwrap(try FileManager.default.contentsOfDirectory(at: exportsURL, includingPropertiesForKeys: nil).first(where: { $0.pathExtension == "epub" }))
        let unpackedURL = tempDir.appendingPathComponent("epub-unpacked", isDirectory: true)
        try FileManager.default.createDirectory(at: unpackedURL, withIntermediateDirectories: true)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", epubURL.path, "-d", unpackedURL.path]
        try unzip.run()
        unzip.waitUntilExit()
        XCTAssertEqual(unzip.terminationStatus, 0)
        let stylesheet = try String(contentsOf: unpackedURL.appendingPathComponent("OEBPS/stylesheet.css"), encoding: .utf8)
        let opf = try String(contentsOf: unpackedURL.appendingPathComponent("OEBPS/content.opf"), encoding: .utf8)
        XCTAssertTrue(stylesheet.contains("Stylesheet: Bookish"))
        XCTAssertTrue(stylesheet.contains(".chapter { color: #123456; }"))
        XCTAssertTrue(opf.contains("<dc:language>en</dc:language>"))
        XCTAssertTrue(opf.contains("<dc:publisher>"))
    }

    func testExportProjectDraftWritesUnsavedPresetOutput() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "DraftExport")
        let chapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)

        let message = coordinator.exportProjectDraft(
            format: .html,
            includedSectionIds: [chapterID],
            fontFamily: "Georgia",
            fontSize: 13,
            lineSpacing: 1.8,
            chapterHeadingStyle: "h2",
            sceneBreakMarker: "***",
            htmlTheme: .editorial,
            pageSize: .trade,
            templateStyle: .modern,
            pageMargins: Margins(top: 1, bottom: 1, left: 1, right: 1),
            subtitle: "Preview Run",
            authorName: "Tester",
            includeTitlePage: true,
            includeTableOfContents: true,
            includeStagingArea: false,
            languageCode: "en",
            publisherName: "North Dock Press",
            copyrightText: "",
            dedicationText: "",
            includeAboutAuthor: false,
            aboutAuthorText: "",
            sectionOrder: .manuscript,
            bibliographyText: "",
            appendixTitle: "",
            appendixContent: "",
            stylesheetName: "Release",
            customCSS: ".manuscript { letter-spacing: 0.02em; }"
        )

        XCTAssertTrue(message?.contains("Exported HTML") == true)
        let rootURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        let exportedFile = try XCTUnwrap(
            try FileManager.default.contentsOfDirectory(at: exportsURL, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "html" && $0.lastPathComponent.contains("Draft-Export") })
        )
        let exportedText = try String(contentsOf: exportedFile, encoding: .utf8)
        XCTAssertTrue(exportedText.contains("Preview Run"))
        XCTAssertTrue(exportedText.contains("Tester"))
    }

    func testInsertEntityMentionWritesIntoActiveEditor() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "EntityInsert")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "Captain ")
        coordinator.editorState.cursorPosition = coordinator.editorState.getCurrentContent().count
        XCTAssertNil(coordinator.addEntity(name: "Ava Mercer", type: .character, aliases: ["Mercer"], notes: "", linkSelectedScene: false))
        let entityID = try XCTUnwrap(coordinator.entities.first?.id)

        XCTAssertNil(coordinator.insertEntityMention(entityID))

        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "Captain Ava Mercer")
        XCTAssertTrue(coordinator.editorState.isModified)
    }

    func testOpenSelectionInSplitUsesSelectedSceneAsSecondaryPane() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectionSplit")
        let manifest = coordinator.projectManager.getManifest()
        let chapterID = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let primarySceneID = try XCTUnwrap(coordinator.editorState.currentSceneId)
        let secondScene = try coordinator.projectManager.addScene(to: chapterID, at: nil, title: "Target Split")
        coordinator.navigationState.navigateTo(sceneId: secondScene.id)

        XCTAssertNil(coordinator.openSelectionInSplit(windowWidth: 1200))
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primarySceneID)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondScene.id)
        XCTAssertEqual(coordinator.splitEditorState.activePaneIndex, 1)
    }

    func testSwitchableProjectsPrioritizeCurrentThenRecentsWithoutDuplication() throws {
        let suiteName = "WorkspaceCoordinatorTests.SwitchableProjects.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "SwitchSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "SwitchA"))
        XCTAssertNil(coordinator.createAndOpenProject(named: "SwitchB"))
        let switchAURL = tempDir.appendingPathComponent("SwitchA", isDirectory: true)
        XCTAssertNil(coordinator.openProject(at: switchAURL))

        let names = coordinator.switchableProjects.map(\.name)
        XCTAssertGreaterThanOrEqual(names.count, 2)
        XCTAssertEqual(names[0], "SwitchA")
        XCTAssertEqual(names[1], "SwitchB")
        XCTAssertEqual(names.filter { $0 == "SwitchA" }.count, 1)
    }

    func testShowInlineSearchUsesCurrentSceneIncludingUnsavedContent() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchInline")
        coordinator.editorState.insertText("dragon", at: 0)
        coordinator.searchQueryText = "dragon"

        coordinator.showInlineSearchPanel()

        XCTAssertTrue(coordinator.isSearchPanelVisible)
        XCTAssertEqual(coordinator.searchScope, .currentScene)
        XCTAssertEqual(coordinator.searchResults.count, 1)
        XCTAssertEqual(coordinator.searchResults.first?.matchText.lowercased(), "dragon")
    }

    func testProjectSearchReplaceAllUpdatesScenes() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceAll")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")

        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "color color")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "color")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "color"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.count, 3)

        coordinator.searchReplacementText = "colour"
        let message = coordinator.replaceAllSearchResults()

        XCTAssertEqual(message, "Replaced 3 matches across 2 scenes.")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: firstSceneId), "colour colour")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: secondScene.id), "colour")
    }

    func testProjectSearchReplaceAllHonorsSceneSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceSelection")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")

        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "color color")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "color")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "color"
        coordinator.searchReplacementText = "colour"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.count, 3)
        XCTAssertEqual(coordinator.selectedReplaceSceneCount, 2)

        coordinator.setSceneIncludedForReplace(secondScene.id, included: false)
        XCTAssertEqual(coordinator.selectedReplaceSceneCount, 1)
        let message = coordinator.replaceAllSearchResults()

        XCTAssertEqual(message, "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: firstSceneId), "colour colour")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: secondScene.id), "color")
    }

    func testProjectSearchReplaceAllWithNoScenesSelectedReturnsMessage() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceNoneSelected")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "color color")
        coordinator.searchQueryText = "color"
        coordinator.searchReplacementText = "colour"
        coordinator.showInlineSearchPanel()
        coordinator.excludeAllReplaceScenes()

        XCTAssertEqual(coordinator.replaceAllSearchResults(), "No scenes selected for replace.")
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "color color")
    }

    func testReplaceSceneSelectionModeKeepManualSelectionPersistsAcrossSearchRuns() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchSelectionModeKeep")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "token")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "token")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "token"
        coordinator.runSearch()
        coordinator.replaceSceneSelectionMode = .keepManualSelection
        coordinator.setSceneIncludedForReplace(secondScene.id, included: false)
        XCTAssertEqual(coordinator.selectedReplaceSceneCount, 1)

        coordinator.runSearch()
        XCTAssertEqual(coordinator.selectedReplaceSceneCount, 1)
        XCTAssertFalse(coordinator.isSceneIncludedForReplace(secondScene.id))
    }

    func testReplaceSceneSelectionModePreferencePersistsAcrossCoordinatorInstances() throws {
        let suiteName = "WorkspaceCoordinatorTests.ReplaceSelectionMode.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ReplaceSelectionModePrefs",
            splitSettingsStore: defaults,
            recentProjectStore: defaults,
            searchPreferenceStore: defaults
        )
        first.replaceSceneSelectionMode = .keepManualSelection
        try first.projectManager.closeProject()

        let second = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ReplaceSelectionModePrefs",
            splitSettingsStore: defaults,
            recentProjectStore: defaults,
            searchPreferenceStore: defaults
        )

        XCTAssertEqual(second.replaceSceneSelectionMode, .keepManualSelection)
    }

    func testReplaceSceneSelectionModeResetOnSearchResetsSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchSelectionModeReset")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "token")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "token")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "token"
        coordinator.runSearch()
        coordinator.replaceSceneSelectionMode = .resetOnSearch
        coordinator.setSceneIncludedForReplace(secondScene.id, included: false)
        XCTAssertEqual(coordinator.selectedReplaceSceneCount, 1)

        coordinator.runSearch()
        XCTAssertEqual(coordinator.selectedReplaceSceneCount, 2)
        XCTAssertTrue(coordinator.isSceneIncludedForReplace(secondScene.id))
    }

    func testIncludeReplaceScenesWithMatchCountGreaterThanThreshold() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchSelectionThreshold")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "x x x")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "x")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "x"
        coordinator.runSearch()
        coordinator.includeReplaceScenes(withMatchCountGreaterThan: 1)

        XCTAssertTrue(coordinator.isSceneIncludedForReplace(firstSceneId))
        XCTAssertFalse(coordinator.isSceneIncludedForReplace(secondScene.id))
        XCTAssertEqual(coordinator.selectedReplaceSceneCount, 1)
    }

    func testReplacePreviewItemsSupportFilterAndSort() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchPreviewSortFilter")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let betaScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Beta Scene")
        let alphaScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Alpha Scene")

        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "token")
        try coordinator.projectManager.saveSceneContent(sceneId: betaScene.id, content: "token token token")
        try coordinator.projectManager.saveSceneContent(sceneId: alphaScene.id, content: "token token")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "token"
        coordinator.runSearch()
        coordinator.setSceneIncludedForReplace(betaScene.id, included: false)

        let excluded = coordinator.replacePreviewItems(filter: .excluded, sort: .manuscriptOrder)
        XCTAssertEqual(excluded.map(\.id), [betaScene.id])

        let sortedByMatches = coordinator.replacePreviewItems(sort: .matchCountDescending)
        XCTAssertEqual(sortedByMatches.map(\.id), [betaScene.id, alphaScene.id, firstSceneId])

        let sortedByTitle = coordinator.replacePreviewItems(sort: .sceneTitle)
        XCTAssertEqual(sortedByTitle.map(\.sceneTitle), ["Alpha Scene", "Beta Scene", "Untitled Scene"])
        XCTAssertTrue(sortedByMatches.allSatisfy { !$0.matchTargets.isEmpty })
    }

    func testReplacePreviewItemsCollectMultipleDistinctSnippetsPerScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchPreviewSnippets")
        coordinator.editorState.replaceText(
            in: 0..<coordinator.editorState.getCurrentContent().count,
            with: "alpha one middle filler alpha two distant filler alpha three"
        )
        coordinator.showInlineSearchPanel()
        coordinator.searchQueryText = "alpha"
        coordinator.runSearch()

        let item = try XCTUnwrap(coordinator.replacePreviewItems().first)
        XCTAssertEqual(item.matchCount, 3)
        XCTAssertEqual(item.matchTargets.count, 3)
        XCTAssertTrue(item.matchTargets.allSatisfy { $0.snippet.localizedCaseInsensitiveContains("alpha") })
    }

    func testSelectReplacePreviewMatchNavigatesToStoredResult() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchPreviewMatchNavigation")
        coordinator.editorState.replaceText(
            in: 0..<coordinator.editorState.getCurrentContent().count,
            with: "alpha one middle alpha two"
        )
        coordinator.showInlineSearchPanel()
        coordinator.searchQueryText = "alpha"
        coordinator.runSearch()

        let item = try XCTUnwrap(coordinator.replacePreviewItems().first)
        let target = try XCTUnwrap(item.matchTargets.last)

        coordinator.selectReplacePreviewMatch(sceneID: item.id, resultIndex: target.resultIndex)

        XCTAssertEqual(coordinator.currentSearchResultIndex, target.resultIndex)
        XCTAssertEqual(coordinator.editorState.selection, coordinator.searchResults[target.resultIndex].matchRange)
    }

    func testReplaceNextSearchResultUpdatesCurrentMatchOnly() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceNext")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "color color color")
        coordinator.searchQueryText = "color"
        coordinator.searchReplacementText = "colour"

        coordinator.showInlineSearchPanel()
        coordinator.selectSearchResult(at: 0)

        let message = coordinator.replaceNextSearchResult()
        XCTAssertEqual(message, "Replaced next match.")
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "colour color color")
        XCTAssertEqual(coordinator.searchResults.count, 2)
    }

    func testRegexReplacementWarningFlagsMissingCaptureGroups() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchRegexWarnings")
        coordinator.showInlineSearchPanel()
        coordinator.searchIsRegex = true
        coordinator.searchQueryText = "(\\w+)"
        coordinator.searchReplacementText = "$2"

        XCTAssertEqual(coordinator.regexReplacementHelpText, "Regex replace supports capture groups like $1 through $1.")
        XCTAssertEqual(coordinator.regexReplacementWarning, "Replacement references $2, but the current regex exposes only 1 capture group(s).")
    }

    func testGroupedSearchResultsOrganizeByChapterAndScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchGroupedResults")
        let firstChapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondChapter = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Second")
        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        let firstChapterExtraScene = try coordinator.projectManager.addScene(to: firstChapterId, at: nil, title: "Scene B")
        let secondChapterScene = try coordinator.projectManager.addScene(to: secondChapter.id, at: nil, title: "Scene C")

        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "dragon here")
        try coordinator.projectManager.saveSceneContent(sceneId: firstChapterExtraScene.id, content: "dragon there")
        try coordinator.projectManager.saveSceneContent(sceneId: secondChapterScene.id, content: "dragon elsewhere")

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "dragon"
        coordinator.runSearch()

        let sections = coordinator.groupedSearchResults
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(Set(sections.map(\.chapterTitle)), Set(["Chapter 1", "Second"]))
        let chapterOne = try XCTUnwrap(sections.first(where: { $0.chapterTitle == "Chapter 1" }))
        let second = try XCTUnwrap(sections.first(where: { $0.chapterTitle == "Second" }))
        XCTAssertEqual(chapterOne.matchCount, 1)
        XCTAssertEqual(chapterOne.scenes.count, 1)
        XCTAssertEqual(second.matchCount, 1)
        XCTAssertEqual(second.scenes.count, 1)
    }

    func testUndoLastReplaceBatchRestoresOnlyAffectedSelectedScenes() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceUndoBatch")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")

        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "color color")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "color")

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "color"
        coordinator.searchReplacementText = "colour"
        coordinator.runSearch()
        coordinator.setSceneIncludedForReplace(secondScene.id, included: false)

        XCTAssertEqual(coordinator.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertTrue(coordinator.canUndoLastReplaceBatch)
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: firstSceneId), "colour colour")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: secondScene.id), "color")

        XCTAssertEqual(coordinator.undoLastReplaceBatch(), "Undid last replace batch.")
        XCTAssertFalse(coordinator.canUndoLastReplaceBatch)
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: firstSceneId), "color color")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: secondScene.id), "color")
    }

    func testUndoLastReplaceBatchSupportsChainedUndo() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceUndoChain")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "alpha alpha")

        coordinator.showInlineSearchPanel()
        coordinator.searchQueryText = "alpha"
        coordinator.searchReplacementText = "beta"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(coordinator.replaceUndoDepth, 1)

        coordinator.searchQueryText = "beta"
        coordinator.searchReplacementText = "gamma"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(coordinator.replaceUndoDepth, 2)
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "gamma gamma")

        XCTAssertEqual(coordinator.undoLastReplaceBatch(), "Undid last replace batch. 1 batch(es) still available.")
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "beta beta")
        XCTAssertEqual(coordinator.replaceUndoDepth, 1)

        XCTAssertEqual(coordinator.undoLastReplaceBatch(), "Undid last replace batch.")
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "alpha alpha")
        XCTAssertEqual(coordinator.replaceUndoDepth, 0)
    }

    func testRedoLastReplaceBatchRestoresUndoneBatch() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceRedo")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "alpha alpha")

        coordinator.showInlineSearchPanel()
        coordinator.searchQueryText = "alpha"
        coordinator.searchReplacementText = "beta"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")

        XCTAssertEqual(coordinator.undoLastReplaceBatch(), "Undid last replace batch.")
        XCTAssertTrue(coordinator.canRedoLastReplaceBatch)
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "alpha alpha")

        XCTAssertEqual(coordinator.redoLastReplaceBatch(), "Redid last replace batch.")
        XCTAssertFalse(coordinator.canRedoLastReplaceBatch)
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "beta beta")
    }

    func testSelectedChapterSearchScopeLimitsResultsToChosenChapters() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchSelectedChapterScope")
        let firstChapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondChapter = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Second")
        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        let secondScene = try coordinator.projectManager.addScene(to: secondChapter.id, at: nil, title: "Second Scene")

        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "alpha in first")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "alpha in second")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchScope = .selectedChapters
        coordinator.selectedSearchChapterIDs = [secondChapter.id]
        coordinator.searchQueryText = "alpha"
        coordinator.runSearch()

        XCTAssertEqual(coordinator.searchResults.count, 1)
        XCTAssertEqual(coordinator.searchResults.first?.sceneId, secondScene.id)
        XCTAssertNotEqual(firstChapterId, secondChapter.id)
    }

    func testSearchChapterScopePresetsPersistAcrossCoordinatorInstances() throws {
        let suiteName = "WorkspaceCoordinatorTests.SearchChapterPresets.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "SearchScopePresets",
            searchPreferenceStore: defaults
        )
        let secondChapter = try first.projectManager.addChapter(to: nil, at: nil, title: "Second")
        first.searchScope = .selectedChapters
        first.selectedSearchChapterIDs = [secondChapter.id]

        XCTAssertEqual(first.saveSelectedSearchChapterPreset(), "Saved chapter scope preset: Second.")
        XCTAssertEqual(first.searchChapterPresets.count, 1)
        try first.projectManager.saveManifest()
        try first.projectManager.closeProject()

        let second = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "SearchScopePresets",
            searchPreferenceStore: defaults
        )

        XCTAssertEqual(second.searchChapterPresets.count, 1)
        XCTAssertEqual(second.searchChapterPresets.first?.chapterIDs, [secondChapter.id])
        XCTAssertEqual(second.searchChapterPresets.first?.name, "Second")
    }

    func testApplyAndDeleteSearchChapterScopePresetUpdatesSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchScopePresetApply")
        let firstChapterID = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondChapter = try coordinator.projectManager.addChapter(to: nil, at: nil, title: "Second")
        coordinator.searchScope = .selectedChapters
        coordinator.selectedSearchChapterIDs = [firstChapterID, secondChapter.id]

        XCTAssertTrue(coordinator.saveSelectedSearchChapterPreset()?.contains("Saved chapter scope preset:") == true)
        let presetID = try XCTUnwrap(coordinator.searchChapterPresets.first?.id)

        coordinator.clearSearchChapterSelection()
        coordinator.applySearchChapterPreset(presetID)
        XCTAssertEqual(coordinator.selectedSearchChapterIDs, Set([firstChapterID, secondChapter.id]))

        coordinator.deleteSearchChapterPreset(presetID)
        XCTAssertTrue(coordinator.searchChapterPresets.isEmpty)
    }

    func testReplaceUndoHistoryReflectsRecentBatches() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceUndoHistory")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "alpha alpha")

        coordinator.showInlineSearchPanel()
        coordinator.searchQueryText = "alpha"
        coordinator.searchReplacementText = "beta"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")

        coordinator.searchQueryText = "beta"
        coordinator.searchReplacementText = "gamma"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")

        let history = coordinator.replaceUndoHistory
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].title, "\"beta\" -> \"gamma\"")
        XCTAssertEqual(history[0].summary, "2 replacements across 1 scene(s)")
        XCTAssertEqual(history[1].title, "\"alpha\" -> \"beta\"")
    }

    func testReplaceRedoHistoryReflectsUndoneBatches() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceRedoHistory")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "alpha alpha")

        coordinator.showInlineSearchPanel()
        coordinator.searchQueryText = "alpha"
        coordinator.searchReplacementText = "beta"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(coordinator.undoLastReplaceBatch(), "Undid last replace batch.")

        let history = coordinator.replaceRedoHistory
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].title, "\"alpha\" -> \"beta\"")
        XCTAssertEqual(history[0].summary, "2 replacements across 1 scene(s)")
    }

    func testFormattingWorkspaceScopesRunFormattingSearches() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchFormattingScopes")
        coordinator.editorState.replaceText(
            in: 0..<coordinator.editorState.getCurrentContent().count,
            with: "# Heading\nSome **bold** text and *italic* text."
        )

        coordinator.showProjectSearchPanel()
        coordinator.searchScope = .formattingItalic
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["italic"])

        coordinator.searchScope = .formattingBold
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["bold"])

        coordinator.searchScope = .formattingHeadings
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["Heading"])
    }

    func testAdditionalFormattingWorkspaceScopesRunFormattingSearches() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchMoreFormattingScopes")
        coordinator.editorState.replaceText(
            in: 0..<coordinator.editorState.getCurrentContent().count,
            with: """
            ~~cut~~ `inline`
            > quote
            [link](https://example.com) [^foot]
            """
        )

        coordinator.showProjectSearchPanel()

        coordinator.searchScope = .formattingStrikethrough
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["cut"])

        coordinator.searchScope = .formattingInlineCode
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["inline"])

        coordinator.searchScope = .formattingBlockQuotes
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["quote"])

        coordinator.editorState.replaceText(
            in: 0..<coordinator.editorState.getCurrentContent().count,
            with: "[link](https://example.com) [^foot]"
        )
        coordinator.searchScope = .formattingLinks
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["link"])

        coordinator.searchScope = .formattingFootnotes
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.map(\.matchText), ["foot"])
    }

    func testSearchIndexStatusCompletesAfterCoordinatorBuild() async throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchIndexStatus")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(coordinator.isSearchIndexing)
        XCTAssertGreaterThanOrEqual(coordinator.searchIndexStatus.total, 1)
        XCTAssertEqual(coordinator.searchIndexStatus.completed, coordinator.searchIndexStatus.total)
        XCTAssertEqual(coordinator.searchIndexStatus.percentage, 100)
    }

    func testSearchResultNavigationWrapsAndUpdatesCursorSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchNavigation")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "cat sat cat")
        coordinator.searchQueryText = "cat"

        coordinator.showInlineSearchPanel()
        XCTAssertEqual(coordinator.searchResultPositionText, "1 of 2")

        coordinator.navigateToNextSearchResult()
        XCTAssertEqual(coordinator.searchResultPositionText, "2 of 2")
        XCTAssertEqual(coordinator.editorState.selection, 8..<11)
        XCTAssertEqual(coordinator.editorState.cursorPosition, 11)

        coordinator.navigateToNextSearchResult()
        XCTAssertEqual(coordinator.searchResultPositionText, "1 of 2")
        XCTAssertEqual(coordinator.editorState.selection, 0..<3)
        XCTAssertEqual(coordinator.editorState.cursorPosition, 3)

        coordinator.navigateToPreviousSearchResult()
        XCTAssertEqual(coordinator.searchResultPositionText, "2 of 2")
        XCTAssertEqual(coordinator.editorState.selection, 8..<11)
    }

    func testSelectingProjectSearchResultNavigatesToMatchingScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchSelectResult")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")

        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "apple")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "banana")

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "banana"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.count, 1)

        coordinator.selectSearchResult(at: 0)
        XCTAssertEqual(coordinator.editorState.currentSceneId, secondScene.id)
        XCTAssertEqual(coordinator.navigationState.selectedSceneId, secondScene.id)
        XCTAssertEqual(coordinator.editorState.selection, 0..<6)
    }

    func testSearchHighlightsTrackMatchesAndClearOnHide() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlights")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "the cat sat on the mat")
        coordinator.searchQueryText = "the"

        coordinator.showInlineSearchPanel()
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, 2)
        XCTAssertEqual(coordinator.editorState.activeSearchHighlightRange, 0..<3)

        coordinator.navigateToNextSearchResult()
        XCTAssertEqual(coordinator.editorState.activeSearchHighlightRange, 15..<18)

        coordinator.hideSearchPanel()
        XCTAssertTrue(coordinator.editorState.searchHighlightRanges.isEmpty)
        XCTAssertNil(coordinator.editorState.activeSearchHighlightRange)
    }

    func testSearchHighlightCapAndShowAllToggle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlightCap")
        let content = Array(repeating: "hit", count: 120).joined(separator: " ")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: content)
        coordinator.searchQueryText = "hit"

        coordinator.showInlineSearchPanel()

        XCTAssertEqual(coordinator.searchResults.count, 120)
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, 100)
        XCTAssertEqual(coordinator.hiddenSearchHighlightCount, 20)
        XCTAssertTrue(coordinator.canEnableShowAllSearchHighlights)
        XCTAssertTrue(coordinator.canToggleSearchHighlightMode)

        coordinator.toggleShowAllSearchHighlights()
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, 120)
        XCTAssertEqual(coordinator.hiddenSearchHighlightCount, 0)
        XCTAssertTrue(coordinator.searchShowAllHighlights)
        XCTAssertTrue(coordinator.canToggleSearchHighlightMode)
    }

    func testSearchHighlightShowAllDisabledBeyondSafetyThreshold() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlightSafety")
        let initialContent = Array(repeating: "hit", count: 120).joined(separator: " ")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: initialContent)
        coordinator.searchQueryText = "hit"
        coordinator.showInlineSearchPanel()
        coordinator.toggleShowAllSearchHighlights()
        XCTAssertTrue(coordinator.searchShowAllHighlights)

        let largeContent = Array(repeating: "hit", count: coordinator.searchHighlightSafetyThreshold + 1).joined(separator: " ")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: largeContent)
        coordinator.runSearch()

        XCTAssertFalse(coordinator.searchShowAllHighlights)
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, coordinator.searchHighlightCap)
        XCTAssertFalse(coordinator.canEnableShowAllSearchHighlights)
        XCTAssertFalse(coordinator.canToggleSearchHighlightMode)
        XCTAssertNotNil(coordinator.searchHighlightSafetyMessage)

        coordinator.toggleShowAllSearchHighlights()
        XCTAssertFalse(coordinator.searchShowAllHighlights)
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, coordinator.searchHighlightCap)
    }

    func testSearchHighlightPreferencesPersistAcrossCoordinatorInstances() throws {
        let suiteName = "WorkspaceCoordinatorTests.HighlightPrefs.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "SearchHighlightPrefs",
            splitSettingsStore: defaults,
            recentProjectStore: defaults,
            searchPreferenceStore: defaults
        )
        first.updateSearchHighlightCap(180)
        first.updateSearchHighlightSafetyThreshold(3_500)
        try first.projectManager.closeProject()

        let second = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "SearchHighlightPrefs",
            splitSettingsStore: defaults,
            recentProjectStore: defaults,
            searchPreferenceStore: defaults
        )

        XCTAssertEqual(second.searchHighlightCap, 180)
        XCTAssertEqual(second.searchHighlightSafetyThreshold, 3_500)
    }

    func testSearchHighlightPreferenceNormalizationKeepsThresholdAboveCap() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlightPrefNormalization")

        coordinator.updateSearchHighlightCap(5_000)
        XCTAssertEqual(coordinator.searchHighlightCap, 1_000)
        XCTAssertGreaterThan(coordinator.searchHighlightSafetyThreshold, coordinator.searchHighlightCap)

        coordinator.updateSearchHighlightSafetyThreshold(100)
        XCTAssertGreaterThan(coordinator.searchHighlightSafetyThreshold, coordinator.searchHighlightCap)
    }

    func testResetSearchHighlightPreferencesToDefaults() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlightPrefReset")

        coordinator.updateSearchHighlightCap(180)
        coordinator.updateSearchHighlightSafetyThreshold(3_500)
        XCTAssertFalse(coordinator.usesDefaultSearchHighlightPreferences)

        coordinator.resetSearchHighlightPreferencesToDefaults()

        XCTAssertEqual(coordinator.searchHighlightCap, 100)
        XCTAssertEqual(coordinator.searchHighlightSafetyThreshold, 2_000)
        XCTAssertTrue(coordinator.usesDefaultSearchHighlightPreferences)
    }

    func testSearchHighlightHelpVisibilityShowAndDismiss() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlightHelp")

        coordinator.showSearchHighlightHelp()
        XCTAssertFalse(coordinator.isSearchHighlightHelpVisible)

        coordinator.showInlineSearchPanel()
        coordinator.showSearchHighlightHelp()
        XCTAssertTrue(coordinator.isSearchHighlightHelpVisible)

        coordinator.hideSearchHighlightHelp()
        XCTAssertFalse(coordinator.isSearchHighlightHelpVisible)

        coordinator.showSearchHighlightHelp()
        coordinator.hideSearchPanel()
        XCTAssertFalse(coordinator.isSearchHighlightHelpVisible)
    }

    func testClearRecentProjectsRemovesRecentAndLastEntries() throws {
        let suiteName = "WorkspaceCoordinatorTests.ClearRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "RecentClearSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "RecentClearA"))
        XCTAssertTrue(coordinator.canReopenLastProject)
        XCTAssertTrue(coordinator.canClearRecentProjects)
        XCTAssertFalse(coordinator.recentProjects.isEmpty)

        coordinator.clearRecentProjects()

        XCTAssertFalse(coordinator.canReopenLastProject)
        XCTAssertFalse(coordinator.canClearRecentProjects)
        XCTAssertTrue(coordinator.recentProjects.isEmpty)
    }

    func testCleanupMissingRecentProjectsRemovesStaleEntries() throws {
        let suiteName = "WorkspaceCoordinatorTests.CleanupMissingRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let validManager = FileSystemProjectManager()
        _ = try validManager.createProject(name: "CleanupValid", at: tempDir)
        let validURL = try XCTUnwrap(validManager.projectRootURL)
        try validManager.closeProject()

        let missingURL = tempDir.appendingPathComponent("CleanupMissing", isDirectory: true)
        defaults.set([missingURL.path, validURL.path], forKey: "workspace.recentProjects")
        defaults.set(missingURL.path, forKey: "workspace.lastOpenedProjectPath")

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "CleanupSeed",
            recentProjectStore: defaults
        )
        XCTAssertTrue(coordinator.hasStaleRecentProjects)
        XCTAssertTrue(coordinator.recentProjects.contains(where: { $0.name == "CleanupValid" }))

        coordinator.cleanupMissingRecentProjects()

        XCTAssertFalse(coordinator.hasStaleRecentProjects)
        XCTAssertTrue(coordinator.recentProjects.contains(where: { $0.name == "CleanupValid" }))
    }

    func testRecentProjectsSnapshotRestoreSupportsUndo() throws {
        let suiteName = "WorkspaceCoordinatorTests.RecentUndo.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "UndoSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "UndoA"))
        XCTAssertNil(coordinator.createAndOpenProject(named: "UndoB"))
        let before = coordinator.snapshotRecentProjects()
        XCTAssertFalse(before.paths.isEmpty)

        coordinator.clearRecentProjects()
        XCTAssertTrue(coordinator.recentProjects.isEmpty)

        coordinator.restoreRecentProjects(from: before)
        let restoredNames = coordinator.recentProjects.map(\.name)
        XCTAssertTrue(restoredNames.contains("UndoA"))
        XCTAssertTrue(restoredNames.contains("UndoB"))
    }

    func testSaveProjectAsCreatesCopyAndSwitchesContext() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAsSource")
        let sourceURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("save as baseline", at: 0)

        let message = coordinator.saveProjectAs(named: "SaveAsCopy")

        XCTAssertNil(message)
        let copyURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        XCTAssertNotEqual(copyURL, sourceURL)
        XCTAssertEqual(copyURL.lastPathComponent, "SaveAsCopy")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: sceneId), "save as baseline")
    }

    func testSaveProjectAsReturnsConflictMessageWhenDestinationExists() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAsConflictSource")
        let conflictURL = tempDir.appendingPathComponent("SaveAsConflictTarget", isDirectory: true)
        try FileManager.default.createDirectory(at: conflictURL, withIntermediateDirectories: true)

        let message = coordinator.saveProjectAs(named: "SaveAsConflictTarget")

        XCTAssertEqual(message, "Could not save project as: A project named \"SaveAsConflictTarget\" already exists.")
    }

    func testRenameProjectMovesDirectoryAndKeepsProjectOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RenameSource")
        let sourceURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("rename baseline", at: 0)

        let message = coordinator.renameCurrentProject(to: "RenamedProject")

        XCTAssertNil(message)
        let renamedURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        XCTAssertEqual(renamedURL.lastPathComponent, "RenamedProject")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: sceneId), "rename baseline")
    }

    func testRenameProjectReturnsConflictMessageWhenDestinationExists() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RenameConflictSource")
        let conflictURL = tempDir.appendingPathComponent("RenameConflictTarget", isDirectory: true)
        try FileManager.default.createDirectory(at: conflictURL, withIntermediateDirectories: true)

        let message = coordinator.renameCurrentProject(to: "RenameConflictTarget")

        XCTAssertEqual(message, "Could not rename project: A project named \"RenameConflictTarget\" already exists.")
    }

    func testLiveTypingUpdatesSessionWordStatsThroughCoordinatorBinding() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "LiveGoals")
        coordinator.goalsManager.startSession(goal: nil)
        let startingWords = coordinator.editorState.wordCount

        coordinator.editorState.insertText(" hello", at: coordinator.editorState.getCurrentContent().count)

        XCTAssertEqual(coordinator.editorState.wordCount, startingWords + 1)
        XCTAssertEqual(coordinator.goalsManager.sessionWordsWritten, 1)
        XCTAssertEqual(coordinator.goalsManager.sessionGrossWords, 1)
    }

    func testOpenSplitFromCurrentContextUsesCurrentSceneWhenNoSidebarSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitFromCurrent")
        coordinator.navigationState.selectedSceneId = nil

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 900)

        XCTAssertNil(notice)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, coordinator.editorState.currentSceneId)
    }

    func testOpenSplitFromCurrentContextReturnsNarrowWindowNotice() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitNarrow")

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 480)

        XCTAssertEqual(notice, "Window too narrow for side-by-side split. Using stacked layout.")
        XCTAssertEqual(coordinator.splitEditorState.orientation, .horizontal)
    }

    func testHandleModeChangeClosesOpenSplitWhenEnteringModular() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CloseOnMode")
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 900)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        coordinator.handleModeChange(.modular)

        XCTAssertFalse(coordinator.splitEditorState.isSplit)
    }

    func testOpenSplitFromCurrentContextSkipsStaleSelectionAndUsesValidFallback() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "StaleSelection")
        let validSceneId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first?.id)
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 900)

        XCTAssertNil(notice)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, validSceneId)
    }

    func testOpenSplitFromCurrentContextReturnsNilWhenNoValidScenesExist() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NoScenes")
        let existingSceneId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first?.id)
        try coordinator.projectManager.deleteItem(id: existingSceneId, type: .scene)
        coordinator.linearState.reloadSequence()
        coordinator.navigationState.selectedSceneId = nil
        coordinator.editorState.currentSceneId = existingSceneId

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 900)

        XCTAssertNil(notice)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)
        XCTAssertFalse(coordinator.canToggleSplitEditor)
    }

    func testToggleSplitOpensThenClosesSplit() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ToggleSplit")

        let openNotice = coordinator.toggleSplit(windowWidth: 900)
        XCTAssertNil(openNotice)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        let closeNotice = coordinator.toggleSplit(windowWidth: 900)
        XCTAssertNil(closeNotice)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)
    }

    func testToggleSplitReturnsNoticeWhenFallbackApplied() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ToggleNarrow")

        let notice = coordinator.toggleSplit(windowWidth: 480)

        XCTAssertEqual(notice, "Window too narrow for side-by-side split. Using stacked layout.")
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertEqual(coordinator.splitEditorState.orientation, .horizontal)
    }

    func testCanToggleSplitEditorAllowsClosingOutsideLinearModeWhenAlreadySplit() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ToggleSplitCloseInModular")
        let sceneId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first?.id)
        coordinator.splitEditorState.openSplit(sceneId: sceneId)
        coordinator.modeController.switchTo(.modular)

        XCTAssertTrue(coordinator.canToggleSplitEditor)
    }

    func testSplitSettingsAreScopedPerProjectPath() throws {
        let suiteName = "WorkspaceCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let projectA = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ProjectA",
            splitSettingsStore: defaults
        )
        projectA.splitEditorState.orientation = .horizontal
        projectA.splitEditorState.splitRatio = 0.33

        let projectB = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ProjectB",
            splitSettingsStore: defaults
        )
        XCTAssertEqual(projectB.splitEditorState.orientation, .vertical)
        XCTAssertEqual(projectB.splitEditorState.splitRatio, 0.5, accuracy: 0.0001)

        try projectA.projectManager.closeProject()
        try projectB.projectManager.closeProject()

        let reopenedProjectA = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ProjectA",
            splitSettingsStore: defaults
        )
        XCTAssertEqual(reopenedProjectA.splitEditorState.orientation, .horizontal)
        XCTAssertEqual(reopenedProjectA.splitEditorState.splitRatio, 0.33, accuracy: 0.0001)
    }

    func testCreateChapterAddsTopLevelChapterAndSelectsIt() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapter")
        let before = coordinator.projectManager.getManifest().hierarchy.chapters.count

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertEqual(manifest.hierarchy.chapters.count, before + 1)
        let created = try XCTUnwrap(manifest.hierarchy.chapters.max(by: { $0.sequenceIndex < $1.sequenceIndex }))
        XCTAssertEqual(coordinator.navigationState.selectedChapterId, created.id)
    }

    func testCreateChapterFallsBackToGeneratedTitleWhenInputIsWhitespace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterWhitespaceTitle")
        let beforeCount = coordinator.projectManager.getManifest().hierarchy.chapters.count

        let message = coordinator.createChapter(title: "   \n\t ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertEqual(manifest.hierarchy.chapters.count, beforeCount + 1)
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter \(beforeCount + 1)" }))
    }

    func testCreateChapterTrimsSurroundingWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterTrimmedTitle")

        let message = coordinator.createChapter(title: "  Trimmed Chapter  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Trimmed Chapter" }))
    }

    func testCreateChapterCollapsesInternalWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterCollapsedWhitespace")

        let message = coordinator.createChapter(title: "  Chapter\t\tName \n  Final  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter Name Final" }))
    }

    func testCreateChapterNormalizesNonBreakingSpacesInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterNBSPTitle")

        let message = coordinator.createChapter(title: "Chapter\u{00A0}\u{00A0}Name")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter Name" }))
    }

    func testCreateChapterGeneratedTitleFillsNumericGaps() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterGaps")
        _ = coordinator.createChapter(title: "Chapter 3")

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter 2" }))
    }

    func testCreateChapterGeneratedTitleParsesLegacySpacingAndCase() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterLegacySpacing")
        _ = coordinator.createChapter(title: "chapter   2")

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter 3" }))
    }

    func testCreateChapterGeneratedTitleParsesLegacyNonBreakingSpace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterLegacyNBSP")
        _ = coordinator.createChapter(title: "Chapter\u{00A0}2")

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter 3" }))
    }

    func testCreateSceneUsesSelectedChapterAndSelectsNewScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneSelectedChapter")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        coordinator.navigationState.selectedChapterId = chapterId

        let message = coordinator.createScene(title: "Scene Via Action")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        let added = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.title == "Scene Via Action" }))
        XCTAssertEqual(added.parentChapterId, chapterId)
        XCTAssertEqual(coordinator.navigationState.selectedSceneId, added.id)
        XCTAssertEqual(coordinator.editorState.currentSceneId, added.id)
    }

    func testCreateSceneFallsBackToGeneratedTitleWhenInputIsWhitespace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneWhitespaceTitle")
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene(title: "   \n\t ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        let created = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(created.title, "Scene 1")
    }

    func testCreateSceneUsesGeneratedTitleWhenNoTitleProvided() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneGeneratedTitle")
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        let created = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(created.title, "Scene 1")
    }

    func testCreateSceneGeneratedTitleFillsNumericGaps() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneGaps")
        _ = coordinator.createScene(title: "Scene 1")
        _ = coordinator.createScene(title: "Scene 3")

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene 2" }))
    }

    func testCreateSceneGeneratedTitleParsesLegacySpacingAndCase() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneLegacySpacing")
        _ = coordinator.createScene(title: "Scene 1")
        _ = coordinator.createScene(title: "scene   2")

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene 3" }))
    }

    func testCreateSceneGeneratedTitleParsesLegacyNonBreakingSpace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneLegacyNBSP")
        _ = coordinator.createScene(title: "Scene 1")
        _ = coordinator.createScene(title: "Scene\u{00A0}2")

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene 3" }))
    }

    func testCreateSceneTrimsSurroundingWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneTrimmedTitle")

        let message = coordinator.createScene(title: "  Trimmed Title  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Trimmed Title" }))
    }

    func testCreateSceneCollapsesInternalWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneCollapsedWhitespace")

        let message = coordinator.createScene(title: "  Scene\t\tTitle \n  Final  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene Title Final" }))
    }

    func testCreateSceneNormalizesNonBreakingSpacesInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneNBSPTitle")

        let message = coordinator.createScene(title: "Scene\u{00A0}\u{00A0}Title")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene Title" }))
    }

    func testCreateSceneCreatesFallbackChapterWhenHierarchyIsEmpty() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneFallbackChapter")
        let initialChapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        try coordinator.projectManager.deleteItem(id: initialChapterId, type: .chapter)
        coordinator.linearState.reloadSequence()

        let message = coordinator.createScene(title: "Recovered Scene")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertEqual(manifest.hierarchy.chapters.count, 1)
        let createdScene = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.title == "Recovered Scene" }))
        XCTAssertNotNil(createdScene.parentChapterId)
    }

    func testNavigateToNextSceneAdvancesInLinearMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NextSceneCommand")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        _ = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)
        coordinator.editorState.navigateToScene(id: firstScene)

        let moved = coordinator.navigateToNextScene()

        XCTAssertTrue(moved)
        XCTAssertNotEqual(coordinator.editorState.currentSceneId, firstScene)
    }

    func testNavigateToPreviousSceneReturnsFalseAtBeginning() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "PreviousSceneBoundary")
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)
        coordinator.editorState.navigateToScene(id: firstScene)

        let moved = coordinator.navigateToPreviousScene()

        XCTAssertFalse(moved)
        XCTAssertEqual(coordinator.editorState.currentSceneId, firstScene)
    }

    func testNavigateCommandsNoOpOutsideLinearMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NavigationModeGate")
        coordinator.setMode(.modular)
        let before = coordinator.editorState.currentSceneId

        let movedNext = coordinator.navigateToNextScene()
        let movedPrevious = coordinator.navigateToPreviousScene()

        XCTAssertFalse(movedNext)
        XCTAssertFalse(movedPrevious)
        XCTAssertEqual(coordinator.editorState.currentSceneId, before)
    }

    func testNavigationAvailabilityReflectsLinearBoundaries() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NavigationAvailability")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)

        coordinator.editorState.navigateToScene(id: firstScene)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertTrue(coordinator.canNavigateToNextScene)

        coordinator.editorState.navigateToScene(id: secondScene.id)
        XCTAssertTrue(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)
    }

    func testNavigationAvailabilityDisabledOutsideLinearMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NavigationAvailabilityMode")
        coordinator.setMode(.modular)

        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)
    }

    func testCommandAvailabilityMatrixAcrossBoundaryStates() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandAvailabilityMatrix")

        // Baseline: one-scene linear project.
        XCTAssertTrue(coordinator.canToggleSplitEditor)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        // Two-scene linear project at first scene.
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)
        coordinator.editorState.navigateToScene(id: firstScene)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertTrue(coordinator.canNavigateToNextScene)

        // Two-scene linear project at second scene.
        coordinator.editorState.navigateToScene(id: secondScene.id)
        XCTAssertTrue(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        // Modular mode with no split open disables toggle and navigation.
        coordinator.setMode(.modular)
        XCTAssertFalse(coordinator.canToggleSplitEditor)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        // Split open remains closable outside linear mode.
        coordinator.modeController.switchTo(.linear)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        coordinator.modeController.switchTo(.modular)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertTrue(coordinator.canToggleSplitEditor)

        // Stale selected/current scene IDs still allow split via valid sequence fallback.
        coordinator.splitEditorState.closeSplit()
        coordinator.modeController.switchTo(.linear)
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()
        XCTAssertTrue(coordinator.canToggleSplitEditor)

        // No project means all command availability is disabled.
        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.canToggleSplitEditor)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)
    }

    func testSelectBreadcrumbChapterNavigatesChapterAndFirstScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BreadcrumbChapter")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)

        let chapterCrumb = BreadcrumbItem(id: chapterId, title: "Chapter", type: .chapter)
        coordinator.select(breadcrumb: chapterCrumb)

        XCTAssertEqual(coordinator.navigationState.selectedChapterId, chapterId)
        XCTAssertNotNil(coordinator.navigationState.selectedSceneId)
    }

    func testSelectBreadcrumbSceneNavigatesEditorAndNavigation() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BreadcrumbScene")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Breadcrumb Target")
        coordinator.linearState.reloadSequence()

        let sceneCrumb = BreadcrumbItem(id: scene.id, title: scene.title, type: .scene)
        coordinator.select(breadcrumb: sceneCrumb)

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, scene.id)
        XCTAssertEqual(coordinator.editorState.currentSceneId, scene.id)
    }

    func testSaveProjectNowPersistsManifestChanges() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveProject")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        _ = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Unsaved")

        let saveMessage = coordinator.saveProjectNow()

        XCTAssertNil(saveMessage)
        let root = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let manifestOnDisk = try ManifestCoder.read(from: root.appendingPathComponent("manifest.json"))
        XCTAssertTrue(manifestOnDisk.hierarchy.scenes.contains(where: { $0.title == "Unsaved" }))
    }

    func testSaveProjectNowPersistsDirtyEditorContent() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveEditorContent")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("manual save content", at: 0)

        let saveMessage = coordinator.saveProjectNow()

        XCTAssertNil(saveMessage)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(diskContent, "manual save content")
    }

    func testSaveProjectNowPersistsSplitPaneDirtyContent() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveSplitContent")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Secondary")
        coordinator.linearState.reloadSequence()
        coordinator.editorState.navigateToScene(id: scene.id)
        coordinator.navigationState.navigateTo(sceneId: scene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        let secondarySceneId = try XCTUnwrap(coordinator.splitEditorState.secondarySceneId)
        coordinator.splitEditorState.secondaryEditor.insertText("split pane save", at: 0)

        let saveMessage = coordinator.saveProjectNow()

        XCTAssertNil(saveMessage)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: secondarySceneId)
        XCTAssertEqual(diskContent, "split pane save")
    }

    func testSaveProjectNowReturnsErrorMessageWhenManifestWriteFails() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveFailureMessage")
        coordinator.projectManager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: "WorkspaceCoordinatorTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Simulated manifest write failure"
            ])
        }

        let message = coordinator.saveProjectNow()

        XCTAssertEqual(message, "Could not save project: Simulated manifest write failure")
    }

    func testHasUnsavedChangesReflectsEditorDirtyAndSave() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "DirtyIndicator")
        XCTAssertFalse(coordinator.hasUnsavedChanges)

        coordinator.editorState.insertText("dirty", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
    }

    func testCanSaveProjectTracksUnsavedState() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CanSaveState")
        XCTAssertFalse(coordinator.canSaveProject)

        coordinator.editorState.insertText("dirty", at: 0)
        XCTAssertTrue(coordinator.canSaveProject)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.canSaveProject)
    }

    func testSaveAvailabilityMatrixAcrossEditorSplitAndNoProjectTransitions() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAvailabilityMatrix")
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)

        // Primary editor dirty state enables save.
        coordinator.editorState.insertText("dirty primary", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)
        XCTAssertTrue(coordinator.canSaveProject)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)

        // Split secondary dirty state enables save.
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        coordinator.editorState.navigateToScene(id: secondScene.id)
        coordinator.navigationState.navigateTo(sceneId: secondScene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        coordinator.splitEditorState.secondaryEditor.insertText("dirty secondary", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)
        XCTAssertTrue(coordinator.canSaveProject)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)

        // No project disables save availability regardless of prior state.
        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)
    }

    func testHasUnsavedChangesReflectsSplitPaneDirtyState() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "DirtySplitIndicator")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "SplitDirtyScene")
        coordinator.linearState.reloadSequence()
        coordinator.navigationState.navigateTo(sceneId: scene.id)
        coordinator.editorState.navigateToScene(id: scene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)

        coordinator.splitEditorState.secondaryEditor.insertText("dirty split", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
    }

    func testCreateBackupNowAddsBackupArchive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackupNow")
        let before = coordinator.projectManager.listBackups().count

        let message = coordinator.createBackupNow()

        XCTAssertNotNil(message)
        let after = coordinator.projectManager.listBackups()
        XCTAssertEqual(after.count, before + 1)
        XCTAssertTrue(message?.contains("Backup created") == true)
    }

    func testCreateBackupNowPersistsDirtyEditorBeforeArchiving() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackupFlush")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("backup flush content", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)

        let message = coordinator.createBackupNow()

        XCTAssertNotNil(message)
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(diskContent, "backup flush content")
    }

    func testCreateBackupNowReturnsErrorMessageWhenManifestWriteFails() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackupFailureMessage")
        coordinator.projectManager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: "WorkspaceCoordinatorTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Simulated manifest write failure"
            ])
        }

        let message = coordinator.createBackupNow()

        XCTAssertEqual(message, "Could not create backup: Simulated manifest write failure")
    }

    func testSaveAndBackupNowPersistsDirtyEditorAndCreatesBackup() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAndBackup")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        let before = coordinator.projectManager.listBackups().count
        coordinator.editorState.insertText("save and backup content", at: 0)

        let message = coordinator.saveAndBackupNow()

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("Project saved and backup created") == true)
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertEqual(coordinator.projectManager.listBackups().count, before + 1)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(diskContent, "save and backup content")
    }

    func testSaveAndBackupNowPersistsSplitPaneDirtyContentAndCreatesBackup() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAndBackupSplit")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Split Backup Scene")
        coordinator.linearState.reloadSequence()
        coordinator.editorState.navigateToScene(id: scene.id)
        coordinator.navigationState.navigateTo(sceneId: scene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        let secondarySceneId = try XCTUnwrap(coordinator.splitEditorState.secondarySceneId)
        coordinator.splitEditorState.secondaryEditor.insertText("split save+backup", at: 0)
        let before = coordinator.projectManager.listBackups().count

        let message = coordinator.saveAndBackupNow()

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("Project saved and backup created") == true)
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertEqual(coordinator.projectManager.listBackups().count, before + 1)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: secondarySceneId)
        XCTAssertEqual(diskContent, "split save+backup")
    }

    func testSaveAndBackupNowReturnsErrorMessageWhenManifestWriteFails() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAndBackupFailureMessage")
        coordinator.projectManager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: "WorkspaceCoordinatorTests", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Simulated manifest write failure"
            ])
        }

        let message = coordinator.saveAndBackupNow()

        XCTAssertEqual(message, "Could not save and back up project: Simulated manifest write failure")
    }

    func testActionsFailGracefullyWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NoProjectActions")
        try coordinator.projectManager.closeProject()

        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)
        XCTAssertFalse(coordinator.canToggleSplitEditor)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        XCTAssertEqual(coordinator.createChapter(), "Could not create chapter: No project is currently open.")
        XCTAssertEqual(coordinator.createScene(), "Could not create scene: No project is currently open.")
        XCTAssertEqual(coordinator.saveProjectNow(), "Could not save project: No project is currently open.")
        XCTAssertEqual(coordinator.createBackupNow(), "Could not create backup: No project is currently open.")
        XCTAssertEqual(coordinator.saveAndBackupNow(), "Could not save and back up project: No project is currently open.")
        XCTAssertEqual(coordinator.toggleSplitForCommand(), "No project is currently open.")
        XCTAssertFalse(coordinator.navigateToNextScene())
        XCTAssertFalse(coordinator.navigateToPreviousScene())
    }

    func testSplitToggleAvailabilityStaysDisabledAfterCloseEvenIfSplitRemainsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitAvailabilityAfterClose")
        XCTAssertNil(coordinator.toggleSplit(windowWidth: 1200))
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        try coordinator.projectManager.closeProject()

        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertFalse(coordinator.canToggleSplitEditor)
        XCTAssertEqual(coordinator.toggleSplitForCommand(), "No project is currently open.")
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
    }

    func testHasOpenProjectReflectsProjectLifecycle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "OpenProjectState")
        XCTAssertTrue(coordinator.hasOpenProject)

        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.hasOpenProject)
    }

    func testModeSwitchAvailabilityReflectsActiveMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ModeSwitchAvailability")
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        coordinator.setMode(.modular)
        XCTAssertTrue(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
    }

    func testModeSwitchAvailabilityMatrixAcrossNoOpAndSplitTransitions() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ModeSwitchMatrix")

        // Baseline linear state.
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // Same-mode no-op preserves availability.
        coordinator.setMode(.linear)
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // Split-open linear still allows switching to modular.
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // Switching to modular flips availability and closes split.
        coordinator.setMode(.modular)
        XCTAssertTrue(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)

        // Same-mode no-op in modular preserves availability.
        coordinator.setMode(.modular)
        XCTAssertTrue(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)

        // Switching back to linear flips availability again.
        coordinator.setMode(.linear)
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // No-project state disables both switches.
        try? coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
    }

    func testModeSwitchAvailabilityDisabledWithoutOpenProject() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ModeSwitchNoProject")
        try coordinator.projectManager.closeProject()

        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
    }

    func testSetModeToModularClosesOpenSplit() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SetModeClosesSplit")
        let openMessage = coordinator.toggleSplit(windowWidth: 1200)
        XCTAssertNil(openMessage)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        coordinator.setMode(.modular)

        XCTAssertEqual(coordinator.modeController.activeMode, .modular)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)
    }

    func testSetModeNoOpWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SetModeNoProject")
        try coordinator.projectManager.closeProject()

        coordinator.setMode(.modular)

        XCTAssertEqual(coordinator.modeController.activeMode, .linear)
    }

    func testHandleScenePhaseActiveDoesNotStartSessionWithoutOpenProject() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ScenePhaseNoProject")
        try coordinator.projectManager.closeProject()

        coordinator.handleScenePhase(.active)

        XCTAssertNil(coordinator.goalsManager.sessionStartTime)
        XCTAssertFalse(coordinator.goalsManager.isTimerRunning)
    }

    func testSelectNodeNoOpWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectNodeNoProject")
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()
        let beforeSelectedScene = coordinator.navigationState.selectedSceneId
        let beforeCurrentScene = coordinator.editorState.currentSceneId
        try coordinator.projectManager.closeProject()

        let node = SidebarNode(
            id: UUID(),
            title: "Scene",
            level: .scene,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: node)

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, beforeSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, beforeCurrentScene)
    }

    func testSelectBreadcrumbNoOpWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectBreadcrumbNoProject")
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()
        let beforeSelectedScene = coordinator.navigationState.selectedSceneId
        let beforeCurrentScene = coordinator.editorState.currentSceneId
        try coordinator.projectManager.closeProject()

        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Scene", type: .scene))

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, beforeSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, beforeCurrentScene)
    }

    func testSelectNodeIgnoresStaleSceneAndChapterIds() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleNode")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.navigationState.navigateTo(sceneId: sceneId)
        let originalSelectedScene = coordinator.navigationState.selectedSceneId
        let originalCurrentScene = coordinator.editorState.currentSceneId
        let originalSelectedChapter = coordinator.navigationState.selectedChapterId

        let staleSceneNode = SidebarNode(
            id: UUID(),
            title: "Stale Scene",
            level: .scene,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: staleSceneNode)

        let staleChapterNode = SidebarNode(
            id: UUID(),
            title: "Stale Chapter",
            level: .chapter,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: staleChapterNode)

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, originalSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, originalCurrentScene)
        XCTAssertEqual(coordinator.navigationState.selectedChapterId, originalSelectedChapter)
    }

    func testSelectNodeIgnoresStaleSceneWithoutChangingSplitPaneTargets() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleNodeSplit")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondaryScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Secondary")
        coordinator.splitEditorState.openSplit(sceneId: secondaryScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

        let staleSceneNode = SidebarNode(
            id: UUID(),
            title: "Stale Scene",
            level: .scene,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: staleSceneNode)

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }

    func testSelectBreadcrumbIgnoresStaleSceneAndChapterIds() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleBreadcrumb")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.navigationState.navigateTo(sceneId: sceneId)
        let originalSelectedScene = coordinator.navigationState.selectedSceneId
        let originalCurrentScene = coordinator.editorState.currentSceneId
        let originalSelectedChapter = coordinator.navigationState.selectedChapterId

        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Stale Scene", type: .scene))
        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Stale Chapter", type: .chapter))

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, originalSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, originalCurrentScene)
        XCTAssertEqual(coordinator.navigationState.selectedChapterId, originalSelectedChapter)
    }

    func testSelectBreadcrumbIgnoresStaleSceneWithoutChangingSplitPaneTargets() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleBreadcrumbSplit")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondaryScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Secondary")
        coordinator.splitEditorState.openSplit(sceneId: secondaryScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Stale Scene", type: .scene))

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }
}
