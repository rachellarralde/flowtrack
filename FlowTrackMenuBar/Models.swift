import Foundation

struct FlowProject: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var hourlyRate: Double?
    var colorName: String?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        hourlyRate: Double? = nil,
        colorName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.hourlyRate = hourlyRate
        self.colorName = colorName
    }
}

struct FlowSession: Identifiable, Codable, Equatable {
    let id: UUID
    var projectID: UUID
    var taskName: String
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval

    init(
        id: UUID = UUID(),
        projectID: UUID,
        taskName: String,
        startedAt: Date,
        endedAt: Date,
        duration: TimeInterval
    ) {
        self.id = id
        self.projectID = projectID
        self.taskName = taskName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
    }
}

struct ActiveTimer: Codable, Equatable {
    var projectID: UUID?
    var taskName: String
    var startedAt: Date?
    var sessionStartedAt: Date?
    var accumulatedDuration: TimeInterval

    init(
        projectID: UUID? = nil,
        taskName: String = "",
        startedAt: Date? = nil,
        sessionStartedAt: Date? = nil,
        accumulatedDuration: TimeInterval = 0
    ) {
        self.projectID = projectID
        self.taskName = taskName
        self.startedAt = startedAt
        self.sessionStartedAt = sessionStartedAt
        self.accumulatedDuration = accumulatedDuration
    }

    var isRunning: Bool {
        projectID != nil && startedAt != nil
    }

    var isPaused: Bool {
        projectID != nil && startedAt == nil && accumulatedDuration > 0
    }

    var isActive: Bool {
        isRunning || isPaused
    }
}

struct InvoiceLine: Identifiable, Equatable {
    let id: UUID
    let name: String
    let seconds: TimeInterval
    let rate: Double?

    var hours: Double { seconds / 3600.0 }
    var amount: Double? { rate.map { hours * $0 } }
}

struct InvoiceSummary: Equatable {
    let lines: [InvoiceLine]

    var totalSeconds: TimeInterval { lines.reduce(0) { $0 + $1.seconds } }
    var totalHours: Double { totalSeconds / 3600.0 }
    var totalAmount: Double { lines.reduce(0) { $0 + ($1.amount ?? 0) } }
    var hasUnratedProjects: Bool { lines.contains { $0.rate == nil && $0.seconds > 0 } }
}

struct AppSnapshot: Codable, Equatable {
    var projects: [FlowProject]
    var sessions: [FlowSession]
    var selectedProjectID: UUID?
    var timer: ActiveTimer

    init(
        projects: [FlowProject] = [],
        sessions: [FlowSession] = [],
        selectedProjectID: UUID? = nil,
        timer: ActiveTimer = ActiveTimer()
    ) {
        self.projects = projects
        self.sessions = sessions
        self.selectedProjectID = selectedProjectID
        self.timer = timer
    }
}

