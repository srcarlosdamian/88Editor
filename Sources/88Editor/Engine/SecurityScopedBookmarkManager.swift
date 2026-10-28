import Foundation

/// Administrador de referencias a archivos mediante Security-Scoped Bookmarks en macOS.
/// Garantiza que 88 Editor no copie ni duplique los archivos del usuario,
/// conservando el acceso seguro y persistente entre sesiones.
public final class SecurityScopedBookmarkManager {
    public static let shared = SecurityScopedBookmarkManager()

    private var activeSecurityScopedURLs: Set<URL> = []
    private let lock = NSLock()

    private init() {}

    /// Crea un marcador persistente con ámbito de seguridad para una URL local.
    public func createBookmark(for url: URL) -> Data? {
        // En macOS, aseguramos acceso antes de crear el bookmark si ya es scoped
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmark
        } catch {
            print("[88 Editor] Error al crear Security-Scoped Bookmark para \(url.path): \(error.localizedDescription)")
            // Si el sandbox no lo requiere o falla el flag withSecurityScope, intenta bookmark estándar
            do {
                return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            } catch {
                print("[88 Editor] Fallo al crear bookmark alternativo: \(error.localizedDescription)")
                return nil
            }
        }
    }

    /// Resuelve un marcador y activa el acceso seguro a la ruta de archivo.
    public func resolveBookmark(data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if resolvedURL.startAccessingSecurityScopedResource() {
                lock.lock()
                activeSecurityScopedURLs.insert(resolvedURL)
                lock.unlock()
            }
            return (resolvedURL, isStale)
        } catch {
            // Intentar resolución sin ámbito de seguridad
            do {
                let standardURL = try URL(
                    resolvingBookmarkData: data,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                return (standardURL, isStale)
            } catch {
                print("[88 Editor] Error al resolver bookmark: \(error.localizedDescription)")
                return nil
            }
        }
    }

    /// Libera los recursos con ámbito de seguridad activos
    public func stopAccessing(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        if activeSecurityScopedURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopedURLs.remove(url)
        }
    }

    public func stopAccessingAll() {
        lock.lock()
        defer { lock.unlock() }
        for url in activeSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityScopedURLs.removeAll()
    }

    deinit {
        stopAccessingAll()
    }
}
