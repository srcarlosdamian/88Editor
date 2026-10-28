import Foundation
import AVFoundation

/// Tipo de contenido a exportar
public enum ExportMediaType: String, CaseIterable, Identifiable {
    case videoAndAudio = "Video y Audio"
    case audioOnly = "Solo Audio"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .videoAndAudio: return "film"
        case .audioOnly: return "waveform"
        }
    }
}

/// Contenedores y formatos de archivo
public enum ExportContainer: String, CaseIterable, Identifiable {
    case mp4 = "MP4 (.mp4)"
    case mov = "QuickTime (.mov)"
    case m4a = "Audio AAC (.m4a)"
    case wav = "Audio PCM (.wav)"

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .m4a: return "m4a"
        case .wav: return "wav"
        }
    }

    public var avFileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        case .m4a: return .m4a
        case .wav: return .wav
        }
    }
}

/// Niveles de Calidad de Exportación
public enum ExportQuality: String, CaseIterable, Identifiable {
    case high = "Alta (Recomendada)"
    case balanced = "Media (Balanceada)"
    case maximum = "Máxima (Master ProRes)"
    case webFast = "Optimizada para Redes / Web"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .high:
            return "Bitrate óptimo con compresión eficiente H.264 / HEVC. Ideal para la mayoría de usos."
        case .balanced:
            return "Menor peso de archivo (~50%) con excelente nitidez para streaming o envíos."
        case .maximum:
            return "Calidad de estudio Apple ProRes 422 para archivo maestro y postproducción profesional."
        case .webFast:
            return "Compresión agresiva para archivos ultra ligeros listos para subir a la web o chats."
        }
    }

    public var avExportPreset: String {
        switch self {
        case .high:
            return AVAssetExportPresetHighestQuality
        case .balanced:
            return AVAssetExportPresetMediumQuality
        case .maximum:
            return AVAssetExportPresetAppleProRes422LPCM
        case .webFast:
            return AVAssetExportPreset1920x1080
        }
    }
}

/// Presets inteligentes y optimizados para Redes Sociales
public enum SocialPreset: String, CaseIterable, Identifiable {
    case custom = "Personalizado"
    case youtube = "YouTube (16:9 / 4K / 1080p)"
    case tiktokReels = "TikTok / Reels / Shorts (9:16)"
    case instagram = "Instagram Feed (1:1 / 4:5)"
    case twitterX = "X / Twitter (Optimizado)"
    case messaging = "WhatsApp / Mensajería rápida"
    case proresMaster = "Apple ProRes 422 (Master)"
    case podcastAudio = "Podcast / Audio M4A (320 kbps)"
    case wavMaster = "Audio WAV Sin Compresión"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .custom: return "slider.horizontal.3"
        case .youtube: return "play.rectangle.fill"
        case .tiktokReels: return "iphone"
        case .instagram: return "camera.fill"
        case .twitterX: return "bubble.left.and.bubble.right.fill"
        case .messaging: return "message.fill"
        case .proresMaster: return "crown.fill"
        case .podcastAudio: return "headphones"
        case .wavMaster: return "waveform.badge.magnifyingglass"
        }
    }

    public var recommendationNote: String {
        switch self {
        case .custom:
            return "Ajusta manualmente el contenedor, la calidad y el rango de renderizado."
        case .youtube:
            return "Formato MP4 (H.264 / HEVC) con tasa de bits alta y audio AAC estéreo a 320 kbps. Máxima fidelidad y compatibilidad con el algoritmo de procesamiento de YouTube sin pérdida perceptible."
        case .tiktokReels:
            return "MP4 con H.264 (Perfil High) a ~14 Mbps. Evita la re-compresión destructiva que aplican Instagram y TikTok cuando los videos superan los 20 Mbps."
        case .instagram:
            return "MP4 con H.264 a 30/60 fps y tasa moderada de 12 Mbps para feeds de fotos y videos verticales o cuadrados."
        case .twitterX:
            return "MP4 con compresión optimizada (< 10 Mbps) para reproducción fluida instantánea en conexiones móviles celulares."
        case .messaging:
            return "MP4 súper ligero (< 5 Mbps) diseñado para compartirse al instante en WhatsApp, Telegram y Mail sin exceder límites de peso."
        case .proresMaster:
            return "Contenedor QuickTime (.mov) con códec Apple ProRes 422 y audio LPCM de 24 bits. El estándar de la industria audiovisual para archivo definitivo."
        case .podcastAudio:
            return "Contenedor M4A con audio AAC de alta definición a 320 kbps. Ideal para podcasts, discursos o bandas sonoras."
        case .wavMaster:
            return "Audio PCM sin comprimir a 48 kHz y 16/24 bits en formato WAV."
        }
    }

    public var defaultMediaType: ExportMediaType {
        switch self {
        case .podcastAudio, .wavMaster:
            return .audioOnly
        default:
            return .videoAndAudio
        }
    }

    public var defaultContainer: ExportContainer {
        switch self {
        case .proresMaster:
            return .mov
        case .podcastAudio:
            return .m4a
        case .wavMaster:
            return .wav
        default:
            return .mp4
        }
    }

    public var defaultQuality: ExportQuality {
        switch self {
        case .proresMaster:
            return .maximum
        case .messaging:
            return .webFast
        case .twitterX, .instagram:
            return .balanced
        default:
            return .high
        }
    }

    /// Tasa de bits estimada en Megabits por segundo (Mbps) para cálculo de peso
    public var estimatedBitrateMbps: Double {
        switch self {
        case .proresMaster: return 147.0 // ProRes 422 a 1080p
        case .youtube: return 20.0
        case .tiktokReels: return 14.0
        case .instagram: return 12.0
        case .twitterX: return 8.0
        case .messaging: return 3.5
        case .podcastAudio: return 0.32 // 320 kbps
        case .wavMaster: return 1.536   // 48kHz 16bit estéreo
        case .custom: return 16.0
        }
    }
}

/// Calculadora y formateador de peso estimado de archivo
public struct FileSizeEstimator {
    /// Calcula el peso estimado en bytes: (Mbps * 1_000_000 / 8) * durationSeconds
    public static func estimateSizeBytes(durationSeconds: Double, bitrateMbps: Double) -> Int64 {
        let bytesPerSecond = (bitrateMbps * 1_000_000.0) / 8.0
        return Int64(max(0, bytesPerSecond * durationSeconds))
    }

    /// Formatea bytes a cadena legible: KB, MB o GB
    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }
}
