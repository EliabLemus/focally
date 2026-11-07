import Foundation

/// Assigns a status-bar title only when the desired string actually changes.
///
/// `updateStatusBar()` runs on every 1 Hz tick; rewriting `button.title` each
/// tick forces AppKit accessibility/layout work even when nothing changed.
/// The assigner returns the new string only on a transition (nil = no change).
struct StatusTitleAssigner {
    private var lastTitle: String?

    /// Returns the title to apply, or nil when it is unchanged since last call.
    mutating func title(for desired: String) -> String? {
        guard lastTitle != desired else { return nil }
        lastTitle = desired
        return desired
    }

    /// Forces the next call to re-assign (e.g. after the status button is recreated).
    mutating func reset() {
        lastTitle = nil
    }
}
