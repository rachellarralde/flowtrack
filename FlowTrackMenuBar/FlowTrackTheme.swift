import AppKit
import SwiftUI

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Ledger design tokens (light Swiss editorial)

enum Ledger {
    // paper + ink
    static let paper = Color(hex: 0xF5F4F0)        // window ground
    static let paperDeep = Color(hex: 0xEDECE7)    // title strip, pressed
    static let hover = Color(hex: 0xEBEAE4)        // row hover
    static let surface = Color.white               // invoice sheet, table hover
    static let ink = Color(hex: 0x111110)          // primary text, rules, selected rows
    static let ink2 = Color(hex: 0x5F5E59)         // secondary text (5:1 on paper)
    static let ink3 = Color(hex: 0x8A8882)         // placeholder / index numbers
    static let rule = Color(hex: 0xDAD8D1)         // hairlines
    static let ruleStrong = Color(hex: 0xC9C7BF)   // dashed grid, quiet borders

    // signal accent — always under ink text, never as text on paper
    static let signal = Color(hex: 0xFF5A1F)
    static let signalHover = Color(hex: 0xFF7240)
    static let danger = Color(hex: 0xB42318)

    // inverted (black) panels: timer band
    static let invText = Color(hex: 0xF5F4F0)
    static let invMuted = Color(hex: 0xA9A79F)
    static let invRule = Color(hex: 0x3A3936)
    static let invDim = Color(hex: 0x6E6C66)       // idle clock digits
    static let invOff = Color(hex: 0x55534E)       // disabled controls

    static let radius: CGFloat = 4
}

enum LedgerType {
    /// Heavy grotesk for headlines and big numerals.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Tight Swiss tracking for display sizes (about -4%).
    static func tracking(for size: CGFloat) -> CGFloat {
        -size * 0.04
    }
}

/// Small uppercase mono caption ("TOTAL TIME", "TASK").
struct LedgerLabel: View {
    let text: String
    var color: Color = Ledger.ink
    var size: CGFloat = 11

    init(_ text: String, color: Color = Ledger.ink, size: CGFloat = 11) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text.uppercased())
            .font(LedgerType.mono(size, weight: .semibold))
            .tracking(size * 0.08)
            .foregroundStyle(color)
    }
}

/// Square project color chip.
struct LedgerSwatch: View {
    let color: Color
    var size: CGFloat = 9

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Orange block button with ink label (Start, Done).
struct LedgerSignalButtonStyle: ButtonStyle {
    var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LedgerType.text(15, weight: .bold))
            .foregroundStyle(Ledger.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                    .fill(configuration.isPressed ? Ledger.signalHover : Ledger.signal)
            )
            .contentShape(Rectangle())
    }
}

/// 1px ink outline button (Cancel, Copy summary, New project).
struct LedgerOutlineButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    var foreground: Color = Ledger.ink
    var border: Color = Ledger.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LedgerType.text(14, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                    .fill(configuration.isPressed ? Ledger.paperDeep : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Ledger.radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Folder colors

enum FolderPalette {
    static let names = ["orange", "blue", "green", "pink", "violet", "teal"]

    static func color(named name: String?) -> Color {
        switch name {
        case "orange": Color(hex: 0xE8742A)
        case "blue": Color(hex: 0x2F5BEA)
        case "green": Color(hex: 0x12936A)
        case "pink": Color(hex: 0xD63E78)
        case "violet": Color(hex: 0x7A4FD6)
        case "teal": Color(hex: 0x0E8C8C)
        default: Color(hex: 0xE8742A)
        }
    }

    /// Color for a project, falling back to a stable index-based color for
    /// projects created before colors existed.
    static func color(for project: FlowProject, index: Int) -> Color {
        if let name = project.colorName {
            return color(named: name)
        }
        return color(named: names[index % names.count])
    }
}

// MARK: - Formatting helpers

enum FTFormat {
    static func money(_ amount: Double, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    static func moneyShort(_ amount: Double) -> String {
        if amount >= 10_000 { return "$\(Int((amount / 1000).rounded()))k" }
        if amount >= 1000 { return "$" + String(format: "%.1f", amount / 1000) + "k" }
        return "$\(Int(amount.rounded()))"
    }

    static func timeOfDay(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

// MARK: - Week bars data

struct WeekBarsData {
    let values: [TimeInterval]   // index 0 = 6 days ago ... 6 = today
    let labels: [String]

    var total: TimeInterval { values.reduce(0, +) }
    var max: TimeInterval { values.max() ?? 0 }

    init(sessions: [FlowSession], liveToday: TimeInterval = 0) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var vals = [TimeInterval](repeating: 0, count: 7)
        var labs = [String](repeating: "", count: 7)

        for session in sessions {
            let day = cal.startOfDay(for: session.startedAt)
            if let diff = cal.dateComponents([.day], from: day, to: today).day,
               diff >= 0, diff < 7 {
                vals[6 - diff] += session.duration
            }
        }
        vals[6] += liveToday

        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i - 6, to: today) ?? today
            labs[i] = day.formatted(.dateTime.weekday(.abbreviated))
        }
        self.values = vals
        self.labels = labs
    }
}
