import AppKit
import Observation
import SwiftUI

struct MenuBarContentView: View {
    @Bindable var store: FlowTrackStore
    let openCompanion: () -> Void

    /// Confirmation for the session just saved with Stop; cleared on the next start.
    @State private var lastSaved: FlowSession?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 0) {
                header(date: context.date)

                if store.projects.isEmpty {
                    emptyState
                } else {
                    projectGrid
                    timerPanel(asOf: context.date)
                }

                if let lastSaved {
                    savedRow(lastSaved)
                }

                footer
            }
            .frame(width: 440)
            .background(Ledger.paper)
            .preferredColorScheme(.light)
        }
    }

    private var isRunning: Bool { store.timer.isRunning }
    private var isPaused: Bool { store.timer.isPaused }

    // MARK: - Header

    private func header(date: Date) -> some View {
        HStack {
            LedgerLabel("Project")
            Spacer()
            LedgerLabel(
                date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                color: Ledger.ink2
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    // MARK: - Project chips

    private var projectGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ],
            spacing: 6
        ) {
            ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, project in
                ProjectChip(
                    project: project,
                    index: index,
                    isSelected: store.selectedProjectID == project.id
                ) {
                    store.selectProject(project.id)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    // MARK: - Timer panel

    private func timerPanel(asOf date: Date) -> some View {
        let isTimerSelected = store.timer.projectID == store.selectedProjectID && store.timer.isActive
        let elapsed = isTimerSelected ? store.elapsedTime(asOf: date) : 0
        let rate = store.selectedProject?.hourlyRate
        let liveEarnings = rate.map { (elapsed / 3600) * $0 }

        return VStack(alignment: .leading, spacing: 16) {
            statusRow(earnings: isTimerSelected ? liveEarnings : nil)

            HStack(alignment: .bottom, spacing: 0) {
                ClockReadout(elapsed: elapsed, isLit: isTimerSelected)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    primaryButton(isTimerSelected: isTimerSelected)
                    stopButton
                }
                .fixedSize()
            }

            taskRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ledger.ink)
    }

    private func statusRow(earnings: Double?) -> some View {
        HStack(spacing: 8) {
            StatusDot(mode: isRunning ? .recording : isPaused ? .paused : .idle)

            Text(statusLabel.uppercased())
                .font(LedgerType.mono(11))
                .tracking(11 * 0.08)
                .foregroundStyle(Ledger.invText)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if let earnings {
                Text(FTFormat.money(earnings))
                    .font(LedgerType.mono(11, weight: .semibold))
                    .foregroundStyle(Ledger.invText)
                    .accessibilityLabel("Earned this session")
                    .accessibilityValue(FTFormat.money(earnings))
            }
        }
    }

    private var statusLabel: String {
        if isRunning {
            let name = store.timer.projectID.map { store.projectName(for: $0) } ?? ""
            return name.isEmpty ? "Recording" : "Recording — \(name)"
        }
        return isPaused ? "Paused" : "Ready"
    }

    private func primaryButton(isTimerSelected: Bool) -> some View {
        let title = isRunning ? "Pause" : (isPaused && isTimerSelected ? "Resume" : "Start")

        return Button {
            if isRunning {
                store.pauseTimer()
            } else {
                lastSaved = nil
                store.startTimer()
            }
        } label: {
            HStack(spacing: 0) {
                Text(title)
                Spacer(minLength: 12)
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .accessibilityHidden(true)
            }
            // 112pt minimum including the style's 18pt side padding.
            .frame(minWidth: 112 - 36)
        }
        .buttonStyle(LedgerSignalButtonStyle(height: 52))
    }

    private var stopButton: some View {
        let isActive = store.timer.isActive

        return Button {
            lastSaved = store.stopTimer()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: 11, weight: .bold))
        }
        .buttonStyle(InvertedOutlineButtonStyle(isActive: isActive))
        .disabled(!isActive)
        .help("Stop & save")
        .accessibilityLabel("Stop and save session")
    }

    private var taskRow: some View {
        HStack(spacing: 8) {
            LedgerLabel("Task", color: Ledger.invMuted)
                .frame(width: 44, alignment: .leading)
                .accessibilityHidden(true)

            TextField(
                "Task",
                text: $store.activeTaskName,
                prompt: Text("What are you working on?").foregroundStyle(Ledger.invMuted)
            )
            .textFieldStyle(.plain)
            .font(LedgerType.text(16, weight: .medium))
            .foregroundStyle(Ledger.invText)
            // Light insertion point and selection on the ink panel.
            .environment(\.colorScheme, .dark)
            .frame(height: 40)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Ledger.invRule)
                .frame(height: 1)
        }
    }

    // MARK: - Saved confirmation

    private func savedRow(_ session: FlowSession) -> some View {
        let task = session.taskName
        let label = "Saved \(savedDuration(session.duration)) to \(store.projectName(for: session.projectID))"
            + (task.isEmpty ? "" : " — \(task)")

        return Text(label)
            .font(LedgerType.mono(12))
            .foregroundStyle(Ledger.ink)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Ledger.rule)
                    .frame(height: 1)
            }
    }

    private func savedDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        return seconds < 60 ? "\(max(1, seconds))s" : TimeFormatting.shortSummary(for: duration)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No projects yet")
                .font(LedgerType.text(14, weight: .semibold))
                .foregroundStyle(Ledger.ink)
            Text("Open FlowTrack to add one.")
                .font(LedgerType.text(13))
                .foregroundStyle(Ledger.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .overlay(
            RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                .strokeBorder(Ledger.ruleStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(LedgerType.text(13, weight: .semibold))
                    .foregroundStyle(Ledger.ink2)
                    .footerHitArea()
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                openCompanion()
            } label: {
                HStack(spacing: 8) {
                    Text("Open FlowTrack")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .accessibilityHidden(true)
                }
                .font(LedgerType.text(13, weight: .bold))
                .foregroundStyle(Ledger.ink)
                .footerHitArea()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - Pieces

private struct ProjectChip: View {
    let project: FlowProject
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
    }

    private var fill: Color {
        if isSelected { return Ledger.ink }
        return isHovered ? Ledger.hover : .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(String(format: "%02d", index + 1))
                    .font(LedgerType.mono(11, weight: .semibold))
                    .foregroundStyle(isSelected ? Ledger.signal : Ledger.ink3)
                    .frame(width: 22, alignment: .leading)

                Text(project.name)
                    .font(LedgerType.text(14, weight: .semibold))
                    .foregroundStyle(isSelected ? Ledger.paper : Ledger.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LedgerSwatch(color: FolderPalette.color(for: project, index: index), size: 8)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(isSelected ? Ledger.ink : Ledger.ruleStrong, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(project.name)
        .accessibilityLabel(project.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Big HH:MM:SS readout with signal-colored colons and fixed-width digits.
private struct ClockReadout: View {
    let elapsed: TimeInterval
    let isLit: Bool

    private static let size: CGFloat = 56

    var body: some View {
        let clock = TimeFormatting.clockString(for: elapsed)

        Text(Self.styled(clock))
            .font(LedgerType.text(Self.size, weight: .medium))
            .monospacedDigit()
            .tracking(LedgerType.tracking(for: Self.size))
            .foregroundStyle(isLit ? Ledger.invText : Ledger.invDim)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // Trim SF Pro's ascender/descender space so the box is ~0.85em tall
            // and the digits sit on the button baseline, as in the design.
            .padding(.top, -Self.size * 0.19)
            .padding(.bottom, -Self.size * 0.14)
            .accessibilityElement()
            .accessibilityLabel("Elapsed time")
            .accessibilityValue(clock)
    }

    private static func styled(_ clock: String) -> AttributedString {
        var result = AttributedString()
        for (offset, part) in clock.split(separator: ":").enumerated() {
            if offset > 0 {
                var colon = AttributedString(":")
                colon.swiftUI.foregroundColor = Ledger.signal
                result += colon
            }
            result += AttributedString(String(part))
        }
        return result
    }
}

private struct StatusDot: View {
    enum Mode { case recording, paused, idle }

    let mode: Mode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        switch mode {
        case .recording: Ledger.signal
        case .paused: Ledger.invText
        case .idle: Ledger.invOff
        }
    }

    var body: some View {
        Group {
            if mode == .recording && !reduceMotion {
                // Hard on/off blink, 1.2s period.
                TimelineView(.periodic(from: .now, by: 0.6)) { context in
                    let phase = Int((context.date.timeIntervalSinceReferenceDate / 0.6).rounded())
                    LedgerSwatch(color: color, size: 8)
                        .opacity(phase.isMultiple(of: 2) ? 1 : 0.25)
                }
            } else {
                LedgerSwatch(color: color, size: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 52pt square outline button for the ink timer panel (Stop).
private struct InvertedOutlineButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)

        configuration.label
            .foregroundStyle(isActive ? Ledger.invText : Ledger.invOff)
            .frame(width: 52, height: 52)
            .background(shape.fill(configuration.isPressed ? Ledger.invRule : .clear))
            .overlay(shape.strokeBorder(isActive ? Ledger.invText : Ledger.invRule, lineWidth: 1))
            .contentShape(shape)
    }
}

private extension View {
    func footerHitArea() -> some View {
        padding(.horizontal, 12)
            .frame(height: 46)
            .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var store = FlowTrackStore(persistence: .inMemory)

    MenuBarContentView(store: store, openCompanion: {})
        .task {
            if store.projects.isEmpty {
                store.addProject(named: "YF April 28 →")
                store.addProject(named: "YF May 11th")
                store.addProject(named: "YF May 22")
                store.addProject(named: "June 10th")
                if let projectID = store.projects.last?.id {
                    store.selectProject(projectID)
                }
                store.activeTaskName = "Menu bar redesign"
            }
        }
}
