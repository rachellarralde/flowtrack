import SwiftUI

@main
struct FlowTrackMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("FlowTrack Menu Bar")
                    .font(.title3.weight(.semibold))

                Text("Your projects and sessions are saved automatically on this Mac.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 320)
        }
    }
}
