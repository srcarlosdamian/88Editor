import Foundation
import SwiftUI

/// Preset de relación de aspecto y resolución para el proyecto
public enum ResolutionPreset: String, CaseIterable, Identifiable, Codable {
    case fullHD16x9 = "16:9 Horizontal (1080p)"
    case uhd4K16x9 = "16:9 4K UHD"
    case vertical9x16 = "9:16 Vertical (Reels / TikTok)"
    case square1x1 = "1:1 Cuadrado (Social)"
    case custom = "Personalizado"

    public var id: String { rawValue }

    public var defaultDimensions: CGSize {
        switch self {
        case .fullHD16x9:
            return CGSize(width: 1920, height: 1080)
        case .uhd4K16x9:
            return CGSize(width: 3840, height: 2160)
        case .vertical9x16:
            return CGSize(width: 1080, height: 1920)
        case .square1x1:
            return CGSize(width: 1080, height: 1080)
        case .custom:
            return CGSize(width: 1920, height: 1080)
        }
    }

    public var iconName: String {
        switch self {
        case .fullHD16x9, .uhd4K16x9:
            return "rectangle.ratio.16.to.9"
        case .vertical9x16:
            return "rectangle.ratio.9.to.16"
        case .square1x1:
            return "square"
        case .custom:
            return "slider.horizontal.2.square"
        }
    }
}

/// Tasa de cuadros por segundo admitida en el proyecto
public enum FramerateOption: Int, CaseIterable, Identifiable, Codable {
    case fps24 = 24
    case fps25 = 25
    case fps30 = 30
    case fps50 = 50
    case fps60 = 60

    public var id: Int { rawValue }

    public var shortName: String {
        return "\(rawValue) fps"
    }

    public var displayName: String {
        switch self {
        case .fps24: return "24 fps (Cinematográfico)"
        case .fps25: return "25 fps (PAL / Europa)"
        case .fps30: return "30 fps (Estándar Web)"
        case .fps50: return "50 fps (PAL Alta Fluidez)"
        case .fps60: return "60 fps (Máxima Fluidez)"
        }
    }
}

/// Color base de lienzo/fondo serializable
public struct CanvasColor: Codable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = CanvasColor(red: 0.0, green: 0.0, blue: 0.0)
    public static let darkGray = CanvasColor(red: 0.12, green: 0.12, blue: 0.12)
    public static let pureWhite = CanvasColor(red: 1.0, green: 1.0, blue: 1.0)

    public var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    public var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

/// Configuración base del proyecto 88 Editor
public struct ProjectConfiguration: Codable, Equatable {
    public var preset: ResolutionPreset
    public var width: Double
    public var height: Double
    public var framerate: FramerateOption
    public var backgroundColor: CanvasColor
    public var defaultDuration: Double

    public init(
        preset: ResolutionPreset = .fullHD16x9,
        customWidth: Double? = nil,
        customHeight: Double? = nil,
        framerate: FramerateOption = .fps30,
        backgroundColor: CanvasColor = .black,
        defaultDuration: Double = 60.0
    ) {
        self.preset = preset
        let dims = preset.defaultDimensions
        self.width = customWidth ?? Double(dims.width)
        self.height = customHeight ?? Double(dims.height)
        self.framerate = framerate
        self.backgroundColor = backgroundColor
        self.defaultDuration = max(5.0, defaultDuration)
    }

    enum CodingKeys: String, CodingKey {
        case preset, width, height, framerate, backgroundColor, defaultDuration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.preset = try container.decodeIfPresent(ResolutionPreset.self, forKey: .preset) ?? .fullHD16x9
        self.width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 1920.0
        self.height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 1080.0
        self.framerate = try container.decodeIfPresent(FramerateOption.self, forKey: .framerate) ?? .fps30
        self.backgroundColor = try container.decodeIfPresent(CanvasColor.self, forKey: .backgroundColor) ?? .black
        self.defaultDuration = try container.decodeIfPresent(Double.self, forKey: .defaultDuration) ?? 60.0
    }

    public var aspectRatio: Double {
        guard height > 0 else { return 16.0 / 9.0 }
        return width / height
    }

    public var resolutionDisplayString: String {
        "\(Int(width)) × \(Int(height))"
    }
}
