import Foundation
import Combine

/// Elemento representativo de un proyecto guardado recientemente (.88proj)
public struct RecentProjectItem: Identifiable, Codable, Equatable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let modifiedAt: Date

    public init(url: URL, name: String, modifiedAt: Date = Date()) {
        self.url = url
        self.name = name
        self.modifiedAt = modifiedAt
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: modifiedAt, relativeTo: Date())
    }

    public var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix(home) {
            return "~" + url.path.dropFirst(home.count)
        }
        return url.path
    }
}

/// Administrador centralizado de proyectos recientes (.88proj)
/// Persiste la lista en UserDefaults y la sincroniza con el menú del sistema y el modal de bienvenida.
@MainActor
public final class RecentProjectsManager: ObservableObject {
    public static let shared = RecentProjectsManager()

    private let userDefaultsKey = "88Editor.recentProjectsList"
    private let maxRecents: Int = 10

    @Published public private(set) var recentProjects: [RecentProjectItem] = []

    public init() {
        loadRecents()
    }

    public func loadRecents() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([RecentProjectItem].self, from: data) {
            // Filtrar archivos que todavía existan físicamente en el disco
            self.recentProjects = decoded.filter { $0.exists }
        }
    }

    public func add(url: URL, name: String) {
        // Remover coincidencia previa para reubicar al inicio
        var updated = recentProjects.filter { $0.url.path != url.path }
        let cleanName = name.isEmpty ? url.deletingPathExtension().lastPathComponent : name
        let newItem = RecentProjectItem(url: url, name: cleanName, modifiedAt: Date())
        updated.insert(newItem, at: 0)

        if updated.count > maxRecents {
            updated = Array(updated.prefix(maxRecents))
        }

        self.recentProjects = updated
        saveRecents()
    }

    public func remove(url: URL) {
        self.recentProjects.removeAll { $0.url.path == url.path }
        saveRecents()
    }

    public func clear() {
        self.recentProjects.removeAll()
        saveRecents()
    }

    private func saveRecents() {
        if let encoded = try? JSONEncoder().encode(recentProjects) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}
