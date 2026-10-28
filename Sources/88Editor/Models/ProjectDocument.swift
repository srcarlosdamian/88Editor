import Foundation

/// Documento principal del proyecto 88 Editor (.88proj)
public struct ProjectDocument: Identifiable, Codable, Equatable {
    public let id: UUID
    public var version: String
    public var projectName: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var configuration: ProjectConfiguration
    public var assets: [MediaAsset]
    public var tracks: [TimelineTrack]

    public init(
        id: UUID = UUID(),
        version: String = "1.0",
        projectName: String = "Proyecto sin título",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        configuration: ProjectConfiguration = ProjectConfiguration(),
        assets: [MediaAsset] = [],
        tracks: [TimelineTrack] = []
    ) {
        self.id = id
        self.version = version
        self.projectName = projectName
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.configuration = configuration
        self.assets = assets
        self.tracks = tracks
    }

    /// Duración total del proyecto calculada a partir del clip más lejano
    public var totalDuration: Double {
        let maxTime = tracks.flatMap { $0.clips }.map { $0.endTime }.max() ?? 0.0
        return max(maxTime, 5.0) // Al menos 5 segundos de lienzo visible
    }

    /// Codifica el proyecto a Data en formato JSON formateado
    public func serialize() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Decodifica un proyecto desde Data JSON
    public static func deserialize(from data: Data) throws -> ProjectDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectDocument.self, from: data)
    }
}
