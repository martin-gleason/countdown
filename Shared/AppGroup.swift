// Created: 2026-11-09 07:37 -06:00 · Edited: 2026-11-10 07:54 -06:00
import Foundation

/// The App Group the host app writes and the widget reads (`F1`). One id on both platforms:
/// Xcode's automatic signing refuses to register the Team-ID-prefixed macOS form ("Application
/// Group identifiers should start with 'group.'", 2026-11-10), and Mac profiles have covered
/// `group.` ids since 2025. Must match Entitlements/*.entitlements.
enum AppGroup {
    static let id = "group.com.martingleason.countdown"
}
