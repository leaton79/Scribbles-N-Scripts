import Foundation

// MARK: - Core Content Hierarchy

struct Project: Codable, Identifiable {
    let id: UUID
    var name: String
    var manuscript: Manuscript
    var settings: ProjectSettings
    var tags: [Tag]
    var snapshots: [Snapshot]
    var entities: [Entity]
    var sources: [Source]
    var notes: [Note]
    var compilePresets: [CompilePreset]
    var trash: [TrashedItem]
    let createdAt: Date
    var modifiedAt: Date
}

struct Manuscript: Codable, Identifiable {
    let id: UUID
    var title: String
    var parts: [Part]
    var chapters: [Chapter]
    var stagingArea: [Scene]
}

struct Part: Codable, Identifiable {
    let id: UUID
    var title: String
    var synopsis: String
    var chapters: [Chapter]
    var sequenceIndex: Int
}

struct Chapter: Codable, Identifiable {
    let id: UUID
    var title: String
    var synopsis: String
    var scenes: [Scene]
    var status: ContentStatus
    var sequenceIndex: Int
    var goalWordCount: Int?
}

struct Scene: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var synopsis: String
    var status: ContentStatus
    var tags: [UUID]
    var colorLabel: ColorLabel?
    var metadata: [String: String]
    var sequenceIndex: Int
    var wordCount: Int
    let createdAt: Date
    var modifiedAt: Date
}

enum ContentStatus: String, Codable, CaseIterable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case firstDraft = "First Draft"
    case revised = "Revised"
    case final_ = "Final"
}

enum ColorLabel: String, Codable, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray
    case none
}

// MARK: - Metadata & Organization

struct Tag: Codable, Identifiable {
    let id: UUID
    var name: String
    var color: String?
}

struct CustomMetadataField: Codable, Identifiable {
    let id: UUID
    var name: String
    var fieldType: MetadataFieldType
}

enum MetadataFieldType: String, Codable, CaseIterable {
    case text
    case singleSelect
    case multiSelect
}

// MARK: - Version Control

struct Snapshot: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var wordCount: Int
    var isBaseline: Bool
}

struct SnapshotDiff: Codable {
    let snapshotId: UUID
    var sceneDiffs: [SceneDiff]
    var hierarchyChanges: HierarchyDiff
}

struct SceneDiff: Codable {
    let sceneId: UUID
    var changeType: DiffChangeType
    var textDiff: String?
}

enum DiffChangeType: String, Codable, CaseIterable {
    case added
    case removed
    case modified
    case unchanged
}

struct HierarchyDiff: Codable {
    var addedScenes: [UUID]
    var removedScenes: [UUID]
    var reorderedChapters: [ChapterReorder]
    var reorderedScenes: [SceneReorder]
}

struct ChapterReorder: Codable {
    var chapterId: UUID
    var oldIndex: Int
    var newIndex: Int
}

struct SceneReorder: Codable {
    var sceneId: UUID
    var oldChapterId: UUID
    var newChapterId: UUID
    var oldIndex: Int
    var newIndex: Int
}

// MARK: - Trash

struct TrashedItem: Codable, Identifiable {
    let id: UUID
    var originalType: TrashedItemType
    var originalParentId: UUID?
    var originalIndex: Int
    var content: TrashedContent
    let trashedAt: Date
}

enum TrashedContent: Codable {
    case scene(Scene)
    case chapter(Chapter)
    case part(Part)
}

enum TrashedItemType: String, Codable, CaseIterable {
    case scene
    case chapter
    case part
}

// MARK: - Entity Tracking (v1.1)

struct Entity: Codable, Identifiable {
    let id: UUID
    var entityType: EntityType
    var name: String
    var aliases: [String]
    var fields: [String: String]
    var sceneMentions: [UUID]
    var relationships: [EntityRelationship]
    var notes: String
}

enum EntityType: String, Codable, CaseIterable {
    case character
    case location
    case object
    case faction
    case concept
    case custom
}

struct EntityRelationship: Codable {
    let targetEntityId: UUID
    var label: String
    var isBidirectional: Bool
}

// MARK: - Timeline (v1.1)

struct TimelineEvent: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var track: String
    var position: TimelinePosition
    var linkedSceneIds: [UUID]
    var color: String?
}

enum TimelinePosition: Codable {
    case absolute(Date)
    case relative(order: Int)
}

// MARK: - Sources & Citations (v1.1 lightweight -> v2.0 full)

struct Source: Codable, Identifiable {
    let id: UUID
    var title: String
    var author: String?
    var date: String?
    var url: String?
    var publication: String?
    var volume: String?
    var pages: String?
    var doi: String?
    var notes: String
    var citationKey: String
}

// MARK: - Notes (v2.0)

struct Note: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var folder: String?
    var tags: [UUID]
    var linkedSceneIds: [UUID]
    var attachments: [NoteAttachment]
    let createdAt: Date
    var modifiedAt: Date
}

struct NoteAttachment: Codable, Identifiable {
    let id: UUID
    var filename: String
    var mimeType: String
}

// MARK: - Export & Compile (v1.1 basic -> v2.0 full)

struct CompilePreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var format: ExportFormat
    var includedSectionIds: [UUID]
    var styleOverrides: StyleConfig
    var frontMatter: FrontMatterConfig
    var backMatter: BackMatterConfig
}

enum ExportFormat: String, Codable, CaseIterable {
    case markdown
    case docx
    case pdf
    case epub
    case html
}

struct StyleConfig: Codable {
    var fontFamily: String
    var fontSize: Int
    var lineSpacing: Double
    var paragraphIndent: Double
    var chapterHeadingStyle: String
    var sceneBreakMarker: String
    var pageMargins: Margins
}

struct Margins: Codable {
    var top: Double
    var bottom: Double
    var left: Double
    var right: Double
}

struct FrontMatterConfig: Codable {
    var includeTitlePage: Bool
    var includeCopyright: Bool
    var includeDedication: Bool
    var includeTableOfContents: Bool
    var titlePageContent: TitlePageContent?
    var copyrightText: String?
    var dedicationText: String?
}

struct TitlePageContent: Codable {
    var title: String
    var subtitle: String?
    var author: String
}

struct BackMatterConfig: Codable {
    var includeAppendices: Bool
    var includeAboutAuthor: Bool
    var includeBibliography: Bool
    var aboutAuthorText: String?
    var appendices: [AppendixEntry]
}

struct AppendixEntry: Codable {
    var title: String
    var content: String
}

// MARK: - Project Settings

struct ProjectSettings: Codable {
    var autosaveIntervalSeconds: Int
    var backupIntervalMinutes: Int
    var backupRetentionCount: Int
    var backupLocation: String?
    var customMetadataFields: [CustomMetadataField]
    var customStatusOptions: [String]?
    var editorFont: String
    var editorFontSize: Int
    var editorLineHeight: Double
    var theme: AppTheme
    var defaultColorLabelNames: [ColorLabel: String]
}

enum AppTheme: String, Codable, CaseIterable {
    case light
    case dark
    case system
}
