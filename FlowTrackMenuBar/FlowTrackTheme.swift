import AppKit
import SwiftUI

// MARK: - Design tokens (from the FlowTrack design handoff)

extension Color {
    /// Blend toward black, like CSS `color-mix(in srgb, c X%, #000)`.
    func darkened(by fraction: CGFloat) -> Color {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return Color(nsColor: ns.blended(withFraction: fraction, of: .black) ?? ns)
    }

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

enum FT {
    // surfaces
    static let win = Color(hex: 0x1A1B1F)        // window base
    static let bg0 = Color(hex: 0x1D1E23)        // main detail surface
    static let side = Color(hex: 0x141519)       // sidebar
    static let bg1 = Color(hex: 0x212329)        // cards
    static let bg2 = Color(hex: 0x272A31)        // raised / inputs
    static let bgHover = Color(hex: 0x2C2F37)
    static let line = Color.white.opacity(0.07)
    static let line2 = Color.white.opacity(0.11)

    // text
    static let text = Color(hex: 0xF4F5F7)
    static let text2 = Color(hex: 0xA6ABB6)
    static let text3 = Color(hex: 0x6E7480)
    static let text4 = Color(hex: 0x52575F)

    // accent (green) + money (gold) + danger
    static let accent = Color(hex: 0x34D17F)
    static let accentFg = Color(hex: 0x08130C)
    static let accentGlow = Color(hex: 0x34D17F, alpha: 0.30)
    static let accentSoft = Color(hex: 0x34D17F, alpha: 0.14)
    static let earn = Color(hex: 0xE7B765)
    static let earnSoft = Color(hex: 0xE7B765, alpha: 0.13)
    static let amber = Color(hex: 0xE7B765)
    static let amberFg = Color(hex: 0x1D1605)
    static let danger = Color(hex: 0xFF6B6B)
}

// MARK: - Folder colors

enum FolderPalette {
    static let names = ["orange", "blue", "green", "pink", "violet", "teal"]

    static func color(named name: String?) -> Color {
        switch name {
        case "orange": Color(hex: 0xF08A3C)
        case "blue": Color(hex: 0x5B8CFF)
        case "green": Color(hex: 0x46C46E)
        case "pink": Color(hex: 0xE85C9A)
        case "violet": Color(hex: 0xA684FF)
        case "teal": Color(hex: 0x2DC8C0)
        default: Color(hex: 0xF08A3C)
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

// MARK: - Gradient folder tile

struct FolderTile: View {
    let color: Color
    var size: CGFloat = 30
    var radius: CGFloat = 8
    var icon: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color, color.darkened(by: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    .blendMode(.plusLighter)
            )
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.4), radius: 5, y: 3)
            .overlay(
                Image(systemName: "folder.fill")
                    .font(.system(size: icon, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.96))
            )
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
