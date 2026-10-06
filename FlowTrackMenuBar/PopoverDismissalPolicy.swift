enum PopoverDismissalEvent {
    case keyboardInputInsidePopover
    case mouseDownInsidePopover
    case statusItemClick
    case mouseDownOutsidePopover
    case appDidResignActive
}

struct PopoverDismissalPolicy {
    static func shouldClose(for event: PopoverDismissalEvent) -> Bool {
        switch event {
        case .keyboardInputInsidePopover, .mouseDownInsidePopover, .statusItemClick:
            false
        case .mouseDownOutsidePopover, .appDidResignActive:
            true
        }
    }
}
