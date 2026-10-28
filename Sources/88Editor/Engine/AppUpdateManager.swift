import SwiftUI
import AppKit

/// Gestor nativo y ligero de actualizaciones para 88 Editor basado en GitHub Releases.
/// Consulta la API pública de GitHub de forma asíncrona sin bloquear la interfaz.
public final class AppUpdateManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = AppUpdateManager()

    public static let repoOwner = "srcarlosdamian"
    public static let repoName = "88Editor"
    public static let releasesApiUrl = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
    public static let fallbackReleasesWebUrl = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")!

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    // Estado observable para la UI
    @Published public var isChecking: Bool = false
    @Published public var isUpdateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var releaseHtmlUrl: URL? = nil
    @Published public var downloadAssetUrl: URL? = nil
    @Published public var downloadAssetSize: Int64 = 0

    // Control de UI no intrusiva
    @Published public var isBannerVisible: Bool = false
    @Published public var isUpdateSheetPresented: Bool = false

    // Estado de descarga e instalación
    @Published public var isDownloading: Bool = false
    @Published public var isInstalling: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var downloadStatusMessage: String = ""
    @Published public var updateError: String? = nil

    private var downloadTask: URLSessionDownloadTask?
    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    // MARK: - Comprobación de Actualizaciones
    /// Comprueba si hay una nueva versión disponible en GitHub Releases.
    /// Si `manual` es true, muestra mensajes en pantalla aunque no haya actualización.
    public func checkForUpdates(manual: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        updateError = nil

        var request = URLRequest(url: Self.releasesApiUrl)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("88Editor-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isChecking = false
            }

            if let error = error {
                if manual {
                    DispatchQueue.main.async {
                        self.updateError = "No se pudo conectar con GitHub: \(error.localizedDescription)"
                        self.isUpdateSheetPresented = true
                    }
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else { return }

            if httpResponse.statusCode == 404 {
                if manual {
                    DispatchQueue.main.async {
                        self.latestVersion = self.currentVersion
                        self.isUpdateAvailable = false
                        self.updateError = "No hay versiones públicas registradas en GitHub Releases todavía."
                        self.isUpdateSheetPresented = true
                    }
                }
                return
            }

            guard httpResponse.statusCode == 200, let data = data else {
                if manual {
                    DispatchQueue.main.async {
                        self.updateError = "Respuesta inesperada de GitHub (Código \(httpResponse.statusCode))."
                        self.isUpdateSheetPresented = true
                    }
                }
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
                let remoteTag = release.tagName
                let hasNewVersion = Self.isVersion(remoteTag, newerThan: self.currentVersion)

                DispatchQueue.main.async {
                    self.latestVersion = remoteTag
                    self.releaseTitle = release.name ?? "Versión \(remoteTag)"
                    self.releaseNotes = release.body ?? "Sin notas de versión disponibles."
                    self.releaseHtmlUrl = URL(string: release.htmlUrl ?? "") ?? Self.fallbackReleasesWebUrl

                    // Buscar el asset .zip o .dmg adecuado
                    var selectedAsset: GitHubAssetResponse? = nil
                    if let zipAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) {
                        selectedAsset = zipAsset
                    } else if let dmgAsset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }) {
                        selectedAsset = dmgAsset
                    } else {
                        selectedAsset = release.assets.first
                    }

                    if let asset = selectedAsset, let url = URL(string: asset.browserDownloadUrl) {
                        self.downloadAssetUrl = url
                        self.downloadAssetSize = asset.size ?? 0
                    } else {
                        self.downloadAssetUrl = nil
                    }

                    if hasNewVersion {
                        self.isUpdateAvailable = true
                        self.isBannerVisible = true
                        if manual {
                            self.isUpdateSheetPresented = true
                        }
                    } else {
                        self.isUpdateAvailable = false
                        if manual {
                            self.isUpdateSheetPresented = true
                        }
                    }
                }
            } catch {
                if manual {
                    DispatchQueue.main.async {
                        self.updateError = "Error al procesar la información de GitHub: \(error.localizedDescription)"
                        self.isUpdateSheetPresented = true
                    }
                }
            }
        }.resume()
    }

    // MARK: - Comparador Semántico de Versiones
    /// Devuelve true si `remote` es estrictamente superior a `local` (ej: "v1.1.0" > "1.0.0").
    public static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))

        let rParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let lParts = cleanLocal.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(rParts.count, lParts.count)
        for i in 0..<maxCount {
            let r = i < rParts.count ? rParts[i] : 0
            let l = i < lParts.count ? lParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    // MARK: - Descarga e Instalación Automática
    public func startDownloadAndInstall() {
        guard let url = downloadAssetUrl else {
            // Si no hay asset directo, abrir la página web de releases
            openReleaseInBrowser()
            return
        }

        updateError = nil
        isDownloading = true
        isInstalling = false
        downloadProgress = 0.0
        downloadStatusMessage = "Iniciando descarga..."

        downloadTask?.cancel()
        downloadTask = downloadSession.downloadTask(with: url)
        downloadTask?.resume()
    }

    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        isInstalling = false
        downloadProgress = 0.0
        downloadStatusMessage = ""
    }

    public func openReleaseInBrowser() {
        if let url = releaseHtmlUrl {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(Self.fallbackReleasesWebUrl)
        }
    }

    // MARK: - URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            if totalBytesExpectedToWrite > 0 {
                self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                let mbWritten = Double(totalBytesWritten) / (1024 * 1024)
                let mbTotal = Double(totalBytesExpectedToWrite) / (1024 * 1024)
                self.downloadStatusMessage = String(format: "Descargando: %.1f MB de %.1f MB (%.0f%%)", mbWritten, mbTotal, self.downloadProgress * 100)
            } else {
                let mbWritten = Double(totalBytesWritten) / (1024 * 1024)
                self.downloadStatusMessage = String(format: "Descargando: %.1f MB...", mbWritten)
            }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Mover a una ruta temporal antes de que el sistema la elimine
        let fileManager = FileManager.default
        let ext = downloadAssetUrl?.pathExtension ?? "zip"
        let savedTempFile = fileManager.temporaryDirectory.appendingPathComponent("88Editor_Update_\(UUID().uuidString).\(ext)")

        do {
            if fileManager.fileExists(atPath: savedTempFile.path) {
                try fileManager.removeItem(at: savedTempFile)
            }
            try fileManager.moveItem(at: location, to: savedTempFile)
            installDownloadedPackage(at: savedTempFile)
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.isInstalling = false
                self.updateError = "Error al guardar el archivo temporal: \(error.localizedDescription)"
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                // Si fue cancelada manualmente, no mostrar error
                if (error as NSError).code == NSURLErrorCancelled { return }
                self.isDownloading = false
                self.isInstalling = false
                self.updateError = "Error en la descarga: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Extracción y Sustitución de la App
    private func installDownloadedPackage(at localPackageUrl: URL) {
        DispatchQueue.main.async {
            self.downloadStatusMessage = "Extrayendo e instalando nueva versión..."
            self.isInstalling = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                let extractDir = fileManager.temporaryDirectory.appendingPathComponent("88Editor_Extract_\(UUID().uuidString)")
                try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

                let ext = localPackageUrl.pathExtension.lowercased()
                var newAppPath: String? = nil

                if ext == "zip" {
                    // Descomprimir usando ditto nativo de macOS (preserva firmas, permisos y atributos)
                    let ditto = Process()
                    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    ditto.arguments = ["-xk", localPackageUrl.path, extractDir.path]
                    try ditto.run()
                    ditto.waitUntilExit()

                    let items = try fileManager.contentsOfDirectory(atPath: extractDir.path)
                    if let appName = items.first(where: { $0.hasSuffix(".app") }) {
                        newAppPath = extractDir.appendingPathComponent(appName).path
                    }
                } else if ext == "dmg" {
                    // Montar DMG en directorio temporal
                    let mountPoint = fileManager.temporaryDirectory.appendingPathComponent("88Editor_Mount_\(UUID().uuidString)")
                    try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)

                    let hdiutil = Process()
                    hdiutil.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    hdiutil.arguments = ["attach", localPackageUrl.path, "-mountpoint", mountPoint.path, "-nobrowse", "-readonly", "-quiet"]
                    try hdiutil.run()
                    hdiutil.waitUntilExit()

                    let items = try fileManager.contentsOfDirectory(atPath: mountPoint.path)
                    if let appName = items.first(where: { $0.hasSuffix(".app") }) {
                        let extractedApp = extractDir.appendingPathComponent(appName)
                        let cp = Process()
                        cp.executableURL = URL(fileURLWithPath: "/bin/cp")
                        cp.arguments = ["-R", mountPoint.appendingPathComponent(appName).path, extractedApp.path]
                        try cp.run()
                        cp.waitUntilExit()
                        newAppPath = extractedApp.path
                    }

                    // Desmontar DMG
                    let detach = Process()
                    detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    detach.arguments = ["detach", mountPoint.path, "-quiet", "-force"]
                    try? detach.run()
                    detach.waitUntilExit()
                    try? fileManager.removeItem(at: mountPoint)
                }

                guard let finalNewApp = newAppPath, fileManager.fileExists(atPath: finalNewApp) else {
                    throw NSError(domain: "AppUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se encontró el paquete 88Editor.app dentro del archivo descargado."])
                }

                // Destino: ubicación actual de 88Editor.app en ejecución
                let currentAppURL = Bundle.main.bundleURL
                let targetPath = currentAppURL.path

                // Crear script bash para sustituir el ejecutable sin bloqueo de proceso
                let scriptPath = fileManager.temporaryDirectory.appendingPathComponent("88update_\(UUID().uuidString).sh").path
                let pid = ProcessInfo.processInfo.processIdentifier

                let scriptContent = """
                #!/bin/bash
                # Esperar a que el proceso anterior finalice
                while kill -0 \(pid) 2>/dev/null; do
                    sleep 0.2
                done

                # Sustituir aplicación anterior por la nueva
                rm -rf "\(targetPath)"
                cp -R "\(finalNewApp)" "\(targetPath)"

                # Eliminar cuarentena de macOS para arranque inmediato
                xattr -rd com.apple.quarantine "\(targetPath)" 2>/dev/null || true

                # Abrir la nueva versión
                open "\(targetPath)"

                # Limpieza de archivos temporales
                rm -rf "\(extractDir.path)"
                rm -f "\(localPackageUrl.path)"
                rm -f "$0"
                """

                try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

                DispatchQueue.main.async {
                    self.downloadStatusMessage = "¡Listo! Reiniciando 88 Editor..."
                    let runner = Process()
                    runner.executableURL = URL(fileURLWithPath: "/bin/bash")
                    runner.arguments = [scriptPath]
                    try? runner.run()

                    // Salir de la app para permitir la sustitución
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.terminate(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.isInstalling = false
                    self.updateError = "Error durante la instalación: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Modelos de Decodificación de GitHub API
private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String?
    let assets: [GitHubAssetResponse]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

private struct GitHubAssetResponse: Decodable {
    let name: String
    let browserDownloadUrl: String
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}
