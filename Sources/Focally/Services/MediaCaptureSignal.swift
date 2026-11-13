import Foundation

/// Boolean capture signal emitted by `MediaDeviceCallDetector`.
/// Single source of truth consumed by PresenceCoordinator: the detector is
/// CORROBORATIVE — bundle identity never decides a call, the calendar gate does.
struct CaptureSnapshot {
    /// Any non-noise process captures input (system helpers and own PID excluded).
    let anyInput: Bool
    /// Any trusted native conferencing app has audio OUTPUT running
    /// ("muted but listening" — Zoom/Teams/Slack natives only; browsers excluded).
    let anyOutputNative: Bool
    /// Global camera-in-use boolean (CoreMediaIO has no per-process attribution).
    let cameraRunning: Bool
    /// Known clients for COSMETIC naming only — never a decision input.
    let clients: [CallClient]
}

protocol CaptureSignaling: AnyObject {
    func currentSnapshot() -> CaptureSnapshot
}
