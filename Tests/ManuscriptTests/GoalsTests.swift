import XCTest
@testable import Manuscript

@MainActor
final class GoalsTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testSessionWordCountTracksNetAdditions() throws {
        let manager = try makeManager(name: "SessionNet")
        let goals = GoalsManager(projectManager: manager)
        goals.startSession(goal: nil)

        goals.recordWordCountChange(previous: 100, new: 150)
        goals.recordWordCountChange(previous: 150, new: 140)

        XCTAssertEqual(goals.sessionWordsWritten, 40)
        XCTAssertEqual(goals.sessionGrossWords, 50)
    }

    func testSessionGoalNotificationFiresAtThreshold() throws {
        let manager = try makeManager(name: "GoalThreshold")
        let goals = GoalsManager(projectManager: manager)
        goals.startSession(goal: 500)

        goals.recordWordCountChange(previous: 0, new: 500)

        XCTAssertEqual(goals.lastGoalNotificationMessage, "Session goal reached! 500 words written.")
        XCTAssertEqual(goals.sessionProgressText(), "500 / 500")
    }

    func testSessionGoalAllowsOvershootDisplay() throws {
        let manager = try makeManager(name: "Overshoot")
        let goals = GoalsManager(projectManager: manager)
        goals.startSession(goal: 500)

        goals.recordWordCountChange(previous: 0, new: 612)
        XCTAssertEqual(goals.sessionProgressText(), "612 / 500")
    }

    func testProjectGoalCalculatesProjectedCompletion() throws {
        let manager = try makeManager(name: "Projection")
        let goals = GoalsManager(projectManager: manager)

        goals.currentTotalWordCount = 20_000
        goals.projectGoalWordCount = 80_000
        goals.writingHistory = makeConsecutiveDailyRecords(days: 30, wordsPerDay: 1_000, endingAt: Date())

        let projected = try XCTUnwrap(goals.projectedCompletionDate())
        let days = Calendar.current.dateComponents([.day], from: Date(), to: projected).day ?? -1
        XCTAssertTrue((59...61).contains(days))
    }

    func testStreakResetsAfterMissedDay() throws {
        let manager = try makeManager(name: "StreakReset")
        let goals = GoalsManager(projectManager: manager)

        let today = Date()
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: today)!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        goals.writingHistory = [
            record(on: fourDaysAgo, words: 100),
            record(on: threeDaysAgo, words: 100),
            record(on: twoDaysAgo, words: 100),
            record(on: today, words: 100)
        ]

        goals.startSession(goal: nil)
        goals.recordWordCountChange(previous: 0, new: 10)
        goals.endSession()
        XCTAssertEqual(goals.currentStreak, 1)
    }

    func testHistoryAccumulatesAcrossSessions() throws {
        let manager = try makeManager(name: "HistoryAccum")
        let goals = GoalsManager(projectManager: manager)

        let today = dayKey(Date())
        goals.writingHistory = [DailyWritingRecord(date: today, wordsWritten: 200, wordsGross: 200, timeSpentSeconds: 60, sessionsCount: 1)]

        goals.startSession(goal: nil)
        goals.recordWordCountChange(previous: 0, new: 300)
        goals.sessionElapsedSeconds = 120
        goals.endSession()

        let updated = try XCTUnwrap(goals.writingHistory.first(where: { $0.date == today }))
        XCTAssertEqual(updated.wordsWritten, 500)
        XCTAssertEqual(updated.sessionsCount, 2)
    }

    func testTimerPausesOnFocusLoss() throws {
        let manager = try makeManager(name: "FocusPause")
        let goals = GoalsManager(projectManager: manager)

        goals.startSession(goal: nil)
        goals.startTimer()
        XCTAssertTrue(goals.isTimerRunning)

        goals.handleAppFocusChanged(isFocused: false)
        XCTAssertFalse(goals.isTimerRunning)

        goals.handleAppFocusChanged(isFocused: true)
        XCTAssertTrue(goals.isTimerRunning)
    }

    func testNegativeSessionWordsDisplayCorrectly() throws {
        let manager = try makeManager(name: "NegativeNet")
        let goals = GoalsManager(projectManager: manager)

        goals.startSession(goal: nil)
        goals.recordWordCountChange(previous: 200, new: 50)

        XCTAssertEqual(goals.sessionWordsWritten, -150)
        XCTAssertEqual(goals.sessionProgressText(), "−150 words (net)")
    }

    func testChapterGoalShowsInSidebar() throws {
        let manager = try makeManager(name: "ChapterGoal")
        let chapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)

        try manager.saveSceneContent(sceneId: sceneId, content: Array(repeating: "word", count: 3_200).joined(separator: " "))

        let goals = GoalsManager(projectManager: manager)
        goals.setChapterGoal(chapterId: chapterId, wordCount: 5_000)

        let project = try XCTUnwrap(manager.currentProject)
        let nodes = SidebarHierarchyBuilder.build(project: project)
        let chapterNode = try XCTUnwrap(nodes.first(where: { $0.id == chapterId }))
        XCTAssertEqual(chapterNode.goalProgressText, "3,200 / 5,000")
    }

    private func makeManager(name: String) throws -> FileSystemProjectManager {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)
        return manager
    }

    private func makeConsecutiveDailyRecords(days: Int, wordsPerDay: Int, endingAt endDate: Date) -> [DailyWritingRecord] {
        (0..<days).reversed().compactMap { offset in
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: endDate) else { return nil }
            return record(on: day, words: wordsPerDay)
        }
    }

    private func record(on date: Date, words: Int) -> DailyWritingRecord {
        DailyWritingRecord(date: dayKey(date), wordsWritten: words, wordsGross: words, timeSpentSeconds: 60, sessionsCount: 1)
    }

    private func dayKey(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
