import XCTest
@testable import FlowTrackMenuBar

final class FlowTrackStoreTests: XCTestCase {
    func testPopoverDismissalPolicyKeepsKeyboardInputInsideTaskField() {
        XCTAssertFalse(PopoverDismissalPolicy.shouldClose(for: .keyboardInputInsidePopover))
        XCTAssertFalse(PopoverDismissalPolicy.shouldClose(for: .mouseDownInsidePopover))
        XCTAssertFalse(PopoverDismissalPolicy.shouldClose(for: .statusItemClick))
    }

    func testPopoverDismissalPolicyClosesForOutsideInteractions() {
        XCTAssertTrue(PopoverDismissalPolicy.shouldClose(for: .mouseDownOutsidePopover))
        XCTAssertTrue(PopoverDismissalPolicy.shouldClose(for: .appDidResignActive))
    }

    @MainActor
    func testStopCreatesSessionWithPausedAndRunningTime() throws {
        let baseDate = Date(timeIntervalSince1970: 1_000)
        var currentDate = baseDate

        let store = FlowTrackStore(
            persistence: .inMemory,
            now: { currentDate }
        )

        store.addProject(named: "Client Work")
        let projectID = try XCTUnwrap(store.projects.first?.id)
        store.selectProject(projectID)
        store.activeTaskName = "Homepage polish"

        store.startTimer()
        currentDate = baseDate.addingTimeInterval(120)
        store.pauseTimer()
        currentDate = baseDate.addingTimeInterval(180)
        store.startTimer()
        currentDate = baseDate.addingTimeInterval(300)

        let session = try XCTUnwrap(store.stopTimer())

        XCTAssertEqual(session.projectID, projectID)
        XCTAssertEqual(session.taskName, "Homepage polish")
        XCTAssertEqual(session.duration, 240, accuracy: 0.001)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.elapsedTime(asOf: currentDate), 0, accuracy: 0.001)
    }

    @MainActor
    func testDeletingProjectRemovesItsSessionsAndResetsActiveTimer() throws {
        let store = FlowTrackStore(
            persistence: .inMemory,
            now: Date.init
        )

        store.addProject(named: "FlowTrack")
        let projectID = try XCTUnwrap(store.projects.first?.id)
        store.selectProject(projectID)
        store.startTimer()
        _ = store.stopTimer()

        XCTAssertEqual(store.sessions.count, 1)

        store.deleteProject(projectID)

        XCTAssertTrue(store.projects.isEmpty)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNil(store.selectedProjectID)
        XCTAssertNil(store.timer.projectID)
    }

    @MainActor
    func testInvoiceSummaryCombinesHoursAndMoneyAcrossProjects() throws {
        let baseDate = Date(timeIntervalSince1970: 5_000)
        var currentDate = baseDate

        let store = FlowTrackStore(
            persistence: .inMemory,
            now: { currentDate }
        )

        // Project A: 2h @ $100 = $200
        store.addProject(named: "Project A")
        let a = try XCTUnwrap(store.projects.first?.id)
        store.setHourlyRate(100, for: a)
        store.selectProject(a)
        store.startTimer()
        currentDate = baseDate.addingTimeInterval(7_200)
        _ = store.stopTimer()

        // Project B: 1h @ $50 = $50
        store.addProject(named: "Project B")
        let b = try XCTUnwrap(store.projects.last?.id)
        store.setHourlyRate(50, for: b)
        store.selectProject(b)
        store.startTimer()
        currentDate = currentDate.addingTimeInterval(3_600)
        _ = store.stopTimer()

        // Project C: 1h, no rate -> excluded from money total
        store.addProject(named: "Project C")
        let c = try XCTUnwrap(store.projects.last?.id)
        store.selectProject(c)
        store.startTimer()
        currentDate = currentDate.addingTimeInterval(3_600)
        _ = store.stopTimer()

        let summary = store.invoiceSummary(for: [a, b, c])

        XCTAssertEqual(summary.lines.count, 3)
        XCTAssertEqual(summary.totalHours, 4.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalAmount, 250.0, accuracy: 0.001)
        XCTAssertTrue(summary.hasUnratedProjects)

        // Subset selection only sums selected projects.
        let subset = store.invoiceSummary(for: [a, b])
        XCTAssertEqual(subset.totalHours, 3.0, accuracy: 0.001)
        XCTAssertEqual(subset.totalAmount, 250.0, accuracy: 0.001)
        XCTAssertFalse(subset.hasUnratedProjects)
    }

    @MainActor
    func testMenuBarTitleShowsLiveClockWhileTracking() throws {
        let baseDate = Date(timeIntervalSince1970: 2_000)
        var currentDate = baseDate

        let store = FlowTrackStore(
            persistence: .inMemory,
            now: { currentDate }
        )

        store.addProject(named: "Design")
        let projectID = try XCTUnwrap(store.projects.first?.id)
        store.selectProject(projectID)
        store.startTimer()
        currentDate = baseDate.addingTimeInterval(3_725)

        XCTAssertEqual(store.menuBarTitle(asOf: currentDate), "01:02:05")
        XCTAssertEqual(store.menuBarSymbolName, "record.circle.fill")
    }
}
