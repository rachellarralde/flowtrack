import AppKit
import Observation
import SwiftUI

struct MenuBarContentView: View {
    @Bindable var store: FlowTrackStore
    let openCompanion: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 0) {
                projectTabStrip

                Divider().overlay(FT.line)

                if store.projects.isEmpty {
                    emptyState
                } else {
                    timerSection(asOf: context.date)
                }

                Divider().overlay(FT.line)

                footer
            }
            .frame(width: 440)
            .background(FT.bg1)
            .preferredColorScheme(.dark)
        }
    }

    private var isRunning: Bool { store.timer.isRunning }
    private var isPaused: Bool { store.timer.isPaused }

    // MARK: - Project chips

    private var projectTabStrip: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ],
            spacing: 6
        ) {
            ForEach(Array(store.projects.enumerated()), id: \.element.id) { index, project in
                projectTab(project, index: index)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private func projectTab(_ project: FlowProject, index: Int) -> some View {
        let isSelected = store.selectedProjectID == project.id
        let color = FolderPalette.color(for: project, index: index)

        return Button {
            store.selectProject(project.id)
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: 15, height: 15)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    )

                Text(project.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? FT.accentSoft : FT.bg2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(isSelected ? FT.accent.opacity(0.45) : FT.line, lineWidth: 1)
                    )
            )
            .foregroundStyle(isSelected ? FT.accent : FT.text2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer

    private func timerSection(asOf date: Date) -> some View {
        let isTimerSelected = store.timer.projectID == store.selectedProjectID && store.timer.isActive
        let elapsed = isTimerSelected ? store.elapsedTime(asOf: date) : 0
        let rate = store.selectedProject?.hourlyRate
        let liveEarnings = rate.map { (elapsed / 3600) * $0 }

        return VStack(alignment: .leading, spacing: 14) {
            // Task input
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(FT.text3)
                TextField("What are you working on?", text: $store.activeTaskName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FT.text)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(FT.bg2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(
                                isRunning ? FT.accent.opacity(0.5) : FT.line,
                                lineWidth: isRunning ? 1.5 : 1
                            )
                    )
            )

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(TimeFormatting.clockString(for: elapsed))
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(elapsed == 0 && !isTimerSelected ? FT.text3 : FT.text)
                        .lineLimit(1)
                        .fixedSize()

                    HStack(spacing: 4) {
                        Text(isRunning ? "Recording" : isPaused ? "Paused" : "Ready")
                        if let liveEarnings, isTimerSelected {
                            Text("· ")
                                + Text(FTFormat.money(liveEarnings))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(FT.earn)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(FT.text3)
                    .frame(height: 13)
                }

                Spacer()

                HStack(spacing: 8) {
                    if isRunning {
                        popButton(title: "Pause", icon: "pause.fill", bg: FT.amber, fg: FT.amberFg) {
                            store.pauseTimer()
                        }
                    } else {
                        popButton(
                            title: isPaused && isTimerSelected ? "Resume" : "Start",
                            icon: "play.fill",
                            bg: FT.accent,
                            fg: FT.accentFg
                        ) {
                            store.startTimer()
                        }
                    }

                    Button {
                        _ = store.stopTimer()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(FT.text2)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(FT.bg2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(FT.line, lineWidth: 1)
                                    )
                            )
                            .opacity(store.timer.isActive ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.timer.isActive)
                    .help("Stop & save")
                }
            }
        }
        .padding(14)
    }

    private func popButton(
        title: String,
        icon: String,
        bg: Color,
        fg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(bg))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 24))
                .foregroundStyle(FT.text4)
            Text("No projects yet — open FlowTrack to add one")
                .font(.system(size: 13))
                .foregroundStyle(FT.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(FT.text3)

            Spacer()

            Button {
                openCompanion()
            } label: {
                HStack(spacing: 5) {
                    Text("Open FlowTrack")
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .font(.system(size: 12.5, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(FT.text3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

#Preview {
    @Previewable @State var store = FlowTrackStore(persistence: .inMemory)

    MenuBarContentView(store: store, openCompanion: {})
        .task {
            if store.projects.isEmpty {
                store.addProject(named: "YF April 28 →")
                store.addProject(named: "June 10th")
                if let projectID = store.projects.first?.id {
                    store.selectProject(projectID)
                }
                store.activeTaskName = "Menu bar redesign"
            }
        }
}
