import SwiftUI
import AppKit
struct Palette {
    let dark: Bool
    let olive: Bool
    init(_ theme: String, systemDark: Bool) { dark = theme == "dark" || (theme == "system" && systemDark); olive = theme == "olive" }
    func color(_ dark: String, _ light: String, _ olive: String) -> Color { Color(hex: self.olive ? olive : (self.dark ? dark : light)) }
    var canvas: Color { color("101820", "F3F5F8", "EAE5D6") }
    var sidebar: Color { color("141F29", "E9EEF3", "DDD8C5") }
    var surface: Color { color("19232D", "FFFFFF", "F7F3E8") }
    var border: Color { color("30414F", "DAE2E9", "CEC7B2") }
    var accent: Color { color("66D5CD", "087F8C", "4C602E") }
    var onBrand: Color { color("102A2D", "FFFFFF", "FFF9EB") }
    var preview: Color { color("8AE5DC", "066775", "4C602E") }
    var warning: Color { color("F0C273", "925B0A", "97502E") }
    var text: Color { olive ? Color(hex: "30372B") : (dark ? .white : .black.opacity(228/255)) }
    var secondary: Color { olive ? Color(hex: "636750") : (dark ? .white.opacity(197/255) : .black.opacity(158/255)) }
    var control: Color { olive ? Color(hex: "EFEADA") : .white.opacity(dark ? 15/255 : 179/255) }
    var dialog: Color { color("202020", "F3F3F3", "F7F3E8") }
}
extension Color {
    init(hex: String) { let n = UInt32(hex, radix: 16) ?? 0; self.init(.sRGB, red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255, opacity: 1) }
}
struct PrimaryButtonStyle: ButtonStyle {
    let palette: Palette
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 8).padding(.vertical, 6)
            .foregroundStyle(enabled ? palette.onBrand : palette.secondary)
            .background(enabled ? palette.accent.opacity(configuration.isPressed ? 0.8 : 1) : palette.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
    }
}
