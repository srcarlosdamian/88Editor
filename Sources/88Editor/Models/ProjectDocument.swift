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
    public var savedHistory: [HistoryState]?
    public var savedHistoryIndex: Int?

    // Herramienta de Área de Trabajo y Rango de Renderizado (In / Out)
    public var workAreaIn: Double?
    public var workAreaOut: Double?

    public init(
        id: UUID = UUID(),
        version: String = "1.0",
        projectName: String = "Proyecto sin título",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        configuration: ProjectConfiguration = ProjectConfiguration(),
        assets: [MediaAsset] = [],
        tracks: [TimelineTrack] = [],
        savedHistory: [HistoryState]? = nil,
        savedHistoryIndex: Int? = nil,
        workAreaIn: Double? = nil,
        workAreaOut: Double? = nil
    ) {
        self.id = id
        self.version = version
        self.projectName = projectName
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.configuration = configuration
        self.assets = assets
        self.tracks = tracks
        self.savedHistory = savedHistory
        self.savedHistoryIndex = savedHistoryIndex
        self.workAreaIn = workAreaIn
        self.workAreaOut = workAreaOut
    }

    // MARK: - Decodificación Resistente con Retrocompatibilidad Absoluta
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? "Proyecto"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
        self.configuration = try container.decodeIfPresent(ProjectConfiguration.self, forKey: .configuration) ?? ProjectConfiguration()
        self.assets = try container.decodeIfPresent([MediaAsset].self, forKey: .assets) ?? []
        self.tracks = try container.decodeIfPresent([TimelineTrack].self, forKey: .tracks) ?? []
        self.savedHistory = try container.decodeIfPresent([HistoryState].self, forKey: .savedHistory)
        self.savedHistoryIndex = try container.decodeIfPresent(Int.self, forKey: .savedHistoryIndex)
        self.workAreaIn = try container.decodeIfPresent(Double.self, forKey: .workAreaIn)
        self.workAreaOut = try container.decodeIfPresent(Double.self, forKey: .workAreaOut)
    }

    /// Duración total del proyecto calculada a partir del clip más lejano
    public var totalDuration: Double {
        let maxTime = tracks.flatMap { $0.clips }.map { $0.endTime }.max() ?? 0.0
        return max(maxTime, 5.0) // Al menos 5 segundos de lienzo visible
    }

    /// Punto de inicio efectivo para el renderizado / área de trabajo (por defecto 0.0s)
    public var effectiveRenderIn: Double {
        return max(0.0, workAreaIn ?? 0.0)
    }

    /// Punto de finalización efectivo para el renderizado / área de trabajo
    public var effectiveRenderOut: Double {
        if let out = workAreaOut, out > effectiveRenderIn {
            return min(out, totalDuration)
        }
        return totalDuration
    }

    /// Duración efectiva del renderizado / corte de área de trabajo
    public var effectiveRenderDuration: Double {
        return max(0.1, effectiveRenderOut - effectiveRenderIn)
    }

    /// Indica si el usuario ha delimitado un rango de renderizado específico
    public var hasCustomWorkArea: Bool {
        return workAreaIn != nil || workAreaOut != nil
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
