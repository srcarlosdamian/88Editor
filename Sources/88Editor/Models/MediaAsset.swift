import Foundation
import CoreGraphics
import AVFoundation

/// Tipo de contenido multimedia importado o generado vectorialmente
public enum MediaType: String, Codable, CaseIterable {
    case video
    case audio
    case image
    case text
    case shape

    public var systemIcon: String {
        switch self {
        case .video: return "film"
        case .audio: return "waveform"
        case .image: return "photo"
        case .text: return "character.textbox"
        case .shape: return "circle.fill"
        }
    }

    public var displayName: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Audio"
        case .image: return "Imagen"
        case .text: return "Texto Vectorial"
        case .shape: return "Forma Vectorial"
        }
    }
}

/// Representa un archivo multimedia vinculado por referencia en 88 Editor.
/// No duplica los archivos del usuario; almacena la URL local y el Security-Scoped Bookmark.
public struct MediaAsset: Identifiable, Codable, Equatable {
    public let id: UUID
    public var fileName: String
    public var fileURL: URL
    public var bookmarkData: Data?
    public var mediaType: MediaType
    public var duration: Double // en segundos (para imágenes por defecto 5.0s)
    public var width: Double
    public var height: Double
    public var fileSize: Int64
    public var dateAdded: Date

    public init(
        id: UUID = UUID(),
        fileName: String,
        fileURL: URL,
        bookmarkData: Data? = nil,
        mediaType: MediaType,
        duration: Double,
        width: Double = 0,
        height: Double = 0,
        fileSize: Int64 = 0,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.bookmarkData = bookmarkData
        self.mediaType = mediaType
        self.duration = duration
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.dateAdded = dateAdded
    }

    public var isDiskFile: Bool {
        return mediaType == .video || mediaType == .audio || mediaType == .image
    }

    public var isMissing: Bool {
        guard isDiskFile else { return false }
        return !FileManager.default.fileExists(atPath: fileURL.path)
    }

    public var resolutionString: String {
        guard width > 0 && height > 0 else { return "—" }
        return "\(Int(width))×\(Int(height))"
    }

    public var formattedDuration: String {
        if mediaType == .image {
            return "Foto (Estático)"
        }
        let tc = Timecode(seconds: duration, framerate: 30)
        return tc.shortStringValue
    }

    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
