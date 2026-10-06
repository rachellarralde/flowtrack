import AppKit
import Observation
import SwiftUI

// MARK: - Local constants

/// Secondary text on a selected (ink) sidebar row.
private let selectedRowSubtext = Color(hex: 0xB9B7AF)

/// `receipt` ships with macOS 15.2; older systems fall back to a document glyph.
@MainActor private let invoiceSymbolName: String =
    NSImage(systemSymbolName: "receipt", accessibilityDescription: nil) != nil ? "receipt" : "doc.text"

private func sessionCountLabel(_ count: Int) -> String {
    "\(count) session\(count == 1 ? "" : "s")"
}

// MARK: - Main View

struct CompanionWindowView: View {
    @Bindable var store: FlowTrackStore

    @State private var searchQuery = ""
    @State private var isAddingProject = false
    @State private var newProjectName = ""
    @State private var isShowingDeleteConfirmation = false
    @State private var isSelectingForInvoice = false
    @State private var invoiceSelection: Set<UUID> = []
    @FocusState private var newProjectFieldFocused: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 0) {
                sidebarView(asOf: context.date)
                    .frame(width: 290)

                Rectangle()
                    .fill(Ledger.ink)
                    .frame(width: 1)

                detailView(asOf: context.date)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Ledger.paper)
        .foregroundStyle(Ledger.ink)
        .frame(minWidth: 820, minHeight: 560)
        .preferredColorScheme(.light)
        .navigationTitle(windowTitle)
        .toolbar { toolbarContent }
        .toolbarBackground(Ledger.paperDeep, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .onChange(of: isSelectingForInvoice) { _, isOn in
            if isOn {
                if invoiceSelection.isEmpty, let id = store.selectedProjectID {
                    invoiceSelection = [id]
                }
            } else {
                invoiceSelection = []
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
    }

    private var windowTitle: String {
        if isSelectingForInvoice { return "Invoice" }
        return store.selectedProject?.name ?? "FlowTrack"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $isSelectingForInvoice) {
                Label(
                    "Invoice",
                    systemImage: isSelectingForInvoice ? "\(invoiceSymbolName).fill" : invoiceSymbolName
                )
                .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .help(isSelectingForInvoice ? "Close the invoice" : "Select projects to invoice")
        }
        ToolbarItem(placement: .primaryAction) {
            Button { beginAddingProject() } label: {
                Label("New project", systemImage: "plus")
            }
            .help("New project")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete project", systemImage: "trash")
            }
            .help("Delete project")
            .disabled(store.selectedProject == nil || isSelectingForInvoice)
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
        let liveElapsed = store.timer.isActive ? store.elapsedTime(asOf: date) : 0

        return VStack(alignment: .leading, spacing: 0) {
            brandBlock(allTime: store.allTimeTotal + liveElapsed)
            searchField

            HStack {
                LedgerLabel(isSelectingForInvoice ? "Select to invoice" : "Projects")
                Spacer()
                LedgerLabel(
                    isSelectingForInvoice ? "\(invoiceSelection.count) selected" : "\(filtered.count)"
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 8)

            Rectangle()
                .fill(Ledger.ink)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered, id: \.element.id) { item in
                        projectRow(item.element, index: item.offset, asOf: date)
                    }
                    if filtered.isEmpty {
                        Text(store.projects.isEmpty ? "No projects yet." : "No projects match \u{201C}\(searchQuery)\u{201D}.")
                            .font(LedgerType.text(13))
                            .foregroundStyle(Ledger.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            sidebarFooter
        }
        .background(Ledger.paper)
    }

    private func brandBlock(allTime: TimeInterval) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Ledger.ink)
                .frame(width: 40, height: 40)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Ledger.signal)
                        .frame(width: 10, height: 10)
                        .padding(7)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("FlowTrack")
                    .font(LedgerType.display(20))
                    .tracking(-0.6)
                    .foregroundStyle(Ledger.ink)
                Text(verbatim: "\(TimeFormatting.shortSummary(for: allTime)) tracked, all time")
                    .font(LedgerType.mono(11))
                    .foregroundStyle(Ledger.ink2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Ledger.rule).frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ledger.ink)
                .accessibilityHidden(true)

            TextField("", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(LedgerType.text(14))
                .foregroundStyle(Ledger.ink)
                .onExitCommand { searchQuery = "" }
                .windowPlaceholder(
                    "Search projects",
                    isVisible: searchQuery.isEmpty,
                    font: LedgerType.text(14),
                    color: Ledger.ink3
                )
                .accessibilityLabel("Search projects")

            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Ledger.ink3)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                .fill(Ledger.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                .strokeBorder(Ledger.ink, lineWidth: 1)
        )
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private func projectRow(_ project: FlowProject, index: Int, asOf date: Date) -> some View {
        let isTimerProject = store.timer.projectID == project.id && store.timer.isActive
        let liveElapsed = isTimerProject ? store.elapsedTime(asOf: date) : 0
        let total = store.totalTrackedTime(for: project.id) + liveElapsed
        let earnings = store.earnings(for: project.id, asOf: date)
        let live: WindowLiveState = isTimerProject ? (store.timer.isRunning ? .running : .paused) : .idle

        return WindowProjectRow(
            number: index + 1,
            name: project.name,
            color: FolderPalette.color(for: project, index: index),
            total: TimeFormatting.shortSummary(for: total),
            earnings: earnings.map { FTFormat.moneyShort($0) } ?? "—",
            live: live,
            isSelected: !isSelectingForInvoice && store.selectedProjectID == project.id,
            isInvoiceMode: isSelectingForInvoice,
            isChecked: invoiceSelection.contains(project.id)
        ) {
            if isSelectingForInvoice {
                toggleInvoiceMembership(project.id)
            } else {
                store.selectProject(project.id)
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Ledger.ink)
                .frame(height: 1)

            Group {
                if isAddingProject {
                    TextField("", text: $newProjectName)
                        .textFieldStyle(.plain)
                        .font(LedgerType.text(14))
                        .foregroundStyle(Ledger.ink)
                        .focused($newProjectFieldFocused)
                        .onSubmit(commitNewProject)
                        .onExitCommand {
                            isAddingProject = false
                            newProjectName = ""
                        }
                        .windowPlaceholder(
                            "Project name, then Enter",
                            isVisible: newProjectName.isEmpty,
                            font: LedgerType.text(14),
                            color: Ledger.ink3
                        )
                        .accessibilityLabel("New project name")
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                                .fill(Ledger.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                                .strokeBorder(Ledger.ink, lineWidth: 2)
                        )
                        .onAppear { newProjectFieldFocused = true }
                } else {
                    Button {
                        beginAddingProject()
                    } label: {
                        HStack {
                            Text("New project")
                            Spacer(minLength: 8)
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LedgerOutlineButtonStyle())
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private func detailView(asOf date: Date) -> some View {
        if !isSelectingForInvoice && store.selectedProject == nil {
            emptyState
        } else {
            GeometryReader { geo in
                let horizontalPadding = min(56, max(24, geo.size.width * 0.06))
                let contentWidth = max(0, geo.size.width - horizontalPadding * 2)

                ScrollView {
                    Group {
                        if isSelectingForInvoice {
                            invoicePane(asOf: date, contentWidth: contentWidth)
                        } else if let project = store.selectedProject {
                            projectDetail(project, asOf: date, contentWidth: contentWidth)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 40)
                    .padding(.bottom, 64)
                }
            }
            .background(Ledger.paper)
        }
    }

    private func projectDetail(_ project: FlowProject, asOf date: Date, contentWidth: CGFloat) -> some View {
        let index = store.projects.firstIndex(where: { $0.id == project.id }) ?? 0
        let isTimerProject = store.timer.projectID == project.id && store.timer.isActive
        let elapsed = isTimerProject ? store.elapsedTime(asOf: date) : 0
        let sessions = store.sessions
            .filter { $0.projectID == project.id }
            .sorted { $0.startedAt > $1.startedAt }
        let total = store.totalTrackedTime(for: project.id) + elapsed
        let week = WeekBarsData(sessions: sessions, liveToday: elapsed)
        let otherTimerName: String? = (store.timer.isActive && !isTimerProject)
            ? store.timer.projectID.map { store.projectName(for: $0) }
            : nil

        return VStack(alignment: .leading, spacing: 40) {
            detailHeader(project, index: index, sessionCount: sessions.count, contentWidth: contentWidth)

            kpiStrip(
                project: project,
                total: total,
                earnings: store.earnings(for: project.id, asOf: date),
                week: week.total,
                contentWidth: contentWidth
            )

            WindowTimerBand(
                store: store,
                project: project,
                elapsed: elapsed,
                otherTimerProjectName: otherTimerName
            )

            weekSection(week)

            sessionsSection(project: project, sessions: sessions, isWide: contentWidth >= 600)
        }
    }

    private func detailHeader(
        _ project: FlowProject,
        index: Int,
        sessionCount: Int,
        contentWidth: CGFloat
    ) -> some View {
        let titleSize = min(88, max(48, contentWidth * 0.13))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                Text(String(format: "No. %02d", index + 1))
                    .fontWeight(.semibold)
                    .foregroundStyle(Ledger.ink)
                Text(verbatim: "Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                Text(sessionCountLabel(sessionCount))
            }
            .font(LedgerType.mono(12))
            .foregroundStyle(Ledger.ink2)
            .lineLimit(1)

            Text(project.name)
                .font(LedgerType.display(titleSize))
                .tracking(-titleSize * 0.05)
                .foregroundStyle(Ledger.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(.vertical, -titleSize * 0.12)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: KPI strip

    private func kpiStrip(
        project: FlowProject,
        total: TimeInterval,
        earnings: Double?,
        week: TimeInterval,
        contentWidth: CGFloat
    ) -> some View {
        let totalCell = kpiCell("Total time") {
            kpiValue(TimeFormatting.shortSummary(for: total))
        }
        let earnedCell = kpiCell("Earned") {
            kpiValue(earnings.map { FTFormat.money($0) } ?? "—")
        }
        let rateCell = kpiCell("Hourly rate") {
            WindowRateField(
                rate: project.hourlyRate,
                onSet: { store.setHourlyRate($0, for: project.id) }
            )
            .id(project.id)
        }
        let weekCell = kpiCell("This week") {
            kpiValue(TimeFormatting.shortSummary(for: week))
        }

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Ledger.ink)
                .frame(height: 2)

            if contentWidth >= 640 {
                HStack(alignment: .top, spacing: 0) {
                    totalCell
                    earnedCell
                    rateCell
                    weekCell
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        totalCell
                        earnedCell
                    }
                    HStack(alignment: .top, spacing: 0) {
                        rateCell
                        weekCell
                    }
                }
            }
        }
    }

    private func kpiCell<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LedgerLabel(label)
            value()
        }
        .padding(.top, 16)
        .padding(.trailing, 20)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kpiValue(_ text: String) -> some View {
        Text(text)
            .font(LedgerType.text(34, weight: .bold))
            .tracking(-1.02)
            .monospacedDigit()
            .foregroundStyle(Ledger.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
    }

    // MARK: Section header

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(LedgerType.text(22, weight: .bold))
                .tracking(-0.44)
                .foregroundStyle(Ledger.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            Text(trailing)
                .font(LedgerType.mono(12))
                .foregroundStyle(Ledger.ink)
        }
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Ledger.ink).frame(height: 2)
        }
    }

    // MARK: Last 7 days

    private func weekSection(_ data: WeekBarsData) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader("Last 7 days", trailing: "\(TimeFormatting.shortSummary(for: data.total)) tracked")
            weekChart(data)
        }
    }

    private func weekChart(_ data: WeekBarsData) -> some View {
        let plotHeight: CGFloat = 162
        let scale = max(4 * 3600, data.max)
        let labels = weekDayLabels(data)
        let dash = StrokeStyle(lineWidth: 1, dash: [3, 3])

        return VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    let value = data.values[i]
                    let isToday = i == 6
                    let barHeight = value > 0 ? max(0.02, value / scale * 0.8) * plotHeight : 0

                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 0)
                        if value > 0 {
                            Text(TimeFormatting.shortSummary(for: value))
                                .font(LedgerType.mono(11, weight: .semibold))
                                .foregroundStyle(Ledger.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.bottom, 6)
                        }
                        Rectangle()
                            .fill(isToday ? Ledger.signal : Ledger.ink)
                            .frame(height: barHeight)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(labels[i])
                    .accessibilityValue(value > 0 ? TimeFormatting.shortSummary(for: value) : "No time")
                }
            }
            .frame(height: plotHeight)
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    WindowHorizontalLine()
                        .stroke(Ledger.ruleStrong, style: dash)
                        .frame(height: 1)
                    WindowHorizontalLine()
                        .stroke(Ledger.rule, style: dash)
                        .frame(height: 1)
                        .offset(y: 81)
                }
                .accessibilityHidden(true)
            }

            Rectangle()
                .fill(Ledger.ink)
                .frame(height: 1)

            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { i in
                    Text(labels[i])
                        .font(LedgerType.mono(11, weight: i == 6 ? .bold : .regular))
                        .foregroundStyle(i == 6 ? Ledger.ink : Ledger.ink2)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 9)
            .accessibilityHidden(true)
        }
    }

    /// "Mon 5" style labels, oldest first, matching `WeekBarsData` ordering.
    private func weekDayLabels(_ data: WeekBarsData) -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).map { i in
            let day = calendar.date(byAdding: .day, value: i - 6, to: today) ?? today
            return "\(data.labels[i]) \(calendar.component(.day, from: day))"
        }
    }

    // MARK: Sessions

    private func sessionsSection(project: FlowProject, sessions: [FlowSession], isWide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Sessions", trailing: sessionCountLabel(sessions.count))

            if sessions.isEmpty {
                Text("No sessions yet. Start the timer to log your first one.")
                    .font(LedgerType.text(14))
                    .foregroundStyle(Ledger.ink2)
                    .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sessions) { session in
                        WindowSessionRow(
                            date: session.startedAt.formatted(
                                .dateTime.weekday(.abbreviated).month(.abbreviated).day()
                            ),
                            task: session.taskName.isEmpty ? "Untitled session" : session.taskName,
                            range: "\(FTFormat.timeOfDay(session.startedAt)) – \(FTFormat.timeOfDay(session.endedAt))",
                            duration: TimeFormatting.shortSummary(for: session.duration),
                            amount: project.hourlyRate.map { FTFormat.money((session.duration / 3600) * $0) } ?? "—",
                            isWide: isWide
                        )
                    }
                }
            }
        }
    }

    // MARK: Invoice

    private func invoicePane(asOf date: Date, contentWidth: CGFloat) -> some View {
        let colors = Dictionary(
            store.projects.enumerated().map { ($0.element.id, FolderPalette.color(for: $0.element, index: $0.offset)) },
            uniquingKeysWith: { first, _ in first }
        )

        return InvoiceSummaryView(
            summary: store.invoiceSummary(for: invoiceSelection),
            colors: colors,
            asOf: date,
            isCompact: contentWidth < 620,
            onClose: { isSelectingForInvoice = false }
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.projects.isEmpty ? "No projects yet." : "No project selected.")
                .font(LedgerType.display(48))
                .tracking(-1.92)
                .foregroundStyle(Ledger.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(
                store.projects.isEmpty
                    ? "Press + or New project to start your first one."
                    : "Pick one on the left, or press + to start a new one."
            )
            .font(LedgerType.text(15))
            .foregroundStyle(Ledger.ink2)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ledger.paper)
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
        newProjectFieldFocused = true
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
        isSelectingForInvoice = false
    }
}

// MARK: - Sidebar row

private enum WindowLiveState {
    case idle, running, paused
}

private struct WindowProjectRow: View {
    let number: Int
    let name: String
    let color: Color
    let total: String
    let earnings: String
    let live: WindowLiveState
    let isSelected: Bool
    let isInvoiceMode: Bool
    let isChecked: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var foreground: Color { isSelected ? Ledger.invText : Ledger.ink }
    private var subtext: Color { isSelected ? selectedRowSubtext : Ledger.ink2 }
    private var background: Color {
        if isSelected { return Ledger.ink }
        return isHovering ? Ledger.hover : .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(String(format: "%02d", number))
                    .font(LedgerType.mono(12, weight: .semibold))
                    .foregroundStyle(isSelected ? Ledger.signal : Ledger.ink3)
                    .frame(width: 30, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        LedgerSwatch(color: color)
                        Text(name)
                            .font(LedgerType.text(15, weight: .semibold))
                            .tracking(-0.15)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Text(total)
                        .font(LedgerType.mono(11.5))
                        .foregroundStyle(subtext)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    if live != .idle {
                        WindowBlinkSquare(size: 8, color: Ledger.signal, isBlinking: live == .running)
                    }
                    if isInvoiceMode {
                        checkbox
                    } else {
                        Text(earnings)
                            .font(LedgerType.mono(12, weight: .medium))
                    }
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .background(background)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Ledger.rule).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected || (isInvoiceMode && isChecked) ? .isSelected : [])
    }

    private var checkbox: some View {
        Rectangle()
            .fill(isChecked ? Ledger.signal : Color.clear)
            .frame(width: 20, height: 20)
            .overlay(
                Rectangle().strokeBorder(foreground, lineWidth: 1.5)
            )
            .overlay {
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Ledger.ink)
                }
            }
            .accessibilityHidden(true)
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if isInvoiceMode {
            parts.append(isChecked ? "Included in invoice" : "Not in invoice")
        }
        switch live {
        case .running: parts.append("Recording")
        case .paused: parts.append("Paused")
        case .idle: break
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Blinking status square

private struct WindowBlinkSquare: View {
    let size: CGFloat
    let color: Color
    var isBlinking = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isBlinking && !reduceMotion {
            LedgerSwatch(color: color, size: size)
                .phaseAnimator([1.0, 0.25]) { content, opacity in
                    content.opacity(opacity)
                } animation: { _ in
                    .easeInOut(duration: 0.6)
                }
                .accessibilityHidden(true)
        } else {
            LedgerSwatch(color: color, size: size)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Hourly rate field

private struct WindowRateField: View {
    let rate: Double?
    let onSet: (Double?) -> Void

    @State private var isEditing = false
    @State private var input = ""
    @FocusState private var isFocused: Bool

    private let valueFont = LedgerType.text(34, weight: .bold)

    var body: some View {
        if isEditing {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("$")
                    .font(valueFont)
                TextField("", text: $input)
                    .textFieldStyle(.plain)
                    .font(valueFont)
                    .monospacedDigit()
                    .frame(width: 88)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onExitCommand(perform: cancel)
                    .accessibilityLabel("Hourly rate in dollars")
                Text("/hr")
                    .font(LedgerType.text(16))
                    .foregroundStyle(Ledger.ink2)
            }
            .tracking(-1.02)
            .foregroundStyle(Ledger.ink)
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Ledger.signal).frame(height: 2)
            }
            .fixedSize()
            .onAppear { isFocused = true }
            .onChange(of: isFocused) { _, focused in
                if !focused && isEditing { commit() }
            }
            .onChange(of: input) { _, newValue in
                let cleaned = String(newValue.filter { "0123456789.".contains($0) }.prefix(8))
                if cleaned != newValue { input = cleaned }
            }
        } else {
            Button {
                input = rate.map { String(format: "%.0f", $0) } ?? ""
                isEditing = true
            } label: {
                Text(rate.map { "\(FTFormat.money($0, decimals: 0))/hr" } ?? "Set rate")
                    .font(valueFont)
                    .tracking(-1.02)
                    .monospacedDigit()
                    .foregroundStyle(Ledger.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.bottom, 2)
                    .overlay(alignment: .bottom) {
                        WindowHorizontalLine()
                            .stroke(Ledger.ink3, style: StrokeStyle(lineWidth: 2, dash: [2, 3]))
                            .frame(height: 2)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(rate == nil ? "Set an hourly rate" : "Edit hourly rate")
            .accessibilityLabel("Hourly rate")
            .accessibilityValue(rate.map { "\(FTFormat.money($0, decimals: 0)) per hour" } ?? "Not set")
        }
    }

    private func commit() {
        let value = Double(input.trimmingCharacters(in: .whitespaces))
        onSet((value ?? 0) > 0 ? value.map { $0.rounded() } : nil)
        isEditing = false
    }

    private func cancel() {
        isEditing = false
    }
}

// MARK: - Timer band

private struct WindowTimerBand: View {
    @Bindable var store: FlowTrackStore
    let project: FlowProject
    let elapsed: TimeInterval
    let otherTimerProjectName: String?

    private var isTimerProject: Bool {
        store.timer.projectID == project.id && store.timer.isActive
    }
    private var isRunning: Bool { isTimerProject && store.timer.isRunning }
    private var isPaused: Bool { isTimerProject && store.timer.isPaused }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            statusRow

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 0) {
                    clock(size: 136, scales: false)
                        .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
                    Spacer(minLength: 28)
                    controls
                }
                HStack(alignment: .bottom, spacing: 0) {
                    clock(size: 112, scales: false)
                        .alignmentGuide(.bottom) { $0[.lastTextBaseline] }
                    Spacer(minLength: 28)
                    controls
                }
                VStack(alignment: .leading, spacing: 28) {
                    clock(size: 136, scales: true)
                    controls
                }
            }

            taskRow
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ledger.ink)
        .environment(\.colorScheme, .dark)
        .tint(Ledger.signal)
    }

    // Status

    private var statusTitle: String {
        if isRunning { return "Recording" }
        if isPaused { return "Paused" }
        return "Ready to track"
    }

    private var trackingLabel: String {
        if isTimerProject { return "Logging to \(project.name)" }
        if let otherTimerProjectName { return "Timer active on \(otherTimerProjectName)" }
        return "Logs to \(project.name)"
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                if isRunning {
                    WindowBlinkSquare(size: 10, color: Ledger.signal)
                } else {
                    LedgerSwatch(color: isPaused ? Ledger.invText : Ledger.invOff, size: 10)
                        .accessibilityHidden(true)
                }
                Text(statusTitle.uppercased())
                    .font(LedgerType.mono(12, weight: .medium))
                    .tracking(0.96)
                    .foregroundStyle(Ledger.invText)
            }
            Spacer(minLength: 12)
            Text(trackingLabel)
                .font(LedgerType.mono(12))
                .foregroundStyle(Ledger.invMuted)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // Clock

    private func clock(size: CGFloat, scales: Bool) -> some View {
        let string = TimeFormatting.clockString(for: elapsed)
        let digitColor = isTimerProject ? Ledger.invText : Ledger.invDim
        let colon = Text(verbatim: ":").foregroundStyle(Ledger.signal)
        let text = string
            .split(separator: ":", omittingEmptySubsequences: false)
            .enumerated()
            .reduce(Text(verbatim: "")) { result, part in
                let digits = Text(String(part.element)).foregroundStyle(digitColor)
                return part.offset == 0 ? Text("\(result)\(digits)") : Text("\(result)\(colon)\(digits)")
            }

        return text
            .font(LedgerType.text(size, weight: .medium))
            .monospacedDigit()
            .tracking(-size * 0.04)
            .lineLimit(1)
            .minimumScaleFactor(scales ? 0.35 : 1)
            // Trim SF's ascender/descender whitespace so the digits sit tight like the 0.85 line-height mock.
            .padding(.vertical, -size * 0.18)
            .accessibilityLabel("Elapsed time \(string)")
    }

    // Controls

    private var primaryTitle: String {
        if isRunning { return "Pause" }
        return isPaused ? "Resume" : "Start"
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                if isRunning {
                    store.pauseTimer()
                } else {
                    store.startTimer()
                }
            } label: {
                HStack(spacing: 0) {
                    Text(primaryTitle)
                        .font(LedgerType.text(17, weight: .bold))
                    Spacer(minLength: 18)
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(minWidth: 108)
                .padding(.horizontal, 6)
            }
            .buttonStyle(LedgerSignalButtonStyle(height: 64))
            .fixedSize()
            .help(isRunning ? "Pause the timer" : (isPaused ? "Resume the timer" : "Start tracking \(project.name)"))

            Button {
                _ = store.stopTimer()
            } label: {
                Rectangle()
                    .fill(isTimerProject ? Ledger.invText : Ledger.invOff)
                    .frame(width: 12, height: 12)
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                            .strokeBorder(isTimerProject ? Ledger.invText : Ledger.invRule, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isTimerProject)
            .help("Stop and save session")
            .accessibilityLabel("Stop and save session")
        }
    }

    // Task

    private var taskRow: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Ledger.invRule)
                .frame(height: 1)

            HStack(spacing: 12) {
                LedgerLabel("Task", color: Ledger.invMuted)
                    .frame(width: 64, alignment: .leading)
                    .accessibilityHidden(true)

                TextField("", text: $store.activeTaskName)
                    .textFieldStyle(.plain)
                    .font(LedgerType.text(20, weight: .medium))
                    .foregroundStyle(Ledger.invText)
                    .windowPlaceholder(
                        "What are you working on?",
                        isVisible: store.activeTaskName.isEmpty,
                        font: LedgerType.text(20, weight: .medium),
                        color: Ledger.invMuted
                    )
                    .frame(height: 44)
                    .accessibilityLabel("Task")
            }
            .padding(.top, 18)
        }
    }
}

// MARK: - Session row

private struct WindowSessionRow: View {
    let date: String
    let task: String
    let range: String
    let duration: String
    let amount: String
    let isWide: Bool

    @State private var isHovering = false

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 12) {
                    Text(date)
                        .font(LedgerType.mono(12))
                        .foregroundStyle(Ledger.ink2)
                        .lineLimit(1)
                        .frame(width: 120, alignment: .leading)
                    taskText
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(range)
                        .font(LedgerType.mono(12))
                        .foregroundStyle(Ledger.ink2)
                        .lineLimit(1)
                        .frame(width: 170, alignment: .leading)
                    Text(duration)
                        .font(LedgerType.mono(13))
                        .lineLimit(1)
                        .frame(width: 80, alignment: .trailing)
                    Text(amount)
                        .font(LedgerType.mono(13, weight: .semibold))
                        .lineLimit(1)
                        .frame(width: 90, alignment: .trailing)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        taskText
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(amount)
                            .font(LedgerType.mono(13, weight: .semibold))
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(verbatim: "\(date) · \(range)")
                            .font(LedgerType.mono(12))
                            .foregroundStyle(Ledger.ink2)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(duration)
                            .font(LedgerType.mono(13))
                    }
                }
            }
        }
        .foregroundStyle(Ledger.ink)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(minHeight: 56)
        .background(isHovering ? Ledger.surface : Color.clear)
        .padding(.horizontal, -8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Ledger.rule).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
    }

    private var taskText: some View {
        Text(task)
            .font(LedgerType.text(15, weight: .semibold))
            .tracking(-0.15)
            .lineLimit(1)
    }
}

// MARK: - Invoice document

struct InvoiceSummaryView: View {
    let summary: InvoiceSummary
    var colors: [UUID: Color] = [:]
    var asOf: Date = .now
    var isCompact = false
    let onClose: () -> Void

    @State private var copied = false

    private var numberColumn: CGFloat { isCompact ? 64 : 90 }
    private var amountColumn: CGFloat { isCompact ? 92 : 110 }
    private var dateLabel: String { asOf.formatted(.dateTime.month(.wide).day().year()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 12) {
                Text("Tick projects on the left to add them.")
                    .font(LedgerType.mono(12))
                    .foregroundStyle(Ledger.ink2)
                Spacer(minLength: 12)
                HStack(spacing: 8) {
                    Button(copied ? "Copied" : "Copy summary", action: copySummary)
                        .buttonStyle(LedgerOutlineButtonStyle())
                        .disabled(summary.lines.isEmpty)
                        .opacity(summary.lines.isEmpty ? 0.45 : 1)
                        .help("Copy a plain-text summary")
                    Button("Done", action: onClose)
                        .buttonStyle(LedgerSignalButtonStyle())
                        .help("Close the invoice")
                }
                .fixedSize()
            }

            sheet
        }
        .frame(maxWidth: 760, alignment: .leading)
        .onChange(of: summary) { copied = false }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invoice")
                        .font(LedgerType.display(44))
                        .tracking(-1.76)
                        .foregroundStyle(Ledger.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: "\(summary.lines.count) project\(summary.lines.count == 1 ? "" : "s") combined")
                        .font(LedgerType.mono(12))
                        .foregroundStyle(Ledger.ink2)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Draft")
                    Text(dateLabel)
                }
                .font(LedgerType.mono(12))
                .foregroundStyle(Ledger.ink2)
            }
            .padding(.bottom, 32)

            Rectangle()
                .fill(Ledger.ink)
                .frame(height: 2)

            HStack(spacing: 12) {
                LedgerLabel("Project")
                    .frame(maxWidth: .infinity, alignment: .leading)
                LedgerLabel("Hours")
                    .frame(width: numberColumn, alignment: .trailing)
                LedgerLabel("Rate")
                    .frame(width: numberColumn, alignment: .trailing)
                LedgerLabel("Amount")
                    .frame(width: amountColumn, alignment: .trailing)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { hairline }

            if summary.lines.isEmpty {
                Text("Nothing selected yet.")
                    .font(LedgerType.text(15))
                    .foregroundStyle(Ledger.ink2)
                    .padding(.vertical, 28)
            }

            ForEach(summary.lines) { line in
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        LedgerSwatch(color: colors[line.id] ?? Ledger.ink3)
                        Text(line.name)
                            .font(LedgerType.text(15, weight: .semibold))
                            .foregroundStyle(Ledger.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(String(format: "%.2f", line.hours))
                        .frame(width: numberColumn, alignment: .trailing)
                    Text(line.rate.map { FTFormat.money($0, decimals: 0) } ?? "—")
                        .frame(width: numberColumn, alignment: .trailing)
                    Text(line.amount.map { FTFormat.money($0) } ?? "—")
                        .fontWeight(.semibold)
                        .frame(width: amountColumn, alignment: .trailing)
                }
                .font(LedgerType.mono(13))
                .foregroundStyle(Ledger.ink)
                .lineLimit(1)
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) { hairline }
                .accessibilityElement(children: .combine)
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(String(format: "TOTAL — %.2f h", summary.totalHours))
                    .font(LedgerType.mono(12, weight: .semibold))
                    .foregroundStyle(Ledger.ink)
                Spacer(minLength: 12)
                Text(FTFormat.money(summary.totalAmount))
                    .font(LedgerType.display(52))
                    .tracking(-2.08)
                    .monospacedDigit()
                    .foregroundStyle(Ledger.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.top, 28)

            if summary.hasUnratedProjects {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("Some projects have no hourly rate and are excluded from the dollar total.")
                }
                .font(LedgerType.text(12))
                .foregroundStyle(Ledger.ink2)
                .padding(.top, 20)
            }
        }
        .padding(isCompact ? 28 : 48)
        .background(
            Rectangle()
                .fill(Ledger.surface)
                .shadow(color: Ledger.ink.opacity(0.08), radius: 30, y: 24)
        )
        .overlay(
            Rectangle().strokeBorder(Ledger.rule, lineWidth: 1)
        )
    }

    private var hairline: some View {
        Rectangle().fill(Ledger.rule).frame(height: 1)
    }

    private var plainTextSummary: String {
        var lines = ["Invoice — \(dateLabel)", ""]
        for line in summary.lines {
            let rate = line.rate.map { "\(FTFormat.money($0, decimals: 0))/hr" } ?? "no rate"
            let amount = line.amount.map { FTFormat.money($0) } ?? "—"
            lines.append("\(line.name)  \(String(format: "%.2f", line.hours)) h  \(rate)  \(amount)")
        }
        lines.append("")
        lines.append("Total  \(String(format: "%.2f", summary.totalHours)) h  \(FTFormat.money(summary.totalAmount))")
        if summary.hasUnratedProjects {
            lines.append("Projects without an hourly rate are excluded from the dollar total.")
        }
        return lines.joined(separator: "\n")
    }

    private func copySummary() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainTextSummary, forType: .string)
        copied = true
    }
}

// MARK: - Small helpers

private struct WindowHorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private extension View {
    /// Placeholder drawn under a plain `TextField` so its color can follow the Ledger palette.
    func windowPlaceholder(_ text: String, isVisible: Bool, font: Font, color: Color) -> some View {
        background(alignment: .leading) {
            if isVisible {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
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
