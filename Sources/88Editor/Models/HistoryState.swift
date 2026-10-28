import Foundation

/// Representa una instantánea en el historial de acciones (estilo Adobe Photoshop / Premiere Pro).
/// Permite deshacer, rehacer y navegar a cualquier punto temporal del proyecto con un solo clic.
public struct HistoryState: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let icon: String
    public let timestamp: Date
    public let snapshot: ProjectDocument
    public let selectedClipId: UUID?
    public let playheadTime: Double

    public init(
        id: UUID = UUID(),
        title: String,
        icon: String = "clock.arrow.circlepath",
        timestamp: Date = Date(),
        snapshot: ProjectDocument,
        selectedClipId: UUID? = nil,
        playheadTime: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.timestamp = timestamp
        self.snapshot = snapshot
        self.selectedClipId = selectedClipId
        self.playheadTime = playheadTime
    }

    public static func == (lhs: HistoryState, rhs: HistoryState) -> Bool {
        lhs.id == rhs.id
    }
}
