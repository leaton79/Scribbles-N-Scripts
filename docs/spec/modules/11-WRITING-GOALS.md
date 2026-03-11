# Module 11: Writing Goals & Statistics
## Scribbles-N-Scripts — Module Spec Card

> **Context**: Include `PROJECT-BIBLE.md` in the prompt alongside this card.
> **Depends on**: Module 01 (Project I/O) — stores history data; Module 02 (Editor) — subscribes to word count changes
> **Exposes**: `GoalsManager` — session/project/chapter goals, history logging, statistics computation

---

## 1. Purpose

Tracks writing progress at session, chapter, and project levels. Maintains a local writing history for motivation and accountability. Provides goal-setting and progress visualization.

---

## 2. Interface Specification

```swift
class GoalsManager: ObservableObject {
    // Session
    @Published var sessionGoal: Int?                    // nil = no session goal
    @Published var sessionWordsWritten: Int              // Net words added this session
    @Published var sessionGrossWords: Int                // Total words typed (including deleted)
    @Published var sessionStartTime: Date?
    @Published var sessionElapsedSeconds: Int
    @Published var isTimerRunning: Bool
    
    // Project
    @Published var projectGoalWordCount: Int?
    @Published var projectGoalDeadline: Date?
    @Published var currentTotalWordCount: Int
    
    // History
    @Published var writingHistory: [DailyWritingRecord]
    @Published var currentStreak: Int                    // Consecutive days with writing
    
    func startSession(goal: Int?)
    func endSession()
    func startTimer()
    func pauseTimer()
    func resetTimer()
    
    func setProjectGoal(wordCount: Int?, deadline: Date?)
    func setChapterGoal(chapterId: UUID, wordCount: Int)
    func clearChapterGoal(chapterId: UUID)
    
    func projectedCompletionDate() -> Date?              // Based on avg daily pace
    func averageDailyWords(lastNDays: Int) -> Double
}

struct DailyWritingRecord: Codable {
    let date: String                                     // "YYYY-MM-DD"
    var wordsWritten: Int                                 // Net (additions minus deletions)
    var wordsGross: Int                                   // All typed words
    var timeSpentSeconds: Int                             // Active editing time
    var sessionsCount: Int
}

// Stored in project at metadata/writing-history.json
struct WritingHistoryStore: Codable {
    var records: [DailyWritingRecord]
    var projectGoalWordCount: Int?
    var projectGoalDeadline: String?                      // ISO8601
}
```

---

## 3. Behavioral Specification

### 3.1 Session Tracking
- **Given** the user opens the project
- **When** the session starts (project open or manual "Start Session")
- **Then** `sessionWordsWritten` starts at 0. Every word count change in the editor updates the session count. Additions increase the count; deletions decrease it (net tracking). `sessionGrossWords` only increases (tracks total keystrokes that produce words).

- **Given** the user set a session goal of 500 words
- **When** `sessionWordsWritten` reaches 500
- **Then** a non-modal notification appears: "Session goal reached! 500 words written." The progress bar fills to 100%. The user can continue writing (the bar shows overshoot, e.g., "612 / 500").

### 3.2 Session Timer
- **Given** the user starts the timer
- **When** the timer is running
- **Then** `sessionElapsedSeconds` increments every second. The timer is visible in the status bar. If the editor loses focus (user switches to another app), the timer pauses automatically. It resumes when the editor regains focus. Manual pause/resume is also available.

### 3.3 Project Goal
- **Given** the user sets a project goal of 80,000 words by December 31
- **When** the project dashboard is viewed
- **Then** it shows: current word count (e.g., 23,450 / 80,000), a progress bar (29%), words remaining (56,550), average daily words over the last 30 days, projected completion date based on that average, and whether the user is ahead of or behind schedule relative to the deadline.

### 3.4 Chapter Goals
- **Given** a chapter goal of 5,000 words is set for Chapter 3
- **When** the sidebar renders Chapter 3
- **Then** a mini progress bar or fraction (e.g., "3,200 / 5,000") is visible next to the chapter title. Reaching the goal triggers no notification (chapter goals are passive indicators).

### 3.5 Writing History
- **Given** the user has been writing for 7 consecutive days
- **When** they view the statistics panel
- **Then** a calendar heatmap shows the last 90 days, colored by word count intensity. A line chart shows daily word counts. Current streak: 7 days. Today's words: [count]. The history is stored in `metadata/writing-history.json` and persists across sessions.

- **Given** the user skips a day
- **When** the streak is recalculated
- **Then** the streak resets to 0. The next writing day starts a new streak at 1.

### 3.6 History Recording
- **Given** a session is active
- **When** the session ends (project close, manual end, or timer stop)
- **Then** the session's words and time are added to today's `DailyWritingRecord`. If a record for today already exists (multiple sessions), values are accumulated. The file is saved immediately.

---

## 4. Edge Cases & Constraints

| Case | Behavior |
|------|----------|
| User deletes more words than they wrote | `sessionWordsWritten` can be negative. Display as "−150 words (net)" — this is valid for editing sessions. `sessionGrossWords` remains positive. |
| Session spans midnight | The words written before midnight are attributed to the previous day, words after midnight to the new day. Split based on the timestamp of each word count change event. |
| Project goal deadline is in the past | Show "Deadline passed X days ago. Y words remaining." No error — the goal remains active. |
| Projected completion date is "never" (0 average pace) | Show "No recent writing activity. Set a session goal to get started." |
| Writing history file is corrupted | Attempt to parse. If parsing fails, back up the corrupted file and start a new empty history. Show a warning: "Writing history could not be loaded. Previous data has been backed up." |
| User works on multiple chapters in one session | Session word count is a single aggregate. Per-chapter word count changes are tracked via the manifest (chapter word counts update when scenes within them change). |
| Timer running but no typing for 30+ minutes | Timer continues running (user may be thinking, reading, etc.). The timer tracks "session time," not "active typing time." Active typing time is a separate metric computed from keystroke timestamps. |

---

## 5. Test Cases

```
TEST: Session word count tracks net additions
  GIVEN a session starts with a scene at 100 words
  WHEN the user adds 50 words then deletes 10 words
  THEN sessionWordsWritten == 40
  AND sessionGrossWords == 50

TEST: Session goal notification fires at threshold
  GIVEN sessionGoal = 500
  WHEN sessionWordsWritten reaches 500
  THEN a notification is triggered
  AND progress shows 500/500 (100%)

TEST: Session goal allows overshoot display
  GIVEN sessionGoal = 500 and sessionWordsWritten = 612
  WHEN the status bar renders
  THEN it shows "612 / 500" with the bar filled past 100%

TEST: Project goal calculates projected completion
  GIVEN projectGoalWordCount = 80000, currentTotal = 20000, average daily pace = 1000
  WHEN projectedCompletionDate() is called
  THEN result is approximately 60 days from now

TEST: Streak resets after missed day
  GIVEN writingHistory has records for the last 5 consecutive days
  AND no record exists for yesterday
  WHEN currentStreak is computed today (with a new record)
  THEN currentStreak == 1

TEST: History accumulates across sessions
  GIVEN today's record has wordsWritten=200 from a morning session
  WHEN an afternoon session adds 300 net words and ends
  THEN today's record shows wordsWritten=500
  AND sessionsCount=2

TEST: Timer pauses on focus loss
  GIVEN the timer is running
  WHEN the app loses focus (user switches to Safari)
  THEN the timer pauses
  AND resuming focus resumes the timer

TEST: Negative session words display correctly
  GIVEN a session where user deleted 200 words and wrote 50
  WHEN the status bar renders
  THEN it shows "−150 words (net)" or equivalent

TEST: Chapter goal shows in sidebar
  GIVEN Chapter 3 has a goal of 5000 and current word count of 3200
  WHEN the sidebar renders
  THEN Chapter 3 shows "3,200 / 5,000" indicator
```

---

## 6. Implementation Notes

- Subscribe to the editor's word count changes via a Combine publisher. On each change, compute the delta from the last known count and add to session totals.
- The writing history file (`metadata/writing-history.json`) should be small — one record per day. Even for years of daily writing, this is <50KB.
- For the calendar heatmap, use a SwiftUI grid of colored rectangles. Color intensity mapped to word count quantiles (not absolute values) so the heatmap is meaningful regardless of the user's pace.
- Projected completion date: `remainingWords / averageDailyWords(lastNDays: 30)`. If average is 0, return nil (no projection possible).
- The session timer is a simple `Timer.scheduledTimer` or `DispatchSource` timer. Accuracy to the second is sufficient — no need for high-precision timing.
- Consider storing gross vs. net words separately in history. Gross is useful for tracking effort; net is useful for tracking progress. Both have motivational value.
