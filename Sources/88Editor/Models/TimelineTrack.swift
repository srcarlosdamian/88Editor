import Foundation

/// Tipo de pista en la línea de tiempo
public enum TrackKind: String, Codable, CaseIterable {
    case video
    case audio

    public var displayName: String {
        switch self {
        case .video: return "Pista de Video"
        case .audio: return "Pista de Audio"
        }
    }

    public var iconName: String {
        switch self {
        case .video: return "video.fill"
        case .audio: return "waveform"
        }
    }
}

/// Pista individual de la línea de tiempo multicapa no magnética.
public struct TimelineTrack: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var kind: TrackKind
    public var isMuted: Bool
    public var isLocked: Bool
    public var isHidden: Bool
    public var clips: [TimelineClip]

    public init(
        id: UUID = UUID(),
        name: String,
        kind: TrackKind,
        isMuted: Bool = false,
        isLocked: Bool = false,
        isHidden: Bool = false,
        clips: [TimelineClip] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isMuted = isMuted
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.clips = clips
    }

    // MARK: - Decodificación Resistente con Retrocompatibilidad Absoluta
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Capa"
        self.kind = try container.decodeIfPresent(TrackKind.self, forKey: .kind) ?? .video
        self.isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        self.isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        self.clips = try container.decodeIfPresent([TimelineClip].self, forKey: .clips) ?? []
    }

    /// Duración total máxima de la pista
    public var maxDuration: Double {
        clips.map { $0.endTime }.max() ?? 0.0
    }
}
