// Created: 2026-11-08 21:10 -06:00 · Edited: 2026-11-08 21:10 -06:00
import Foundation

/// Whole hours from `now` until `target`, floored and never rounded up (`FR6`).
/// Negative once the target has passed; the count-up rules (`D16`) are built in `C2`.
public func hoursRemaining(from now: Date, to target: Date) -> Int {
    Int((target.timeIntervalSince(now) / 3600).rounded(.down))
}
