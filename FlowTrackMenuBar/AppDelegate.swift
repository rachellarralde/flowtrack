import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let store = FlowTrackStore()

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private weak var companionWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !terminateIfDuplicateInstance() else { return }

        setupPopover()
        setupStatusItem()
        startRefreshingStatusItem()
    }

    /// Prevents a second copy from adding a duplicate menu bar icon.
    private func terminateIfDuplicateInstance() -> Bool {
        let me = NSRunningApplication.current
        let duplicates = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == me.bundleIdentifier && $0.processIdentifier != me.processIdentifier
        }
        guard !duplicates.isEmpty else { return false }

        // An instance is already running — hand off and quit.
        duplicates.first?.activate()
        NSApp.terminate(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    func popoverDidClose(_ notification: Notification) {
        updateStatusItem()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 440, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(store: store, openCompanion: { [weak self] in
                self?.openCompanionWindow()
            })
        )
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.imagePosition = .imageLeading
        item.button?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        statusItem = item
        updateStatusItem()
    }

    private func startRefreshingStatusItem() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        let elapsed = store.elapsedTime(asOf: Date())

        let symbol = store.timer.isRunning
            ? "record.circle.fill"
            : (store.timer.isPaused ? "pause.circle.fill" : "timer")
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: symbol, accessibilityDescription: "FlowTrack")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.imageScaling = .scaleProportionallyDown
        button.title = elapsed > 0 ? " \(TimeFormatting.clockString(for: elapsed))" : ""
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(store: store, openCompanion: { [weak self] in
                self?.openCompanionWindow()
            })
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openCompanionWindow() {
        popover.performClose(nil)

        if let window = companionWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = store.selectedProject?.name ?? "FlowTrack"
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 860, height: 560)
        window.contentViewController = NSHostingController(
            rootView: CompanionWindowView(store: store)
        )
        window.center()
        // Use a versioned autosave key so old small frames don't restore
        window.setFrameAutosaveName("FlowTrackCompanion-v2")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        companionWindow = window
    }
}
