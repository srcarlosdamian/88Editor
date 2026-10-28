import Foundation

/// Representa una instantánea en el historial de acciones (estilo Adobe Photoshop / Premiere Pro).
/// Permite deshacer, rehacer y navegar a cualquier punto temporal del proyecto con un solo clic.
/// Es completamente serializable (Codable) y ligera para guardarse junto al documento .88proj.
public struct HistoryState: Identifiable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let icon: String
    public let timestamp: Date
    public let tracks: [TimelineTrack]
    public let configuration: ProjectConfiguration
    public let selectedClipId: UUID?
    public let playheadTime: Double

    public init(
        id: UUID = UUID(),
        title: String,
        icon: String = "clock.arrow.circlepath",
        timestamp: Date = Date(),
        tracks: [TimelineTrack],
        configuration: ProjectConfiguration = ProjectConfiguration(),
        selectedClipId: UUID? = nil,
        playheadTime: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.timestamp = timestamp
        self.tracks = tracks
        self.configuration = configuration
        self.selectedClipId = selectedClipId
        self.playheadTime = playheadTime
    }

    /// Inicializador de conveniencia a partir de un ProjectDocument
    public init(
        id: UUID = UUID(),
        title: String,
        icon: String = "clock.arrow.circlepath",
        timestamp: Date = Date(),
        document: ProjectDocument,
        selectedClipId: UUID? = nil,
        playheadTime: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.timestamp = timestamp
        self.tracks = document.tracks
        self.configuration = document.configuration
        self.selectedClipId = selectedClipId
        self.playheadTime = playheadTime
    }

    public var snapshot: ProjectDocument {
        ProjectDocument(
            configuration: configuration,
            tracks: tracks
        )
    }

    public static func == (lhs: HistoryState, rhs: HistoryState) -> Bool {
        lhs.id == rhs.id
    }
}
