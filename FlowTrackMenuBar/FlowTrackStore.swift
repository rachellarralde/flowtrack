import Foundation
import Observation

@MainActor
@Observable
final class FlowTrackStore {
    var projects: [FlowProject]
    var sessions: [FlowSession]
    var selectedProjectID: UUID?
    var timer: ActiveTimer

    private let persistence: FlowTrackPersistence
    private let now: () -> Date

    init(
        snapshot: AppSnapshot = AppSnapshot(),
        persistence: FlowTrackPersistence = .live,
        now: @escaping () -> Date = Date.init
    ) {
        let initialSnapshot = persistence.load() ?? snapshot
        self.projects = initialSnapshot.projects
        self.sessions = initialSnapshot.sessions.sorted { $0.startedAt > $1.startedAt }
        self.selectedProjectID = initialSnapshot.selectedProjectID ?? initialSnapshot.projects.first?.id
        self.timer = initialSnapshot.timer
        self.persistence = persistence
        self.now = now

        if timer.projectID == nil {
            timer.projectID = self.selectedProjectID
        }
    }

    var activeTaskName: String {
        get { timer.taskName }
        set {
            timer.taskName = newValue
            persist()
        }
    }

    var selectedProject: FlowProject? {
        guard let selectedProjectID else {
            return nil
        }

        return projects.first(where: { $0.id == selectedProjectID })
    }

    var selectedProjectSessions: [FlowSession] {
        guard let selectedProjectID else {
            return []
        }

        return sessions
            .filter { $0.projectID == selectedProjectID }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var recentSessions: [FlowSession] {
        Array(sessions.prefix(5))
    }

    var menuBarSymbolName: String {
        if timer.isRunning {
            return "record.circle.fill"
        }

        if elapsedTime(asOf: now()) > 0 {
            return "pause.circle.fill"
        }

        return "timer"
    }

    func addProject(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        let color = FolderPalette.names[projects.count % FolderPalette.names.count]
        let project = FlowProject(name: trimmedName, createdAt: now(), colorName: color)
        projects.append(project)

        if selectedProjectID == nil {
            selectedProjectID = project.id
            timer.projectID = project.id
        }

        persist()
    }

    func deleteProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        sessions.removeAll { $0.projectID == id }

        if selectedProjectID == id {
            selectedProjectID = projects.first?.id
        }

        if timer.projectID == id {
            timer = ActiveTimer(projectID: selectedProjectID)
        } else if timer.projectID == nil {
            timer.projectID = selectedProjectID
        }

        persist()
    }

    func selectProject(_ id: UUID) {
        guard projects.contains(where: { $0.id == id }) else {
            return
        }

        selectedProjectID = id
        // A running or paused timer stays attached to its own project;
        // selection only retargets an idle timer.
        if !timer.isActive {
            timer.projectID = id
        }
        persist()
    }

    func startTimer() {
        // Starting on a different project commits the in-flight session first.
        if timer.isActive, timer.projectID != selectedProjectID {
            _ = stopTimer()
        }

        guard let projectID = selectedProjectID ?? timer.projectID else {
            return
        }

        let currentDate = now()
        timer.projectID = projectID

        if timer.sessionStartedAt == nil {
            timer.sessionStartedAt = currentDate
        }

        if timer.startedAt == nil {
            timer.startedAt = currentDate
        }

        persist()
    }

    func pauseTimer() {
        guard let startedAt = timer.startedAt else {
            return
        }

        timer.accumulatedDuration += max(0, now().timeIntervalSince(startedAt))
        timer.startedAt = nil
        persist()
    }

    func stopTimer() -> FlowSession? {
        guard let projectID = timer.projectID else {
            return nil
        }

        let endDate = now()
        let duration = elapsedTime(asOf: endDate)
        guard duration > 0 else {
            timer = ActiveTimer(projectID: selectedProjectID)
            persist()
            return nil
        }

        let session = FlowSession(
            projectID: projectID,
            taskName: timer.taskName.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: timer.sessionStartedAt ?? endDate.addingTimeInterval(-duration),
            endedAt: endDate,
            duration: duration
        )

        sessions.insert(session, at: 0)
        timer = ActiveTimer(projectID: selectedProjectID)
        persist()

        return session
    }

    func resetTimer() {
        timer = ActiveTimer(projectID: selectedProjectID)
        persist()
    }

    func elapsedTime(asOf date: Date) -> TimeInterval {
        let runningDuration: TimeInterval
        if let startedAt = timer.startedAt {
            runningDuration = max(0, date.timeIntervalSince(startedAt))
        } else {
            runningDuration = 0
        }

        return timer.accumulatedDuration + runningDuration
    }

    func projectName(for id: UUID) -> String {
        projects.first(where: { $0.id == id })?.name ?? "Unknown Project"
    }

    func totalTrackedTime(for id: UUID) -> TimeInterval {
        sessions
            .filter { $0.projectID == id }
            .reduce(0) { $0 + $1.duration }
    }

    func setHourlyRate(_ rate: Double?, for projectID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].hourlyRate = rate
        persist()
    }

    func earnings(for projectID: UUID, asOf date: Date) -> Double? {
        guard let project = projects.first(where: { $0.id == projectID }),
              let rate = project.hourlyRate, rate > 0 else { return nil }
        let saved = totalTrackedTime(for: projectID)
        let live = (timer.projectID == projectID && timer.isActive) ? elapsedTime(asOf: date) : 0
        return ((saved + live) / 3600.0) * rate
    }

    var allTimeTotal: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    func invoiceSummary(for ids: Set<UUID>) -> InvoiceSummary {
        let lines = projects
            .filter { ids.contains($0.id) }
            .map { project in
                InvoiceLine(
                    id: project.id,
                    name: project.name,
                    seconds: totalTrackedTime(for: project.id),
                    rate: project.hourlyRate
                )
            }
        return InvoiceSummary(lines: lines)
    }

    func sessionCount(for id: UUID) -> Int {
        sessions.filter { $0.projectID == id }.count
    }

    func menuBarTitle(asOf date: Date) -> String {
        let elapsed = elapsedTime(asOf: date)
        guard elapsed > 0 else {
            return "FlowTrack"
        }

        return TimeFormatting.clockString(for: elapsed)
    }

    private func persist() {
        persistence.save(
            AppSnapshot(
                projects: projects,
                sessions: sessions,
                selectedProjectID: selectedProjectID,
                timer: timer
            )
        )
    }
}
