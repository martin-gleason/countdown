// Created: 2026-11-10 07:51 -06:00 · Edited: 2026-11-10 07:51 -06:00
import SwiftUI
import WidgetKit
import CountdownCore

/// The one renderer (`FR9`): lays out a `CountdownDisplay` the way a style says, for one
/// family. The system draws the background and the glass (`NFR3`); this draws text only.
struct StyleView: View {
    let display: CountdownDisplay
    let style: CountdownStyle
    let family: Family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(display.inline)
        case .accessoryCircular, .accessoryCorner:
            VStack(spacing: -2) {
                number(display.rows.first)
                    .minimumScaleFactor(0.4)
                unit(display.rows.first)
                    .font(.system(.caption2, design: .rounded))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                if !display.label.isEmpty {
                    Text(display.label).font(.headline).lineLimit(1)
                }
                rowsInline
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemSmall, .systemMedium:
            VStack(alignment: .leading, spacing: 4) {
                if !display.label.isEmpty {
                    Text(display.label).font(.headline).lineLimit(1)
                }
                ForEach(Array(display.rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        number(row).minimumScaleFactor(0.5)
                        unit(row).font(.subheadline)
                    }
                }
                Spacer(minLength: 0)
                Text(display.targetDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Rectangular: one row as "34,872 hours"; Stacked's three as "3y 7m 20d".
    private var rowsInline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            ForEach(Array(display.rows.enumerated()), id: \.offset) { _, row in
                number(row).minimumScaleFactor(0.5)
                unit(row).font(.caption)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func number(_ row: CountdownDisplay.Row?) -> some View {
        let text = Text(row?.number ?? "").font(numberFont)
        if style.accentRole == .number { text.widgetAccentable() } else { text }
    }

    @ViewBuilder
    private func unit(_ row: CountdownDisplay.Row?) -> some View {
        let text = Text(row?.unit ?? "").foregroundStyle(.secondary)
        if style.accentRole == .unit { text.widgetAccentable() } else { text }
    }

    /// The style's typography: SF Pro Rounded and monospaced digits where it says (`NFR3`).
    private var numberFont: Font {
        let t = style.typography
        var font = Font.system(textStyle(t.textStyle), design: t.rounded ? .rounded : .default)
            .weight(weight(t.weight))
        if t.monospacedDigits { font = font.monospacedDigit() }
        return font
    }

    private func textStyle(_ s: CountdownStyle.TextStyle) -> Font.TextStyle {
        switch s {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .caption: .caption
        }
    }

    private func weight(_ w: CountdownStyle.Weight) -> Font.Weight {
        switch w {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}

extension Family {
    /// The core's family for a WidgetKit family; nil for families this project does not draw.
    init?(_ family: WidgetFamily) {
        switch family {
        case .accessoryInline: self = .accessoryInline
        case .accessoryCircular: self = .accessoryCircular
        case .accessoryRectangular: self = .accessoryRectangular
        case .systemSmall: self = .systemSmall
        case .systemMedium: self = .systemMedium
        #if os(watchOS)
        case .accessoryCorner: self = .accessoryCorner
        #endif
        default: return nil
        }
    }
}
