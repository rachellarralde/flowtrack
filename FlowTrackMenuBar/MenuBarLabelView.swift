import SwiftUI

struct MenuBarLabelView: View {
    let store: FlowTrackStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let title = store.menuBarTitle(asOf: context.date)

            HStack(spacing: 6) {
                Image(systemName: store.menuBarSymbolName)
                    .symbolRenderingMode(.hierarchical)
                if title != "FlowTrack" {
                    Text(title)
                        .font(.system(.callout, design: .rounded))
                        .monospacedDigit()
                }
            }
            .fixedSize()
        }
    }
}

#Preview {
    MenuBarLabelView(store: FlowTrackStore(persistence: .inMemory))
}
