import SwiftUI
import AppKit

/// Constantes y estilos de diseño neutros para 88 Editor (Modo Oscuro Profesional macOS HIG)
public enum DesignSystem {
    // Modo Oscuro Profesional
    public static let background = Color(red: 0.11, green: 0.11, blue: 0.12)          // #1C1C1E
    public static let panelBackground = Color(red: 0.15, green: 0.15, blue: 0.16)     // #262629
    public static let sidebarBackground = Color(red: 0.13, green: 0.13, blue: 0.14)   // #212124
    public static let workspaceBackground = Color(red: 0.08, green: 0.08, blue: 0.09) // #141416
    public static let secondaryBackground = Color.white.opacity(0.06)
    public static let border = Color.white.opacity(0.10)
    public static let subtleBorder = Color.white.opacity(0.06)

    // Acentos sobrios de video
    public static let accent = Color.white.opacity(0.85)
    public static let playhead = Color(red: 1.0, green: 0.28, blue: 0.25)
    public static let videoClip = Color(red: 0.20, green: 0.44, blue: 0.70)
    public static let audioClip = Color(red: 0.18, green: 0.58, blue: 0.44)
    public static let imageClip = Color(red: 0.65, green: 0.44, blue: 0.22)
    public static let textClip = Color(red: 0.55, green: 0.35, blue: 0.75) // Púrpura elegante para texto
    public static let shapeClip = Color(red: 0.88, green: 0.24, blue: 0.24) // Rojo vibrante para formas vectoriales
    public static let clipBorder = Color.white.opacity(0.22)
    public static let selectedClipBorder = Color(red: 1.0, green: 0.82, blue: 0.20)

    // Tipografía
    public static let monoFont = Font.system(.caption, design: .monospaced)
    public static let timecodeFont = Font.system(size: 13, weight: .semibold, design: .monospaced)
    public static let sectionTitle = Font.system(size: 11, weight: .bold)
}

/// Modificador de tarjeta minimalista nativa macOS en modo oscuro
public struct MinimalCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 8

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignSystem.border, lineWidth: 1)
            )
    }
}

public extension View {
    func minimalCard(cornerRadius: CGFloat = 8) -> some View {
        self.modifier(MinimalCardModifier(cornerRadius: cornerRadius))
    }
}

public extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 59, 48) // Rojo #FF3B30 por defecto
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return "#FF3B30" }
        let r = Int(rgbColor.redComponent * 255.0)
        let g = Int(rgbColor.greenComponent * 255.0)
        let b = Int(rgbColor.blueComponent * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
