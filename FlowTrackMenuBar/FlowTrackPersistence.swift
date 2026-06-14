import Foundation

struct FlowTrackPersistence: Sendable {
    var load: @Sendable () -> AppSnapshot?
    var save: @Sendable (AppSnapshot) -> Void

    static let inMemory = FlowTrackPersistence(
        load: { nil },
        save: { _ in }
    )

    static let live: FlowTrackPersistence = {
        let storageURL = storageFileURL()
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return FlowTrackPersistence(
            load: {
                guard let data = try? Data(contentsOf: storageURL) else {
                    return nil
                }

                return try? decoder.decode(AppSnapshot.self, from: data)
            },
            save: { snapshot in
                guard let data = try? encoder.encode(snapshot) else {
                    return
                }

                let folderURL = storageURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                try? data.write(to: storageURL, options: .atomic)
            }
        )
    }()

    private static func storageFileURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseURL
            .appendingPathComponent("FlowTrackMenuBar", isDirectory: true)
            .appendingPathComponent("state.json", isDirectory: false)
    }
}
