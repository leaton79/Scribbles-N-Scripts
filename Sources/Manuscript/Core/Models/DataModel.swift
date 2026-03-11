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
    var timelineEvents: [TimelineEvent] = []
    var notes: [Note]
    var scratchpadItems: [ScratchpadItem] = []
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
    var options: [String] = []
}

enum MetadataFieldType: String, Codable, CaseIterable {
    case text
    case singleSelect
    case multiSelect
    case number
    case date
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
    var attachments: [ResearchAttachment] = []
    var linkedSceneIds: [UUID] = []
    var linkedEntityIds: [UUID] = []
    var linkedNoteIds: [UUID] = []
}

extension Source {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case date
        case url
        case publication
        case volume
        case pages
        case doi
        case notes
        case citationKey
        case attachments
        case linkedSceneIds
        case linkedEntityIds
        case linkedNoteIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        publication = try container.decodeIfPresent(String.self, forKey: .publication)
        volume = try container.decodeIfPresent(String.self, forKey: .volume)
        pages = try container.decodeIfPresent(String.self, forKey: .pages)
        doi = try container.decodeIfPresent(String.self, forKey: .doi)
        notes = try container.decode(String.self, forKey: .notes)
        citationKey = try container.decode(String.self, forKey: .citationKey)
        attachments = try container.decodeIfPresent([ResearchAttachment].self, forKey: .attachments) ?? []
        linkedSceneIds = try container.decodeIfPresent([UUID].self, forKey: .linkedSceneIds) ?? []
        linkedEntityIds = try container.decodeIfPresent([UUID].self, forKey: .linkedEntityIds) ?? []
        linkedNoteIds = try container.decodeIfPresent([UUID].self, forKey: .linkedNoteIds) ?? []
    }
}

// MARK: - Notes (v2.0)

struct Note: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var folder: String?
    var tags: [UUID]
    var linkedSceneIds: [UUID]
    var linkedEntityIds: [UUID]
    var attachments: [NoteAttachment]
    let createdAt: Date
    var modifiedAt: Date
}

struct NoteAttachment: Codable, Identifiable {
    let id: UUID
    var filename: String
    var mimeType: String
}

// MARK: - Scratchpad / Clipboard (v2.0)

struct ScratchpadItem: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var kind: ScratchpadItemKind
    let createdAt: Date
    var modifiedAt: Date
    var lastUsedAt: Date?
}

enum ScratchpadItemKind: String, Codable, CaseIterable {
    case scratch
    case clipboard
}

struct ResearchAttachment: Codable, Identifiable {
    let id: UUID
    var filename: String
    var storedFilename: String
    var mimeType: String
    let importedAt: Date
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
    var htmlTheme: CompileHTMLTheme
    var pageSize: CompilePageSize
    var templateStyle: CompileTemplateStyle
    var pageMargins: Margins
    var stylesheetName: String?
    var customCSS: String?
}

enum CompileHTMLTheme: String, Codable, CaseIterable {
    case parchment
    case midnight
    case editorial
}

enum CompilePageSize: String, Codable, CaseIterable {
    case letter
    case a4
    case trade
}

enum CompileTemplateStyle: String, Codable, CaseIterable {
    case classic
    case modern
    case manuscript
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
    var includeStagingArea: Bool
    var languageCode: String?
    var publisherName: String?
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
    var sectionOrder: CompileSectionOrder
    var aboutAuthorText: String?
    var bibliographyText: String?
    var appendices: [AppendixEntry]
}

enum CompileSectionOrder: String, Codable, CaseIterable {
    case manuscript
    case reverse
    case alphabetical
}

struct AppendixEntry: Codable {
    var title: String
    var content: String
}

extension Note {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case folder
        case tags
        case linkedSceneIds
        case linkedEntityIds
        case attachments
        case createdAt
        case modifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        folder = try container.decodeIfPresent(String.self, forKey: .folder)
        tags = try container.decodeIfPresent([UUID].self, forKey: .tags) ?? []
        linkedSceneIds = try container.decodeIfPresent([UUID].self, forKey: .linkedSceneIds) ?? []
        linkedEntityIds = try container.decodeIfPresent([UUID].self, forKey: .linkedEntityIds) ?? []
        attachments = try container.decodeIfPresent([NoteAttachment].self, forKey: .attachments) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
    }
}

extension StyleConfig {
    private enum CodingKeys: String, CodingKey {
        case fontFamily
        case fontSize
        case lineSpacing
        case paragraphIndent
        case chapterHeadingStyle
        case sceneBreakMarker
        case htmlTheme
        case pageSize
        case templateStyle
        case pageMargins
        case stylesheetName
        case customCSS
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontFamily = try container.decode(String.self, forKey: .fontFamily)
        fontSize = try container.decode(Int.self, forKey: .fontSize)
        lineSpacing = try container.decode(Double.self, forKey: .lineSpacing)
        paragraphIndent = try container.decodeIfPresent(Double.self, forKey: .paragraphIndent) ?? 0
        chapterHeadingStyle = try container.decode(String.self, forKey: .chapterHeadingStyle)
        sceneBreakMarker = try container.decode(String.self, forKey: .sceneBreakMarker)
        htmlTheme = try container.decodeIfPresent(CompileHTMLTheme.self, forKey: .htmlTheme) ?? .parchment
        pageSize = try container.decodeIfPresent(CompilePageSize.self, forKey: .pageSize) ?? .letter
        templateStyle = try container.decodeIfPresent(CompileTemplateStyle.self, forKey: .templateStyle) ?? .classic
        pageMargins = try container.decodeIfPresent(Margins.self, forKey: .pageMargins) ?? Margins(top: 1, bottom: 1, left: 1, right: 1)
        stylesheetName = try container.decodeIfPresent(String.self, forKey: .stylesheetName)
        customCSS = try container.decodeIfPresent(String.self, forKey: .customCSS)
    }
}

extension FrontMatterConfig {
    private enum CodingKeys: String, CodingKey {
        case includeTitlePage
        case includeCopyright
        case includeDedication
        case includeTableOfContents
        case includeStagingArea
        case languageCode
        case publisherName
        case titlePageContent
        case copyrightText
        case dedicationText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeTitlePage = try container.decode(Bool.self, forKey: .includeTitlePage)
        includeCopyright = try container.decode(Bool.self, forKey: .includeCopyright)
        includeDedication = try container.decode(Bool.self, forKey: .includeDedication)
        includeTableOfContents = try container.decode(Bool.self, forKey: .includeTableOfContents)
        includeStagingArea = try container.decodeIfPresent(Bool.self, forKey: .includeStagingArea) ?? false
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode)
        publisherName = try container.decodeIfPresent(String.self, forKey: .publisherName)
        titlePageContent = try container.decodeIfPresent(TitlePageContent.self, forKey: .titlePageContent)
        copyrightText = try container.decodeIfPresent(String.self, forKey: .copyrightText)
        dedicationText = try container.decodeIfPresent(String.self, forKey: .dedicationText)
    }
}

extension BackMatterConfig {
    private enum CodingKeys: String, CodingKey {
        case includeAppendices
        case includeAboutAuthor
        case includeBibliography
        case sectionOrder
        case aboutAuthorText
        case bibliographyText
        case appendices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeAppendices = try container.decode(Bool.self, forKey: .includeAppendices)
        includeAboutAuthor = try container.decode(Bool.self, forKey: .includeAboutAuthor)
        includeBibliography = try container.decode(Bool.self, forKey: .includeBibliography)
        sectionOrder = try container.decodeIfPresent(CompileSectionOrder.self, forKey: .sectionOrder) ?? .manuscript
        aboutAuthorText = try container.decodeIfPresent(String.self, forKey: .aboutAuthorText)
        bibliographyText = try container.decodeIfPresent(String.self, forKey: .bibliographyText)
        appendices = try container.decodeIfPresent([AppendixEntry].self, forKey: .appendices) ?? []
    }
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
    var editorContentWidth: Double
    var theme: AppTheme
    var appearancePresets: [AppearancePreset]
    var defaultColorLabelNames: [ColorLabel: String]

    init(
        autosaveIntervalSeconds: Int,
        backupIntervalMinutes: Int,
        backupRetentionCount: Int,
        backupLocation: String?,
        customMetadataFields: [CustomMetadataField],
        customStatusOptions: [String]?,
        editorFont: String,
        editorFontSize: Int,
        editorLineHeight: Double,
        editorContentWidth: Double = 860,
        theme: AppTheme,
        appearancePresets: [AppearancePreset] = [],
        defaultColorLabelNames: [ColorLabel: String]
    ) {
        self.autosaveIntervalSeconds = autosaveIntervalSeconds
        self.backupIntervalMinutes = backupIntervalMinutes
        self.backupRetentionCount = backupRetentionCount
        self.backupLocation = backupLocation
        self.customMetadataFields = customMetadataFields
        self.customStatusOptions = customStatusOptions
        self.editorFont = editorFont
        self.editorFontSize = editorFontSize
        self.editorLineHeight = editorLineHeight
        self.editorContentWidth = editorContentWidth
        self.theme = theme
        self.appearancePresets = appearancePresets
        self.defaultColorLabelNames = defaultColorLabelNames
    }

    private enum CodingKeys: String, CodingKey {
        case autosaveIntervalSeconds
        case backupIntervalMinutes
        case backupRetentionCount
        case backupLocation
        case customMetadataFields
        case customStatusOptions
        case editorFont
        case editorFontSize
        case editorLineHeight
        case editorContentWidth
        case theme
        case appearancePresets
        case defaultColorLabelNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autosaveIntervalSeconds = try container.decode(Int.self, forKey: .autosaveIntervalSeconds)
        backupIntervalMinutes = try container.decode(Int.self, forKey: .backupIntervalMinutes)
        backupRetentionCount = try container.decode(Int.self, forKey: .backupRetentionCount)
        backupLocation = try container.decodeIfPresent(String.self, forKey: .backupLocation)
        customMetadataFields = try container.decodeIfPresent([CustomMetadataField].self, forKey: .customMetadataFields) ?? []
        customStatusOptions = try container.decodeIfPresent([String].self, forKey: .customStatusOptions)
        editorFont = try container.decode(String.self, forKey: .editorFont)
        editorFontSize = try container.decode(Int.self, forKey: .editorFontSize)
        editorLineHeight = try container.decode(Double.self, forKey: .editorLineHeight)
        editorContentWidth = try container.decodeIfPresent(Double.self, forKey: .editorContentWidth) ?? 860
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        appearancePresets = try container.decodeIfPresent([AppearancePreset].self, forKey: .appearancePresets) ?? []
        defaultColorLabelNames = try container.decodeIfPresent([ColorLabel: String].self, forKey: .defaultColorLabelNames)
            ?? Dictionary(uniqueKeysWithValues: ColorLabel.allCases.map { ($0, $0.rawValue.capitalized) })
    }
}

struct AppearancePreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var theme: AppTheme
    var fontName: String
    var fontSize: Int
    var lineHeight: Double
    var editorContentWidth: Double
}

enum AppTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark
    case parchment
    case midnight
    case forest
    case rose

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .parchment:
            return "Parchment"
        case .midnight:
            return "Midnight Ink"
        case .forest:
            return "Forest Draft"
        case .rose:
            return "Rose Study"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = AppTheme(rawValue: value) ?? .system
    }
}
