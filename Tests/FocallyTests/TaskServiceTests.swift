import XCTest
@testable import Focally

@MainActor
final class TaskServiceTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileURL: URL!
    private var scheduler: FakeReminderScheduler!
    private var nowDate = Date(timeIntervalSince1970: 1_789_000_000) // fixed instant

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-service-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        fileURL = tempDirectory.appendingPathComponent("tasks.json")
        scheduler = FakeReminderScheduler()
        nowDate = Date(timeIntervalSince1970: 1_789_000_000) // fixed instant
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    private func makeService() -> TaskService {
        TaskService(fileURL: fileURL, now: { [nowDate] in nowDate }, reminderScheduler: scheduler)
    }

    // MARK: - CRUD

    func testAddTaskTrimsTitleAndPersistsImmediately() throws {
        let service = makeService()
        let task = service.addTask(title: "  Write spec  ")
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.title, "Write spec")

        let reloaded = TaskService(fileURL: fileURL, now: { [nowDate] in nowDate })
        XCTAssertEqual(reloaded.tasks.map(\.title), ["Write spec"])
    }

    func testAddBlankTaskIsRejected() {
        let service = makeService()
        XCTAssertNil(service.addTask(title: "   "))
        XCTAssertTrue(service.tasks.isEmpty)
    }

    func testUpdateTaskSetsAndClearsCompletedAt() {
        let service = makeService()
        let task = service.addTask(title: "task")!
        XCTAssertNil(task.completedAt)

        service.toggleComplete(task.id)
        XCTAssertEqual(service.task(withID: task.id)?.completedAt, nowDate)

        service.toggleComplete(task.id)
        XCTAssertNil(service.task(withID: task.id)?.completedAt)
        XCTAssertFalse(service.task(withID: task.id)!.isCompleted)
    }

    func testRemoveTaskRemovesAndCancelsReminder() {
        let service = makeService()
        let task = service.addTask(title: "task")!
        service.removeTask(task.id)
        XCTAssertTrue(service.tasks.isEmpty)
        // Cancelled twice by design (idempotent): once when the task is created
        // without a due date, once when it is removed.
        XCTAssertEqual(scheduler.cancelledTaskIDs.filter { $0 == task.id }.count, 2)
    }

    func testTaskCapIsEnforced() {
        let service = makeService()
        for index in 0..<TaskItem.maxTasks {
            _ = service.addTask(title: "task \(index)")
        }
        XCTAssertNil(service.addTask(title: "one too many"))
        XCTAssertEqual(service.tasks.count, TaskItem.maxTasks)
    }

    // MARK: - Ordering

    func testOpenTasksAreReorderedByDueDateAfterAdd() {
        let service = makeService()
        let late = service.addTask(title: "late", dueDate: nowDate.addingTimeInterval(86400 * 3))!
        let soon = service.addTask(title: "soon", dueDate: nowDate.addingTimeInterval(3600))!
        XCTAssertEqual(service.tasks.map(\.title), ["soon", "late"])
        _ = late; _ = soon
    }

    // MARK: - Reminder scheduling hooks

    func testAddingTaskWithFutureDueDateSchedulesReminder() {
        let service = makeService()
        let due = nowDate.addingTimeInterval(3600)
        let task = service.addTask(title: "with reminder", dueDate: due)!
        XCTAssertEqual(scheduler.scheduled[task.id]?.title, "with reminder")
        XCTAssertEqual(scheduler.scheduled[task.id]?.dueDate, due)
    }

    func testCompletingTaskCancelsReminder() {
        let service = makeService()
        let task = service.addTask(title: "task", dueDate: nowDate.addingTimeInterval(3600))!
        service.toggleComplete(task.id)
        XCTAssertTrue(scheduler.cancelledTaskIDs.contains(task.id))
    }

    func testUpdatingDueDateReschedulesInsteadOfDuplicating() {
        let service = makeService()
        let task = service.addTask(title: "task", dueDate: nowDate.addingTimeInterval(3600))!
        var updated = task
        let newDue = nowDate.addingTimeInterval(7200)
        updated.dueDate = newDue
        service.updateTask(updated)
        XCTAssertEqual(scheduler.scheduled[task.id]?.dueDate, newDue)
    }

    // MARK: - Time attribution

    func testTimeSpentAndPomodorosAggregateOnlyMatchingTaskRecords() {
        let service = makeService()
        let taskA = UUID()
        let taskB = UUID()

        let records: [FocusSessionRecord] = [
            record(taskID: taskA, active: 1500, pomodoros: 1),
            record(taskID: taskA, active: 600, pomodoros: 1),
            record(taskID: taskB, active: 3000, pomodoros: 2),
            record(taskID: nil, active: 999, pomodoros: nil),
        ]

        XCTAssertEqual(service.timeSpent(on: taskA, records: records), 2100)
        XCTAssertEqual(service.completedPomodoros(on: taskA, records: records), 2)
        XCTAssertEqual(service.timeSpent(on: taskB, records: records), 3000)
        XCTAssertEqual(service.timeSpent(on: UUID(), records: records), 0)
    }

    // MARK: - Corruption tolerance

    func testCorruptFileStartsEmptyInsteadOfCrashing() throws {
        try Data("not json".utf8).write(to: fileURL)
        let service = TaskService(fileURL: fileURL, now: { [nowDate] in nowDate })
        XCTAssertTrue(service.tasks.isEmpty)
    }

    func testInvalidStoredTasksAreFilteredOut() throws {
        let valid = TaskItem(title: "keep me", createdAt: nowDate)
        let invalid = TaskItem(title: "   ", createdAt: nowDate)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([valid, invalid]).write(to: fileURL)

        let service = TaskService(fileURL: fileURL, now: { [nowDate] in nowDate })
        XCTAssertEqual(service.tasks.map(\.title), ["keep me"])
    }

    // MARK: - Helpers

    private func record(taskID: UUID?, active: TimeInterval, pomodoros: Int?) -> FocusSessionRecord {
        let start = nowDate.addingTimeInterval(-3600)
        let end = start.addingTimeInterval(active)
        return FocusSessionRecord(
            modeType: .focusTime,
            modeID: UUID(),
            startTime: start,
            endTime: end,
            duration: active,
            pomodorosCompleted: pomodoros,
            activeDuration: active,
            taskID: taskID
        )
    }
}

@MainActor
private final class FakeReminderScheduler: TaskReminderScheduling {
    var scheduled: [UUID: (title: String, dueDate: Date)] = [:]
    var cancelledTaskIDs: [UUID] = []

    func scheduleReminder(taskID: UUID, title: String, dueDate: Date) {
        scheduled[taskID] = (title, dueDate)
    }

    func cancelReminder(taskID: UUID) {
        cancelledTaskIDs.append(taskID)
    }
}
