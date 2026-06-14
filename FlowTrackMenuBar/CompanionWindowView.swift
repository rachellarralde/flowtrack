import AppKit
import Observation
import SwiftUI

// MARK: - Main View

struct CompanionWindowView: View {
    @Bindable var store: FlowTrackStore

    @State private var searchQuery = ""
    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var isShowingDeleteConfirmation = false
    @State private var isSelectingForInvoice = false
    @State private var invoiceSelection: Set<UUID> = []
    @State private var isShowingInvoice = false
    @FocusState private var newProjectFieldFocused: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 0) {
                sidebarView(asOf: context.date)
                    .frame(width: 264)

                Divider()
                    .overlay(FT.line)

                detailView(asOf: context.date)
            }
        }
        .background(FT.bg0)
        .frame(minWidth: 820, minHeight: 560)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleInvoiceSelection()
                } label: {
                    Image(systemName: isSelectingForInvoice ? "checklist.checked" : "checklist")
                }
                .help(isSelectingForInvoice ? "Cancel invoice selection" : "Select projects to invoice")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { beginAddingProject() } label: {
                    Image(systemName: "plus")
                }
                .help("New project")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete project")
                .disabled(store.selectedProject == nil)
            }
        }
        .confirmationDialog(
            "Delete project?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let project = store.selectedProject {
                Button("Delete \"\(project.name)\" and all sessions", role: .destructive) {
                    store.deleteProject(project.id)
                }
            }
        } message: {
            if let project = store.selectedProject {
                let count = store.sessionCount(for: project.id)
                Text("Removes \(count) session\(count == 1 ? "" : "s"). This cannot be undone.")
            }
        }
        .sheet(isPresented: $isShowingInvoice) {
            InvoiceSummaryView(
                summary: store.invoiceSummary(for: invoiceSelection),
                onClose: { isShowingInvoice = false }
            )
        }
    }

    private func toggleInvoiceSelection() {
        isSelectingForInvoice.toggle()
        if !isSelectingForInvoice {
            invoiceSelection = []
        }
    }

    private func toggleInvoiceMembership(_ id: UUID) {
        if invoiceSelection.contains(id) {
            invoiceSelection.remove(id)
        } else {
            invoiceSelection.insert(id)
        }
    }

    // MARK: - Sidebar

    private func sidebarView(asOf date: Date) -> some View {
        let filtered = filteredProjects

        return VStack(alignment: .leading, spacing: 0) {
            // Brand
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(FT.accent)
                    .frame(width: 30, height: 30)
                    .shadow(color: FT.accentGlow, radius: 7, y: 4)
                    .overlay(
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FT.accentFg)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("FlowTrack")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(FT.text)
                    Text("\(TimeFormatting.shortSummary(for: store.allTimeTotal)) all time")
                        .font(.system(size: 11))
                        .foregroundStyle(FT.text3)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FT.text3)
                TextField("Search projects", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(FT.text)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(FT.bg1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(FT.line, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            // Section head
            HStack {
                Text("PROJECTS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(FT.text3)
                Spacer()
                Text("\(filtered.count)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(FT.text4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Project list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(filtered, id: \.element.id) { item in
                        sidebarRow(project: item.element, index: item.offset, asOf: date)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }

            // Invoice action bar
            if isSelectingForInvoice {
                Divider().overlay(FT.line)
                HStack(spacing: 10) {
                    Text("\(invoiceSelection.count) selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FT.text3)
                    Spacer()
                    Button {
                        isShowingInvoice = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Invoice")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundStyle(FT.accentFg)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(FT.accent)
                                .shadow(color: FT.accentGlow, radius: 6, y: 3)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(invoiceSelection.isEmpty)
                    .opacity(invoiceSelection.isEmpty ? 0.4 : 1)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }

            // Footer — New Project
            Divider().overlay(FT.line)
            Group {
                if isAddingProject {
                    HStack(spacing: 9) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 13))
                            .foregroundStyle(FT.accent)
                        TextField("Project name", text: $newProjectName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FT.text)
                            .focused($newProjectFieldFocused)
                            .onSubmit(commitNewProject)
                            .onExitCommand {
                                isAddingProject = false
                                newProjectName = ""
                            }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .onAppear { newProjectFieldFocused = true }
                } else {
                    Button {
                        beginAddingProject()
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                            Text("New Project")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(FT.text2)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(FT.side)
    }

    private func sidebarRow(project: FlowProject, index: Int, asOf date: Date) -> some View {
        let isSelected = store.selectedProjectID == project.id
        let isTimerProject = store.timer.projectID == project.id && store.timer.isActive
        let liveElapsed = isTimerProject ? store.elapsedTime(asOf: date) : 0
        let total = store.totalTrackedTime(for: project.id) + liveElapsed
        let color = FolderPalette.color(for: project, index: index)
        let earnings = store.earnings(for: project.id, asOf: date)
        let isChecked = invoiceSelection.contains(project.id)

        return Button {
            if isSelectingForInvoice {
                toggleInvoiceMembership(project.id)
            } else {
                store.selectProject(project.id)
            }
        } label: {
            HStack(spacing: 11) {
                if isSelectingForInvoice {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17))
                        .foregroundStyle(isChecked ? FT.accent : FT.text4)
                }
                FolderTile(color: color)

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(FT.text)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if isTimerProject {
                            Circle()
                                .fill(store.timer.isRunning ? FT.accent : FT.amber)
                                .frame(width: 6, height: 6)
                                .shadow(
                                    color: store.timer.isRunning ? FT.accentGlow : .clear,
                                    radius: 3
                                )
                        }
                        Text(TimeFormatting.shortSummary(for: total))
                            .font(.system(size: 11.5))
                            .monospacedDigit()
                            .foregroundStyle(FT.text3)
                        if let earnings {
                            Text("· \(FTFormat.moneyShort(earnings))")
                                .font(.system(size: 11.5))
                                .monospacedDigit()
                                .foregroundStyle(FT.text4)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((isSelectingForInvoice ? isChecked : isSelected) ? FT.bg2 : Color.clear)
            )
            .overlay(alignment: .leading) {
                if !isSelectingForInvoice && isSelected {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 3, topTrailingRadius: 3
                    )
                    .fill(FT.accent)
                    .frame(width: 3, height: 24)
                    .offset(x: -10)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail

    @ViewBuilder
    private func detailView(asOf date: Date) -> some View {
        if let project = store.selectedProject {
            let index = store.projects.firstIndex(where: { $0.id == project.id }) ?? 0
            let color = FolderPalette.color(for: project, index: index)
            let isTimerProject = store.timer.projectID == project.id && store.timer.isActive
            let elapsed = isTimerProject ? store.elapsedTime(asOf: date) : 0
            let sessions = store.sessions
                .filter { $0.projectID == project.id }
                .sorted { $0.startedAt > $1.startedAt }
            let total = store.totalTrackedTime(for: project.id) + elapsed

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    detailHeader(project: project, color: color, total: total, asOf: date)
                    TimerCardView(store: store, project: project, elapsed: elapsed, asOf: date)
                    weekBarsCard(sessions: sessions, liveToday: elapsed)
                    sessionsSection(project: project, sessions: sessions, color: color)
                }
                .padding(.horizontal, 30)
                .padding(.top, 26)
                .padding(.bottom, 34)
            }
            .background(FT.bg0)
            .navigationTitle(project.name)
        } else {
            emptyState
        }
    }

    private func detailHeader(project: FlowProject, color: Color, total: TimeInterval, asOf date: Date) -> some View {
        let sessionCount = store.sessionCount(for: project.id)
        let earnings = store.earnings(for: project.id, asOf: date)

        return HStack(alignment: .top, spacing: 16) {
            FolderTile(color: color, size: 50, radius: 13, icon: 22)

            VStack(alignment: .leading, spacing: 5) {
                Text(project.name)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(FT.text)
                HStack(spacing: 8) {
                    Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    Circle().fill(FT.text4).frame(width: 3, height: 3)
                    Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                }
                .font(.system(size: 12.5))
                .foregroundStyle(FT.text3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 7) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TOTAL")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1.1)
                        .foregroundStyle(FT.text3)
                    Text(TimeFormatting.shortSummary(for: total))
                        .font(.system(size: 25, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(FT.text)
                        .lineLimit(1)
                }

                if let earnings {
                    Text("\(FTFormat.money(earnings)) earned")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(FT.earn)
                        .lineLimit(1)
                }

                RatePill(
                    rate: project.hourlyRate,
                    onSet: { store.setHourlyRate($0, for: project.id) }
                )
            }
        }
    }

    // MARK: - Week bars

    private func weekBarsCard(sessions: [FlowSession], liveToday: TimeInterval) -> some View {
        let data = WeekBarsData(sessions: sessions, liveToday: liveToday)
        let maxValue = max(data.max, 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FT.text3)
                    Text("Last 7 days")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FT.text2)
                }
                Spacer()
                Text("\(TimeFormatting.shortSummary(for: data.total)) tracked")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(FT.text3)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let value = data.values[i]
                    let isToday = i == 6
                    let fraction = value == 0 ? 0 : 0.08 + (value / maxValue) * 0.92

                    VStack(spacing: 7) {
                        GeometryReader { geo in
                            VStack { Spacer(minLength: 0) }
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .bottom) {
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 5, bottomLeadingRadius: 3,
                                        bottomTrailingRadius: 3, topTrailingRadius: 5
                                    )
                                    .fill(barFill(value: value, isToday: isToday))
                                    .frame(height: max(3, geo.size.height * fraction))
                                    .frame(maxWidth: 30)
                                    .shadow(
                                        color: isToday && value > 0 ? FT.accentGlow : .clear,
                                        radius: 7
                                    )
                                }
                        }
                        .frame(height: 62)

                        Text(data.labels[i])
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(isToday ? FT.accent : FT.text4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FT.bg1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FT.line, lineWidth: 1)
                )
        )
    }

    private func barFill(value: TimeInterval, isToday: Bool) -> LinearGradient {
        if value == 0 {
            return LinearGradient(colors: [FT.bg2], startPoint: .top, endPoint: .bottom)
        }
        if isToday {
            return LinearGradient(
                colors: [FT.accent, FT.accent.darkened(by: 0.3)],
                startPoint: .top, endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [FT.accent.opacity(0.85), FT.accent],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Sessions

    private func sessionsSection(project: FlowProject, sessions: [FlowSession], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Sessions")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FT.text)
                Spacer()
                Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(FT.text3)
            }

            if sessions.isEmpty {
                Text("No sessions yet — start the timer to log your first one.")
                    .font(.system(size: 13))
                    .foregroundStyle(FT.text3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(groupedSessions(sessions), id: \.label) { group in
                        Text(group.label.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(FT.text4)
                            .padding(.horizontal, 4)
                            .padding(.top, 14)
                            .padding(.bottom, 6)

                        ForEach(group.sessions) { session in
                            sessionRow(session, project: project, color: color)
                        }
                    }
                }
            }
        }
    }

    private struct SessionGroup {
        let label: String
        let sessions: [FlowSession]
    }

    private func groupedSessions(_ sessions: [FlowSession]) -> [SessionGroup] {
        var groups: [SessionGroup] = []
        for session in sessions {
            let label = FTFormat.dayLabel(session.startedAt)
            if let last = groups.indices.last, groups[last].label == label {
                groups[last] = SessionGroup(label: label, sessions: groups[last].sessions + [session])
            } else {
                groups.append(SessionGroup(label: label, sessions: [session]))
            }
        }
        return groups
    }

    private func sessionRow(_ session: FlowSession, project: FlowProject, color: Color) -> some View {
        let earnings = project.hourlyRate.map { (session.duration / 3600) * $0 }

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskName.isEmpty ? "Untitled session" : session.taskName)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(FT.text)
                    .lineLimit(1)
                Text("\(FTFormat.timeOfDay(session.startedAt)) – \(FTFormat.timeOfDay(session.endedAt))")
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(FT.text3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(TimeFormatting.shortSummary(for: session.duration))
                    .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FT.text)
                if let earnings {
                    Text(FTFormat.money(earnings))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(FT.earn)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.clear)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 52))
                .foregroundStyle(FT.bg2)
            VStack(spacing: 6) {
                Text("No project selected")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FT.text)
                Text("Select a project from the sidebar, or tap + to create one")
                    .font(.system(size: 13))
                    .foregroundStyle(FT.text3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FT.bg0)
    }

    // MARK: - Helpers

    private var filteredProjects: [(element: FlowProject, offset: Int)] {
        store.projects.enumerated()
            .filter {
                searchQuery.isEmpty
                    || $0.element.name.localizedCaseInsensitiveContains(searchQuery)
            }
            .map { (element: $0.element, offset: $0.offset) }
    }

    private func beginAddingProject() {
        isAddingProject = true
    }

    private func commitNewProject() {
        let trimmed = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        newProjectName = ""
        isAddingProject = false
        guard !trimmed.isEmpty else { return }
        store.addProject(named: trimmed)
        if let newID = store.projects.last?.id {
            store.selectProject(newID)
        }
    }
}

// MARK: - Timer card (shared design language with the popover)

struct TimerCardView: View {
    @Bindable var store: FlowTrackStore
    let project: FlowProject
    let elapsed: TimeInterval
    let asOf: Date

    private var isTimerProject: Bool {
        store.timer.projectID == project.id && store.timer.isActive
    }
    private var isRunning: Bool { isTimerProject && store.timer.isRunning }
    private var isPaused: Bool { isTimerProject && store.timer.isPaused }

    var body: some View {
        let liveEarnings = project.hourlyRate.map { (elapsed / 3600) * $0 }

        VStack(alignment: .leading, spacing: 18) {
            // Task input
            HStack(spacing: 11) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(FT.text3)
                TextField("What are you working on?", text: $store.activeTaskName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FT.text)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(FT.bg2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(FT.line, lineWidth: 1)
                    )
            )

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(TimeFormatting.clockString(for: elapsed))
                        .font(.system(size: 46, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(elapsed == 0 && !isTimerProject ? FT.text3 : FT.text)
                        .lineLimit(1)
                        .fixedSize()

                    HStack(spacing: 8) {
                        if isRunning {
                            Circle().fill(FT.accent).frame(width: 7, height: 7)
                                .shadow(color: FT.accentGlow, radius: 3)
                            Text("Recording")
                        } else if isPaused {
                            Circle().fill(FT.amber).frame(width: 7, height: 7)
                            Text("Paused")
                        } else {
                            Text("Ready to track")
                        }
                        if let liveEarnings, isTimerProject {
                            Text("· ")
                                + Text(FTFormat.money(liveEarnings))
                                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(FT.earn)
                        }
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(FT.text3)
                    .frame(height: 16)
                }

                Spacer()

                HStack(spacing: 10) {
                    if isRunning {
                        ActionButton(
                            title: "Pause",
                            systemImage: "pause.fill",
                            background: FT.amber,
                            foreground: FT.amberFg,
                            glow: FT.amber.opacity(0.4)
                        ) {
                            store.pauseTimer()
                        }
                    } else {
                        ActionButton(
                            title: isPaused ? "Resume" : "Start",
                            systemImage: "play.fill",
                            background: FT.accent,
                            foreground: FT.accentFg,
                            glow: FT.accentGlow
                        ) {
                            store.startTimer()
                        }
                    }

                    Button {
                        _ = store.stopTimer()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(FT.text2)
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(FT.bg2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(FT.line, lineWidth: 1)
                                    )
                            )
                            .opacity(isTimerProject ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isTimerProject)
                    .help("Stop & save session")
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FT.bg1, Color(hex: 0x1C1E24)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardBorder, lineWidth: 1)
                )
                .shadow(color: isRunning ? FT.accentGlow : .clear, radius: 20, y: 9)
        )
        .animation(.easeInOut(duration: 0.3), value: isRunning)
        .animation(.easeInOut(duration: 0.3), value: isPaused)
    }

    private var cardBorder: Color {
        if isRunning { return FT.accent.opacity(0.4) }
        if isPaused { return FT.amber.opacity(0.4) }
        return FT.line
    }
}

// MARK: - Primary action button

struct ActionButton: View {
    let title: String
    let systemImage: String
    let background: Color
    let foreground: Color
    let glow: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .frame(height: 50)
            .frame(minWidth: 128)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(background)
                    .brightness(isHovering ? 0.05 : 0)
                    .shadow(color: glow, radius: 11, y: 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Rate pill

struct RatePill: View {
    let rate: Double?
    let onSet: (Double?) -> Void

    @State private var isEditing = false
    @State private var input = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                HStack(spacing: 7) {
                    Image(systemName: "dollarsign")
                        .font(.system(size: 11, weight: .medium))
                    TextField("0", text: $input)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(FT.earn)
                        .frame(width: 46)
                        .focused($fieldFocused)
                        .onSubmit(commit)
                        .onExitCommand { isEditing = false }
                    Text("/hr")
                        .font(.system(size: 12))
                        .foregroundStyle(FT.text3)
                }
                .foregroundStyle(FT.earn)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .frame(height: 30)
                .background(pillBackground(set: true))
                .onAppear { fieldFocused = true }
            } else {
                Button {
                    input = rate.map { String(Int($0)) } ?? ""
                    isEditing = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "dollarsign")
                            .font(.system(size: 11, weight: .medium))
                        if let rate {
                            (Text(String(Int(rate)))
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                + Text("/hr")
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundStyle(FT.earn.opacity(0.6)))
                        } else {
                            Text("Set hourly rate")
                                .font(.system(size: 12.5))
                        }
                    }
                    .foregroundStyle(rate != nil ? FT.earn : FT.text2)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(pillBackground(set: rate != nil))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pillBackground(set: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(set ? FT.earnSoft : FT.bg1)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(set ? FT.earn.opacity(0.25) : FT.line, lineWidth: 1)
            )
    }

    private func commit() {
        let value = Double(input.trimmingCharacters(in: .whitespaces))
        onSet((value ?? 0) > 0 ? value.map { ($0).rounded() } : nil)
        isEditing = false
    }
}

// MARK: - Invoice summary modal

struct InvoiceSummaryView: View {
    let summary: InvoiceSummary
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 13) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(FT.accent)
                    .frame(width: 40, height: 40)
                    .shadow(color: FT.accentGlow, radius: 7, y: 4)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(FT.accentFg)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invoice Summary")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FT.text)
                    Text("\(summary.lines.count) project\(summary.lines.count == 1 ? "" : "s") combined")
                        .font(.system(size: 12.5))
                        .foregroundStyle(FT.text3)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FT.text2)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(FT.bg2)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            Divider().overlay(FT.line)

            // Per-project lines
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(summary.lines) { line in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.name)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(FT.text)
                                    .lineLimit(1)
                                Text(line.rate.map { "\(FTFormat.money($0, decimals: 0))/hr" } ?? "No rate set")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(line.rate == nil ? FT.amber : FT.text3)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.2f h", line.hours))
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(FT.text)
                                Text(line.amount.map { FTFormat.money($0) } ?? "—")
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(FT.earn)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(FT.bg1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(maxHeight: 320)

            Divider().overlay(FT.line)

            // Totals
            VStack(spacing: 12) {
                totalRow(
                    label: "Total Hours",
                    value: String(format: "%.2f h", summary.totalHours),
                    valueColor: FT.text
                )
                totalRow(
                    label: "Total to Invoice",
                    value: FTFormat.money(summary.totalAmount),
                    valueColor: FT.earn,
                    emphasized: true
                )
                if summary.hasUnratedProjects {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(FT.amber)
                        Text("Some projects have no hourly rate and are excluded from the dollar total.")
                            .font(.system(size: 11))
                            .foregroundStyle(FT.text3)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .frame(width: 440)
        .background(FT.bg0)
        .preferredColorScheme(.dark)
    }

    private func totalRow(label: String, value: String, valueColor: Color, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: emphasized ? 15 : 13, weight: emphasized ? .bold : .medium))
                .foregroundStyle(emphasized ? FT.text : FT.text2)
            Spacer()
            Text(value)
                .font(.system(size: emphasized ? 22 : 15, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var store = FlowTrackStore(persistence: .inMemory)

    CompanionWindowView(store: store)
        .task {
            store.addProject(named: "YF April 28 →")
            store.addProject(named: "YF May 11th")
            store.addProject(named: "June 10th")
            if let id = store.projects.first?.id {
                store.selectProject(id)
                store.setHourlyRate(95, for: id)
                store.activeTaskName = "Brand system & logo grid"
            }
        }
}
