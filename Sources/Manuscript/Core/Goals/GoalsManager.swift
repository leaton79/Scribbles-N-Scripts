import Combine
import Foundation

struct DailyWritingRecord: Codable, Equatable {
    let date: String
    var wordsWritten: Int
    var wordsGross: Int
    var timeSpentSeconds: Int
    var sessionsCount: Int
}

struct WritingHistoryStore: Codable {
    var records: [DailyWritingRecord]
    var projectGoalWordCount: Int?
    var projectGoalDeadline: String?
}

@MainActor
final class GoalsManager: ObservableObject {
    // Session
    @Published var sessionGoal: Int?
    @Published var sessionWordsWritten: Int
    @Published var sessionGrossWords: Int
    @Published var sessionStartTime: Date?
    @Published var sessionElapsedSeconds: Int
    @Published var isTimerRunning: Bool

    // Project
    @Published var projectGoalWordCount: Int?
    @Published var projectGoalDeadline: Date?
    @Published var currentTotalWordCount: Int

    // History
    @Published var writingHistory: [DailyWritingRecord]
    @Published var currentStreak: Int
    @Published private(set) var lastGoalNotificationMessage: String?
    @Published private(set) var lastWarningMessage: String?

    private let projectManager: ProjectManager
    private var timer: DispatchSourceTimer?
    private var currentEditorWordCount: Int?
    private var cancellables = Set<AnyCancellable>()
    private var sessionAggregatesByDay: [String: (net: Int, gross: Int)] = [:]
    private let calendar = Calendar(identifier: .gregorian)

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.sessionGoal = nil
        self.sessionWordsWritten = 0
        self.sessionGrossWords = 0
        self.sessionStartTime = nil
        self.sessionElapsedSeconds = 0
        self.isTimerRunning = false
        self.projectGoalWordCount = nil
        self.projectGoalDeadline = nil
        self.currentTotalWordCount = 0
        self.writingHistory = []
        self.currentStreak = 0

        refreshCurrentTotalWordCount()
        loadHistoryStore()
        recomputeStreak()
    }

    deinit {
        timer?.cancel()
    }

    func startSession(goal: Int?) {
        sessionGoal = goal
        sessionWordsWritten = 0
        sessionGrossWords = 0
        sessionElapsedSeconds = 0
        sessionStartTime = Date()
        sessionAggregatesByDay.removeAll()
        lastGoalNotificationMessage = nil
    }

    func endSession() {
        pauseTimer()
        guard sessionStartTime != nil else { return }
        mergeSessionIntoHistory()
        try? saveHistoryStore()
        sessionStartTime = nil
        currentEditorWordCount = nil
        sessionAggregatesByDay.removeAll()
    }

    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        if timer == nil {
            let newTimer = DispatchSource.makeTimerSource(queue: .main)
            newTimer.schedule(deadline: .now() + 1, repeating: 1)
            newTimer.setEventHandler { [weak self] in
                guard let self else { return }
                if self.isTimerRunning {
                    self.sessionElapsedSeconds += 1
                }
            }
            timer = newTimer
            newTimer.resume()
        }
    }

    func pauseTimer() {
        isTimerRunning = false
    }

    func resetTimer() {
        pauseTimer()
        sessionElapsedSeconds = 0
    }

    func setProjectGoal(wordCount: Int?, deadline: Date?) {
        projectGoalWordCount = wordCount
        projectGoalDeadline = deadline
        try? saveHistoryStore()
    }

    func setChapterGoal(chapterId: UUID, wordCount: Int) {
        try? projectManager.updateChapterMetadata(
            chapterId: chapterId,
            updates: ChapterMetadataUpdate(title: nil, synopsis: nil, status: nil, goalWordCount: wordCount)
        )
    }

    func clearChapterGoal(chapterId: UUID) {
        try? projectManager.updateChapterMetadata(
            chapterId: chapterId,
            updates: ChapterMetadataUpdate(title: nil, synopsis: nil, status: nil, goalWordCount: nil)
        )
    }

    func projectedCompletionDate() -> Date? {
        guard let projectGoalWordCount else { return nil }
        let remaining = projectGoalWordCount - currentTotalWordCount
        if remaining <= 0 {
            return Date()
        }

        let pace = averageDailyWords(lastNDays: 30)
        guard pace > 0 else { return nil }

        let days = Int(ceil(Double(remaining) / pace))
        return calendar.date(byAdding: .day, value: days, to: Date())
    }

    func averageDailyWords(lastNDays: Int) -> Double {
        guard lastNDays > 0 else { return 0 }
        let index = Dictionary(uniqueKeysWithValues: writingHistory.map { ($0.date, $0.wordsWritten) })
        let today = calendar.startOfDay(for: Date())
        var sum = 0
        for offset in 0..<lastNDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            sum += index[dayKey(for: day)] ?? 0
        }
        return Double(sum) / Double(lastNDays)
    }

    func bind(to editorState: EditorState, clock: @escaping () -> Date = Date.init) {
        currentEditorWordCount = editorState.wordCount
        editorState.$wordCount
            .sink { [weak self] wordCount in
                guard let self else { return }
                self.recordWordCountSnapshot(wordCount, at: clock())
            }
            .store(in: &cancellables)
    }

    func recordWordCountChange(previous: Int, new: Int, at timestamp: Date = Date()) {
        currentEditorWordCount = previous
        recordWordCountSnapshot(new, at: timestamp)
    }

    func recordWordCountSnapshot(_ newWordCount: Int, at timestamp: Date = Date()) {
        guard sessionStartTime != nil else {
            currentEditorWordCount = newWordCount
            return
        }

        let previous = currentEditorWordCount ?? newWordCount
        let delta = newWordCount - previous
        currentEditorWordCount = newWordCount

        if delta == 0 { return }

        sessionWordsWritten += delta
        if delta > 0 {
            sessionGrossWords += delta
        }

        let day = dayKey(for: timestamp)
        var aggregate = sessionAggregatesByDay[day] ?? (0, 0)
        aggregate.net += delta
        if delta > 0 {
            aggregate.gross += delta
        }
        sessionAggregatesByDay[day] = aggregate

        maybeNotifyGoalReached()
    }

    func handleAppFocusChanged(isFocused: Bool) {
        if isFocused {
            startTimer()
        } else {
            pauseTimer()
        }
    }

    func chapterGoalProgressText(chapterId: UUID) -> String? {
        let manifest = projectManager.getManifest()
        guard let chapter = manifest.hierarchy.chapters.first(where: { $0.id == chapterId }),
              let goal = chapter.goalWordCount else {
            return nil
        }
        let sceneById = Dictionary(uniqueKeysWithValues: manifest.hierarchy.scenes.map { ($0.id, $0.wordCount) })
        let current = chapter.scenes.reduce(0) { partialResult, sceneId in
            partialResult + (sceneById[sceneId] ?? 0)
        }
        return "\(Self.formatNumber(current)) / \(Self.formatNumber(goal))"
    }

    func sessionProgressText() -> String {
        if let goal = sessionGoal {
            return "\(sessionWordsWritten) / \(goal)"
        }
        if sessionWordsWritten < 0 {
            return "−\(abs(sessionWordsWritten)) words (net)"
        }
        return "\(sessionWordsWritten) words (net)"
    }

    private func mergeSessionIntoHistory() {
        guard !sessionAggregatesByDay.isEmpty else { return }
        var byDate = Dictionary(uniqueKeysWithValues: writingHistory.map { ($0.date, $0) })

        for (day, aggregate) in sessionAggregatesByDay {
            var record = byDate[day] ?? DailyWritingRecord(date: day, wordsWritten: 0, wordsGross: 0, timeSpentSeconds: 0, sessionsCount: 0)
            record.wordsWritten += aggregate.net
            record.wordsGross += aggregate.gross
            record.timeSpentSeconds += sessionElapsedSeconds
            record.sessionsCount += 1
            byDate[day] = record
        }

        writingHistory = Array(byDate.values).sorted(by: { $0.date < $1.date })
        recomputeStreak()
    }

    private func maybeNotifyGoalReached() {
        guard let goal = sessionGoal, goal > 0 else { return }
        guard sessionWordsWritten >= goal, lastGoalNotificationMessage == nil else { return }
        lastGoalNotificationMessage = "Session goal reached! \(goal) words written."
    }

    private func recomputeStreak(referenceDate: Date = Date()) {
        let recordSet = Set(writingHistory.filter { $0.wordsGross > 0 }.map(\.date))
        var streak = 0
        var day = calendar.startOfDay(for: referenceDate)
        while recordSet.contains(dayKey(for: day)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        currentStreak = streak
    }

    private func refreshCurrentTotalWordCount() {
        let manifest = projectManager.getManifest()
        currentTotalWordCount = manifest.hierarchy.scenes.reduce(0) { $0 + $1.wordCount }
    }

    private func historyURL() -> URL? {
        projectManager.projectRootURL?.appendingPathComponent("metadata/writing-history.json")
    }

    private func loadHistoryStore() {
        lastWarningMessage = nil
        guard let url = historyURL(), FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let store = try JSONDecoder().decode(WritingHistoryStore.self, from: data)
            writingHistory = store.records.sorted(by: { $0.date < $1.date })
            projectGoalWordCount = store.projectGoalWordCount
            if let deadlineString = store.projectGoalDeadline {
                projectGoalDeadline = ISO8601DateFormatter().date(from: deadlineString)
            }
        } catch {
            backupCorruptedHistoryFile(url: url)
            writingHistory = []
            lastWarningMessage = "Writing history could not be loaded. Previous data has been backed up."
        }
    }

    private func saveHistoryStore() throws {
        guard let url = historyURL() else { return }
        let store = WritingHistoryStore(
            records: writingHistory.sorted(by: { $0.date < $1.date }),
            projectGoalWordCount: projectGoalWordCount,
            projectGoalDeadline: projectGoalDeadline.map { ISO8601DateFormatter().string(from: $0) }
        )
        let data = try JSONEncoder().encode(store)
        try data.write(to: url, options: .atomic)
    }

    private func backupCorruptedHistoryFile(url: URL) {
        let backupURL = url
            .deletingLastPathComponent()
            .appendingPathComponent("writing-history.corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: url, to: backupURL)
    }

    private func dayKey(for date: Date) -> String {
        let comps = calendar.dateComponents(in: .current, from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func formatNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
