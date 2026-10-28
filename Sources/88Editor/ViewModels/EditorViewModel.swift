import Foundation
import SwiftUI
import Combine
import AVFoundation
import AppKit

/// Pestañas del panel lateral derecho (Inspector Contextual e Historial de Acciones)
public enum RightSidebarTab: String, CaseIterable, Identifiable {
    case inspector = "Inspector"
    case history = "Historial"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .inspector: return "slider.horizontal.3"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

/// ViewModel principal de 88 Editor (Patrón MVVM).
/// Coordina la línea de tiempo, el Media Pool, el Inspector Contextual y el motor de reproducción.
@MainActor
public final class EditorViewModel: ObservableObject {

    // MARK: - Estado del Proyecto
    @Published public var project: ProjectDocument
    @Published public var currentProjectURL: URL?
    @Published public var hasUnsavedChanges: Bool = false

    // MARK: - Motor de Reproducción
    @Published public var playbackEngine = PlaybackEngine()

    // MARK: - Selección e Interacción
    @Published public var selectedClipId: UUID?
    @Published public var selectedTrackId: UUID?
    @Published public var selectedAssetId: UUID?

    // MARK: - UI & Modales
    @Published public var isNewProjectSheetPresented: Bool = false
    @Published public var isFontPickerPresented: Bool = false
    @Published public var isInsertSheetPresented: Bool = false
    @Published public var insertSheetCategory: InsertItemCategory = .text
    @Published public var showUnsavedChangesAlert: Bool = false
    @Published public var pendingActionAfterAlert: (() -> Void)?
    @Published public var unsupportedFormatAlertMessage: String?
    @Published public var showUnsupportedFormatAlert: Bool = false

    // Zoom de la línea de tiempo (píxeles por segundo: 15px a 400px)
    @Published public var timelineZoom: Double = 60.0
    // Zoom vertical (altura de pistas de video y audio: 32px a 110px)
    @Published public var trackHeight: CGFloat = 50.0

    /// Aumenta el zoom horizontal del timeline
    public func zoomInTimeline() {
        timelineZoom = min(timelineZoom * 1.25, 400.0)
    }

    /// Reduce el zoom horizontal del timeline
    public func zoomOutTimeline() {
        timelineZoom = max(timelineZoom / 1.25, 15.0)
    }

    /// Ajusta toda la línea de tiempo a la anchura visible (Shift + Z)
    public func fitTimelineToWindow(availableWidth: CGFloat) {
        let dur = max(project.totalDuration, 1.0)
        let target = Double(availableWidth - 50) / dur
        timelineZoom = min(max(target, 15.0), 300.0)
    }

    // Búsqueda y filtrado en Media Pool
    @Published public var mediaSearchText: String = ""
    @Published public var isMediaGridView: Bool = false

    // Pestaña activa en el panel lateral derecho (Inspector o Historial)
    @Published public var activeRightTab: RightSidebarTab = .inspector

    // Historial de Acciones (Estilo Adobe Photoshop / Premiere Pro)
    @Published public var historyStates: [HistoryState] = []
    @Published public var currentHistoryIndex: Int = 0
    private var isRestoringHistoryState: Bool = false
    private let maxHistoryStates: Int = 60

    // Magnetismo (Snapping) inteligente entre capas y cabezal
    @Published public var isSnappingEnabled: Bool = true
    @Published public var snapGuideLineTime: Double? = nil

    // Fuentes del sistema cargadas mediante NSFontManager
    @Published public var availableSystemFonts: [String] = []

    // Diccionario rápido de assets para la composición
    public var assetsById: [UUID: MediaAsset] {
        Dictionary(uniqueKeysWithValues: project.assets.map { ($0.id, $0) })
    }

    private var cancellables = Set<AnyCancellable>()
    private var compositionBuildTask: Task<Void, Never>?

    public init(initialConfiguration: ProjectConfiguration = ProjectConfiguration()) {
        self.project = ProjectDocument(configuration: initialConfiguration)
        loadSystemFonts()
        setupEngineObservers()
        rebuildComposition()
        recordHistory(title: "Estado inicial", icon: "arrow.counterclockwise")
    }

    // MARK: - Fuentes del Sistema (NSFontManager)
    public func loadSystemFonts() {
        let fontManager = NSFontManager.shared
        let families = fontManager.availableFontFamilies
        self.availableSystemFonts = families.sorted()
    }

    // MARK: - Observadores de Reproducción
    private func setupEngineObservers() {
        playbackEngine.$currentTime
            .dropFirst()
            .sink { [weak self] _ in
                // Mantenemos sincronía con el playhead
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Clip Seleccionado
    public var selectedClip: TimelineClip? {
        get {
            guard let id = selectedClipId else { return nil }
            for track in project.tracks {
                if let clip = track.clips.first(where: { $0.id == id }) {
                    return clip
                }
            }
            return nil
        }
        set {
            guard let updated = newValue else { return }
            for (trackIndex, track) in project.tracks.enumerated() {
                if let clipIndex = track.clips.firstIndex(where: { $0.id == updated.id }) {
                    project.tracks[trackIndex].clips[clipIndex] = updated
                    hasUnsavedChanges = true
                    debouncedRebuildComposition()
                    return
                }
            }
        }
    }

    public var selectedTrack: TimelineTrack? {
        guard let id = selectedTrackId else { return nil }
        return project.tracks.first(where: { $0.id == id })
    }

    public func asset(for clip: TimelineClip) -> MediaAsset? {
        return assetsById[clip.assetId]
    }

    /// Determina si un clip es de naturaleza visual (video, imagen, forma, texto) o si es solo de audio
    public func isClipVisual(_ clip: TimelineClip) -> Bool {
        if clip.shapeType != nil || (clip.textOverlay != nil && !clip.textOverlay!.isEmpty) {
            return true
        }
        if let asset = assetsById[clip.assetId] {
            return asset.mediaType == .video || asset.mediaType == .image || asset.mediaType == .text || asset.mediaType == .shape
        }
        if let track = project.tracks.first(where: { $0.id == clip.trackId }) {
            return track.kind == .video
        }
        return false
    }

    // MARK: - Mutación Segura de Clip Seleccionado
    public func updateSelectedClip(_ mutate: (inout TimelineClip) -> Void) {
        guard let id = selectedClipId else { return }
        for (trackIndex, track) in project.tracks.enumerated() {
            if let clipIndex = track.clips.firstIndex(where: { $0.id == id }) {
                mutate(&project.tracks[trackIndex].clips[clipIndex])
                hasUnsavedChanges = true
                objectWillChange.send()
                debouncedRebuildComposition()
                return
            }
        }
    }

    /// Tiempo relativo del cabezal respecto al inicio del clip seleccionado
    public var currentClipRelativeTime: Double {
        guard let clip = selectedClip else { return 0.0 }
        return max(0, min(playbackEngine.currentTime - clip.startTime, clip.duration))
    }

    /// Actualiza una propiedad animable (Opacidad, Volumen, Escala, Rotación).
    /// Si existen fotogramas clave o hay uno en el cabezal, actualiza/crea el keyframe correspondiente.
    /// Si no hay fotogramas clave, actualiza el valor base del clip.
    public func updateAnimatableProperty(_ property: AnimatableProperty, value: Double) {
        guard let _ = selectedClipId else { return }
        let relTime = currentClipRelativeTime

        updateSelectedClip { clip in
            let hasActiveKeyframe = clip.hasKeyframe(for: property, at: relTime)
            let hasAnyKeyframe = (property == .opacity && !clip.opacityKeyframes.isEmpty) ||
                                 (property == .volume && !clip.volumeKeyframes.isEmpty) ||
                                 (property == .scale && !clip.scaleKeyframes.isEmpty) ||
                                 (property == .rotation && !clip.rotationKeyframes.isEmpty)

            if hasActiveKeyframe || hasAnyKeyframe {
                clip.setKeyframe(for: property, at: relTime, value: value)
            } else {
                switch property {
                case .opacity: clip.opacity = value
                case .volume: clip.volume = value
                case .scale: clip.scale = value
                case .rotation: clip.rotation = value
                }
            }
        }
    }

    // MARK: - Capas Visuales Activas en Visor (Jerarquía: El elemento de arriba manda)
    public struct VisualLayerItem: Identifiable {
        public var id: UUID { clip.id }
        public let trackIndex: Int
        public let track: TimelineTrack
        public let clip: TimelineClip
        public let asset: MediaAsset?
    }

    /// Retorna todas las capas visuales activas ordenadas desde la pista inferior hacia la superior (Track 0).
    /// En el ZStack de SwiftUI, los elementos al final se dibujan encima de los anteriores,
    /// garantizando que la pista situada físicamente arriba en la línea de tiempo se vea por encima de todo.
    public var activeVisualLayersAtPlayhead: [VisualLayerItem] {
        let currentTime = playbackEngine.currentTime
        var layers: [VisualLayerItem] = []

        // Recorrido inverso: de la pista inferior a la pista superior 0
        for (trackIndex, track) in project.tracks.enumerated().reversed() {
            guard track.kind == .video && !track.isHidden else { continue }
            for clip in track.clips {
                if currentTime >= clip.startTime && currentTime <= clip.endTime {
                    let asset = assetsById[clip.assetId]
                    layers.append(VisualLayerItem(trackIndex: trackIndex, track: track, clip: clip, asset: asset))
                }
            }
        }
        return layers
    }

    // MARK: - Clips de Imagen Activos en Visor (Compatibilidad)
    public struct ActiveImageItem: Identifiable {
        public var id: UUID { clip.id }
        public let clip: TimelineClip
        public let asset: MediaAsset
    }

    /// Retorna los clips de imagen activos en la posición actual del playhead ordenados por capa
    public var activeImageClipsAtPlayhead: [ActiveImageItem] {
        let currentTime = playbackEngine.currentTime
        var result: [ActiveImageItem] = []

        for track in project.tracks.reversed() {
            guard track.kind == .video && !track.isHidden else { continue }
            for clip in track.clips {
                if currentTime >= clip.startTime && currentTime <= clip.endTime {
                    if let asset = assetsById[clip.assetId], asset.mediaType == .image {
                        result.append(ActiveImageItem(clip: clip, asset: asset))
                    }
                }
            }
        }
        return result
    }

    // MARK: - Media Pool / Gestión de Medios (Por Referencia)
    public func importFiles(urls: [URL]) {
        for url in urls {
            let fileName = url.lastPathComponent
            let ext = url.pathExtension.lowercased()

            // Detección y bloqueo de formatos incompatibles con AVFoundation (como .mkv)
            let unsupportedFormats = ["mkv", "avi", "wmv", "flv", "webm"]
            if unsupportedFormats.contains(ext) {
                unsupportedFormatAlertMessage = "El archivo '\(fileName)' está en formato .\(ext).\n\nEl motor nativo Apple AVFoundation no admite contenedores .\(ext). Para editarlo en 88 Editor, por favor conviértelo previamente a .mp4 o .mov (H.264 o HEVC)."
                showUnsupportedFormatAlert = true
                continue
            }

            // Evitar duplicar si el archivo ya existe en la biblioteca por URL o ruta
            if let existing = self.project.assets.first(where: {
                $0.fileURL.standardizedFileURL == url.standardizedFileURL ||
                $0.fileURL.path == url.path
            }) {
                self.selectedAssetId = existing.id
                continue
            }

            // No copiamos archivos: generamos Security-Scoped Bookmark
            let bookmark = SecurityScopedBookmarkManager.shared.createBookmark(for: url)

            let resolvedMediaType: MediaType
            if ["mp3", "wav", "m4a", "aac", "aiff"].contains(ext) {
                resolvedMediaType = .audio
            } else if ["png", "jpg", "jpeg", "heic", "tiff", "webp", "psd", "bmp", "gif", "svg"].contains(ext) {
                resolvedMediaType = .image
            } else {
                resolvedMediaType = .video
            }

            // Metadatos iniciales
            let initialDuration: Double = (resolvedMediaType == .image) ? 5.0 : 0.0
            let initialWidth: Double = 0.0
            let initialHeight: Double = 0.0
            var fileSize: Int64 = 0

            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            }

            let asset = MediaAsset(
                fileName: fileName,
                fileURL: url,
                bookmarkData: bookmark,
                mediaType: resolvedMediaType,
                duration: initialDuration,
                width: initialWidth,
                height: initialHeight,
                fileSize: fileSize
            )

            // Añadir al catálogo del proyecto
            self.project.assets.append(asset)
            self.hasUnsavedChanges = true

            // Cargar metadatos asíncronos sin bloquear UI
            let capturedMediaType = resolvedMediaType
            Task {
                await self.loadAssetMetadata(for: asset.id, url: url, mediaType: capturedMediaType)
            }
        }
    }

    private func loadAssetMetadata(for assetId: UUID, url: URL, mediaType: MediaType) async {
        if mediaType == .image {
            if let image = NSImage(contentsOf: url) {
                let w = Double(image.size.width)
                let h = Double(image.size.height)
                await MainActor.run {
                    if let idx = self.project.assets.firstIndex(where: { $0.id == assetId }) {
                        self.project.assets[idx].width = w
                        self.project.assets[idx].height = h
                    }
                }
            }
            return
        }

        let avAsset = AVURLAsset(url: url)
        do {
            let durationCM = try await avAsset.load(.duration)
            let dur = CMTimeGetSeconds(durationCM)
            
            var assetWidth: Double = 0.0
            var assetHeight: Double = 0.0

            if mediaType == .video {
                if let videoTrack = try? await avAsset.loadTracks(withMediaType: .video).first {
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    assetWidth = Double(naturalSize.width)
                    assetHeight = Double(naturalSize.height)
                }
            }

            await MainActor.run {
                if let idx = self.project.assets.firstIndex(where: { $0.id == assetId }) {
                    self.project.assets[idx].duration = dur.isFinite ? dur : 5.0
                    self.project.assets[idx].width = assetWidth
                    self.project.assets[idx].height = assetHeight
                }
            }
        } catch {
            print("[88 Editor] Error cargando metadatos para \(url.lastPathComponent): \(error)")
        }
    }

    public func removeAsset(id: UUID) {
        project.assets.removeAll { $0.id == id }
        // Eliminar también clips asociados de las pistas
        for i in 0..<project.tracks.count {
            project.tracks[i].clips.removeAll { $0.assetId == id }
        }
        // Limpiar capas que hayan quedado vacías para restaurar el estado inicial
        project.tracks.removeAll { $0.clips.isEmpty }
        if project.tracks.isEmpty {
            playbackEngine.pause()
            playbackEngine.seek(to: 0.0)
        }
        if selectedAssetId == id {
            selectedAssetId = nil
        }
        if selectedClipId != nil && selectedClip == nil {
            selectedClipId = nil
        }
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        objectWillChange.send()
    }

    // MARK: - Inserción de Objetos Vectoriales (Texto y Formas Geométricas)
    public func insertVectorText(text: String, fontName: String, fontSize: Double, colorHex: String) {
        let assetId = UUID()
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayText = cleanText.isEmpty ? "Texto" : cleanText
        let assetName = "Texto: \(displayText.prefix(16))"
        let virtualURL = URL(string: "vector://text/\(assetId.uuidString)")!

        let asset = MediaAsset(
            id: assetId,
            fileName: assetName,
            fileURL: virtualURL,
            mediaType: .text,
            duration: 5.0,
            width: Double(project.configuration.width),
            height: Double(project.configuration.height)
        )
        project.assets.append(asset)

        let targetTrack = TimelineTrack(name: assetName, kind: .video)
        project.tracks.insert(targetTrack, at: 0) // Capa superior en la jerarquía (el elemento de arriba manda)

        let clip = TimelineClip(
            assetId: asset.id,
            trackId: targetTrack.id,
            name: assetName,
            startTime: playbackEngine.currentTime,
            duration: 5.0,
            textOverlay: displayText,
            fontName: fontName,
            fontSize: fontSize,
            textColorHex: colorHex
        )

        project.tracks[0].clips.append(clip)
        selectedClipId = clip.id
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        recordHistory(title: "Insertar Texto Vectorial", icon: "character.textbox")
        objectWillChange.send()
    }

    public func insertVectorShape(
        shapeType: String,
        shapeDisplayName: String,
        fillColorHex: String,
        strokeColorHex: String?,
        strokeWidth: Double
    ) {
        let assetId = UUID()
        let assetName = "\(shapeDisplayName) Vectorial"
        let virtualURL = URL(string: "vector://shape/\(assetId.uuidString)")!

        let asset = MediaAsset(
            id: assetId,
            fileName: assetName,
            fileURL: virtualURL,
            mediaType: .shape,
            duration: 5.0,
            width: 240,
            height: 240
        )
        project.assets.append(asset)

        let targetTrack = TimelineTrack(name: assetName, kind: .video)
        project.tracks.insert(targetTrack, at: 0) // Capa superior en la jerarquía

        let clip = TimelineClip(
            assetId: asset.id,
            trackId: targetTrack.id,
            name: assetName,
            startTime: playbackEngine.currentTime,
            duration: 5.0,
            shapeType: shapeType,
            fillColorHex: fillColorHex,
            strokeColorHex: strokeColorHex,
            strokeWidth: strokeWidth
        )

        project.tracks[0].clips.append(clip)
        selectedClipId = clip.id
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        recordHistory(title: "Insertar \(shapeDisplayName)", icon: "circle.fill")
        objectWillChange.send()
    }

    // MARK: - Línea de Tiempo (Cada elemento en su propia pista individual)
    public func addClipToTimeline(assetId: UUID, targetTrackId: UUID? = nil, at timelineTime: Double? = nil) {
        guard let asset = assetsById[assetId] else { return }

        let kind: TrackKind = (asset.mediaType == .audio) ? .audio : .video

        // Cada elemento agregado tiene su propia pista / capa individual dedicada con su nombre propio,
        // a menos que el usuario lo haya arrastrado explícitamente sobre una pista específica existente.
        let suitableTrackId: UUID
        if let target = targetTrackId, project.tracks.contains(where: { $0.id == target }) {
            suitableTrackId = target
        } else {
            let baseName = (asset.fileName as NSString).deletingPathExtension
            let cleanLayerName = baseName.isEmpty ? asset.fileName : baseName
            let newTrack = TimelineTrack(name: cleanLayerName, kind: kind)
            if kind == .video {
                project.tracks.insert(newTrack, at: 0) // Capas de video arriba en la jerarquía
            } else {
                project.tracks.append(newTrack) // Capas de audio abajo
            }
            suitableTrackId = newTrack.id
        }

        let clipDuration = min(asset.duration > 0 ? asset.duration : 5.0, 30.0) // Clip inicial conveniente
        let startTime = max(0, timelineTime ?? playbackEngine.currentTime)

        let newClip = TimelineClip(
            assetId: asset.id,
            trackId: suitableTrackId,
            name: asset.fileName,
            startTime: startTime,
            duration: clipDuration,
            sourceIn: 0.0,
            sourceOut: clipDuration
        )

        for i in 0..<project.tracks.count {
            if project.tracks[i].id == suitableTrackId {
                project.tracks[i].clips.append(newClip)
                break
            }
        }

        selectedClipId = newClip.id
        selectedTrackId = suitableTrackId
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        recordHistory(title: "Añadir capa \(asset.fileName)", icon: "plus.square.fill")
        objectWillChange.send()
    }

    // MARK: - Reconexión / Reemplazo de Medios Eliminados (Offline Media)
    public func reconnectAsset(id: UUID) {
        guard let assetIndex = project.assets.firstIndex(where: { $0.id == id }) else { return }
        let currentAsset = project.assets[assetIndex]

        let panel = NSOpenPanel()
        panel.title = "Reconectar o Reemplazar Archivo Original"
        panel.prompt = "Reconectar"
        panel.message = "Localiza el archivo en el disco para restablecer la conexión multimedia de '\(currentAsset.fileName)'."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        switch currentAsset.mediaType {
        case .video:
            panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        case .audio:
            panel.allowedContentTypes = [.audio, .mp3, .wav]
        case .image:
            panel.allowedContentTypes = [.image, .png, .jpeg]
        default:
            break
        }

        if panel.runModal() == .OK, let selectedURL = panel.url {
            guard FileManager.default.fileExists(atPath: selectedURL.path) else { return }

            let newBookmark = SecurityScopedBookmarkManager.shared.createBookmark(for: selectedURL)
            project.assets[assetIndex].fileURL = selectedURL
            project.assets[assetIndex].fileName = selectedURL.lastPathComponent
            project.assets[assetIndex].bookmarkData = newBookmark

            if let attr = try? FileManager.default.attributesOfItem(atPath: selectedURL.path) {
                project.assets[assetIndex].fileSize = (attr[.size] as? NSNumber)?.int64Value ?? 0
            }

            // Actualizar nombre de los clips asociados si tenían el nombre del archivo anterior
            for tIdx in 0..<project.tracks.count {
                for cIdx in 0..<project.tracks[tIdx].clips.count {
                    if project.tracks[tIdx].clips[cIdx].assetId == id {
                        if project.tracks[tIdx].clips[cIdx].name == currentAsset.fileName {
                            project.tracks[tIdx].clips[cIdx].name = selectedURL.lastPathComponent
                        }
                    }
                }
            }

            hasUnsavedChanges = true
            let capturedType = currentAsset.mediaType
            Task {
                await loadAssetMetadata(for: id, url: selectedURL, mediaType: capturedType)
                await MainActor.run {
                    debouncedRebuildComposition()
                    recordHistory(title: "Reconectar medio \(selectedURL.lastPathComponent)", icon: "arrow.triangle.2.circlepath")
                    objectWillChange.send()
                }
            }
        }
    }

    /// Mueve un clip a un nuevo tiempo y opcionalmente a otra pista con magnetismo sutil
    public func moveClip(clipId: UUID, newStartTime: Double, targetTrackId: UUID? = nil) {
        var clipToMove: TimelineClip?
        var sourceTrackIndex: Int?

        for (tIdx, track) in project.tracks.enumerated() {
            if let cIdx = track.clips.firstIndex(where: { $0.id == clipId }) {
                clipToMove = track.clips[cIdx]
                sourceTrackIndex = tIdx
                project.tracks[tIdx].clips.remove(at: cIdx)
                break
            }
        }

        guard var clip = clipToMove else { return }

        // Aplicar magnetismo inteligente sutil con respecto a todas las capas
        let (snappedStart, _) = snapTime(candidateStartTime: newStartTime, clipDuration: clip.duration, ignoringClipId: clipId)
        clip.startTime = max(0, snappedStart)
        clearSnapGuide()

        let destinationTrackId = targetTrackId ?? clip.trackId
        clip.trackId = destinationTrackId

        if let destIdx = project.tracks.firstIndex(where: { $0.id == destinationTrackId }) {
            project.tracks[destIdx].clips.append(clip)
        } else if let origIdx = sourceTrackIndex {
            project.tracks[origIdx].clips.append(clip)
        }

        hasUnsavedChanges = true
        debouncedRebuildComposition()
        objectWillChange.send()
    }

    // MARK: - Magnetismo Inteligente (Snapping)
    /// Calcula el tiempo ajustado por magnetismo sutil con respecto a otros clips de todas las pistas,
    /// cabezal de reproducción e inicio de la línea de tiempo.
    public func snapTime(
        candidateStartTime: Double,
        clipDuration: Double,
        ignoringClipId: UUID? = nil
    ) -> (snappedStartTime: Double, guideTime: Double?) {
        guard isSnappingEnabled else { return (candidateStartTime, nil) }

        // Umbral sutil en segundos: ~14 píxeles de tolerancia en pantalla
        let pixelTolerance: Double = 14.0
        let timeTolerance = max(0.04, min(0.35, pixelTolerance / timelineZoom))

        var snapPoints: Set<Double> = [0.0]
        snapPoints.insert(playbackEngine.currentTime)

        // Recolectar puntos de corte de todas las capas (video y audio)
        for track in project.tracks {
            for clip in track.clips {
                if clip.id == ignoringClipId { continue }
                snapPoints.insert(clip.startTime)
                snapPoints.insert(clip.endTime)
            }
        }

        let candidateEndTime = candidateStartTime + clipDuration

        var closestDelta = Double.infinity
        var bestStartTime = candidateStartTime
        var bestGuideTime: Double? = nil

        for point in snapPoints {
            // 1. Magnetismo del inicio del clip al punto (start -> point)
            let deltaStart = abs(candidateStartTime - point)
            if deltaStart <= timeTolerance && deltaStart < closestDelta {
                closestDelta = deltaStart
                bestStartTime = point
                bestGuideTime = point
            }

            // 2. Magnetismo del final del clip al punto (end -> point)
            let deltaEnd = abs(candidateEndTime - point)
            if deltaEnd <= timeTolerance && deltaEnd < closestDelta {
                closestDelta = deltaEnd
                bestStartTime = max(0, point - clipDuration)
                bestGuideTime = point
            }
        }

        return (bestStartTime, bestGuideTime)
    }

    /// Actualiza la previsualización del magnetismo en tiempo real durante el arrastre
    public func updateLiveSnapPreview(candidateStartTime: Double, clipDuration: Double, clipId: UUID) -> Double {
        let (snapped, guide) = snapTime(candidateStartTime: candidateStartTime, clipDuration: clipDuration, ignoringClipId: clipId)
        if snapGuideLineTime != guide {
            snapGuideLineTime = guide
        }
        return snapped
    }

    public func clearSnapGuide() {
        if snapGuideLineTime != nil {
            snapGuideLineTime = nil
        }
    }

    /// Recorte por bordes: punto In
    public func trimClipIn(clipId: UUID, deltaSeconds: Double) {
        for tIdx in 0..<project.tracks.count {
            if let cIdx = project.tracks[tIdx].clips.firstIndex(where: { $0.id == clipId }) {
                let assetDur = assetsById[project.tracks[tIdx].clips[cIdx].assetId]?.duration ?? 0
                project.tracks[tIdx].clips[cIdx].trimIn(deltaSeconds: deltaSeconds, maxAssetDuration: assetDur)
                hasUnsavedChanges = true
                debouncedRebuildComposition()
                break
            }
        }
    }

    /// Recorte por bordes: punto Out
    public func trimClipOut(clipId: UUID, deltaSeconds: Double) {
        for tIdx in 0..<project.tracks.count {
            if let cIdx = project.tracks[tIdx].clips.firstIndex(where: { $0.id == clipId }) {
                let assetDur = assetsById[project.tracks[tIdx].clips[cIdx].assetId]?.duration ?? 0
                project.tracks[tIdx].clips[cIdx].trimOut(deltaSeconds: deltaSeconds, maxAssetDuration: assetDur)
                hasUnsavedChanges = true
                debouncedRebuildComposition()
                break
            }
        }
    }

    /// Herramienta de corte: Cmd + B para dividir el clip seleccionado en la posición del playhead
    public func splitSelectedClipAtPlayhead() {
        guard let selectedId = selectedClipId else { return }
        let playheadTime = playbackEngine.currentTime

        for tIdx in 0..<project.tracks.count {
            guard !project.tracks[tIdx].isLocked else { continue }
            if let cIdx = project.tracks[tIdx].clips.firstIndex(where: { $0.id == selectedId }) {
                let currentClip = project.tracks[tIdx].clips[cIdx]
                if let (firstPart, secondPart) = currentClip.split(at: playheadTime) {
                    project.tracks[tIdx].clips[cIdx] = firstPart
                    project.tracks[tIdx].clips.append(secondPart)
                    selectedClipId = secondPart.id // Seleccionar la parte posterior
                    hasUnsavedChanges = true
                    debouncedRebuildComposition()
                    recordHistory(title: "Dividir clip", icon: "scissors")
                }
                break
            }
        }
    }

    /// Elimina el clip seleccionado (Tecla Delete / Retroceso)
    public func deleteSelectedClip() {
        guard let selectedId = selectedClipId else { return }
        for tIdx in 0..<project.tracks.count {
            project.tracks[tIdx].clips.removeAll { $0.id == selectedId }
        }
        // Limpiar capas que hayan quedado vacías para restaurar el estado inicial si no quedan elementos
        project.tracks.removeAll { $0.clips.isEmpty }
        selectedClipId = nil
        selectedTrackId = nil

        if project.tracks.isEmpty {
            playbackEngine.pause()
            playbackEngine.seek(to: 0.0)
        }

        hasUnsavedChanges = true
        debouncedRebuildComposition()
        recordHistory(title: "Eliminar clip", icon: "trash")
        objectWillChange.send()
    }

    /// Salta al corte o inicio de clip anterior (Flecha Arriba ↑)
    public func jumpToPreviousCut() {
        let current = playbackEngine.currentTime
        var cutPoints: Set<Double> = [0.0]
        for track in project.tracks {
            for clip in track.clips {
                cutPoints.insert(clip.startTime)
                cutPoints.insert(clip.endTime)
            }
        }
        let sorted = cutPoints.sorted()
        if let prevCut = sorted.last(where: { $0 < current - 0.05 }) {
            playbackEngine.seek(to: prevCut)
        } else {
            playbackEngine.seek(to: 0.0)
        }
    }

    /// Salta al siguiente corte o fin de clip (Flecha Abajo ↓)
    public func jumpToNextCut() {
        let current = playbackEngine.currentTime
        var cutPoints: Set<Double> = [project.totalDuration]
        for track in project.tracks {
            for clip in track.clips {
                cutPoints.insert(clip.startTime)
                cutPoints.insert(clip.endTime)
            }
        }
        let sorted = cutPoints.sorted()
        if let nextCut = sorted.first(where: { $0 > current + 0.05 }) {
            playbackEngine.seek(to: nextCut)
        } else {
            playbackEngine.seek(to: project.totalDuration)
        }
    }

    /// Alterna el silenciado del clip seleccionado (Tecla M)
    public func toggleMuteSelectedClip() {
        if selectedClip != nil {
            selectedClip?.isMuted.toggle()
        }
    }

    // MARK: - Portapapeles y Operaciones de Clip (Copiar, Pegar, Duplicar)
    public var clipboardClip: TimelineClip? = nil

    /// Copia el clip seleccionado al portapapeles interno (⌘C)
    public func copySelectedClip() {
        guard let clip = selectedClip else { return }
        self.clipboardClip = clip
    }

    /// Pega el clip del portapapeles en la posición actual del playhead (⌘V)
    public func pasteClipAtPlayhead(targetTrackId: UUID? = nil) {
        guard let source = clipboardClip else { return }
        var pasted = source
        pasted.id = UUID()
        pasted.startTime = playbackEngine.currentTime

        let destinationId: UUID
        if let target = targetTrackId {
            destinationId = target
        } else if project.tracks.contains(where: { $0.id == source.trackId && !$0.isLocked }) {
            destinationId = source.trackId
        } else if let fallback = project.tracks.first(where: { !$0.isLocked }) {
            destinationId = fallback.id
        } else {
            return
        }

        pasted.trackId = destinationId

        // Aplicar magnetismo sutil al pegar si coincide con otro borde
        let (snappedStart, _) = snapTime(candidateStartTime: pasted.startTime, clipDuration: pasted.duration)
        pasted.startTime = snappedStart

        if let tIdx = project.tracks.firstIndex(where: { $0.id == destinationId }) {
            project.tracks[tIdx].clips.append(pasted)
            selectedClipId = pasted.id
            hasUnsavedChanges = true
            debouncedRebuildComposition()
            objectWillChange.send()
        }
    }

    /// Duplica el clip seleccionado colocándolo inmediatamente a continuación (⌘D)
    public func duplicateSelectedClip() {
        guard let selectedId = selectedClipId else { return }
        duplicateClip(id: selectedId)
    }

    /// Duplica un clip específico colocándolo inmediatamente después en la misma pista
    public func duplicateClip(id: UUID) {
        for tIdx in 0..<project.tracks.count {
            if let clip = project.tracks[tIdx].clips.first(where: { $0.id == id }) {
                var clone = clip
                clone.id = UUID()
                clone.name = "\(clip.name) (Copia)"
                clone.startTime = clip.endTime + 0.5
                project.tracks[tIdx].clips.append(clone)
                selectedClipId = clone.id
                hasUnsavedChanges = true
                debouncedRebuildComposition()
                break
            }
        }
    }

    // MARK: - Fotogramas Clave (Keyframes)
    public func isKeyframeActive(for property: AnimatableProperty) -> Bool {
        guard let clip = selectedClip else { return false }
        let relativeTime = playbackEngine.currentTime - clip.startTime
        return clip.hasKeyframe(for: property, at: relativeTime)
    }

    public func hasAnyKeyframes(for property: AnimatableProperty) -> Bool {
        guard let clip = selectedClip else { return false }
        switch property {
        case .opacity: return !clip.opacityKeyframes.isEmpty
        case .volume: return !clip.volumeKeyframes.isEmpty
        case .scale: return !clip.scaleKeyframes.isEmpty
        case .rotation: return !clip.rotationKeyframes.isEmpty
        }
    }

    public func toggleKeyframe(for property: AnimatableProperty) {
        guard let clip = selectedClip else { return }
        let relativeTime = currentClipRelativeTime
        let val: Double
        switch property {
        case .opacity: val = clip.opacity(at: relativeTime)
        case .volume: val = clip.volume(at: relativeTime)
        case .scale: val = clip.scale(at: relativeTime)
        case .rotation: val = clip.rotation(at: relativeTime)
        }
        updateSelectedClip { c in
            c.toggleKeyframe(for: property, at: relativeTime, currentValue: val)
        }
        recordHistory(title: "Alternar fotograma clave: \(property.displayName)", icon: "diamond.fill")
    }

    // MARK: - Reordenamiento de Jerarquía de Capas (El elemento de arriba manda)
    public func moveTrackUp(id: UUID) {
        guard let index = project.tracks.firstIndex(where: { $0.id == id }), index > 0 else { return }
        project.tracks.swapAt(index, index - 1)
        recordHistory(title: "Subir capa en jerarquía", icon: "arrow.up")
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        objectWillChange.send()
    }

    public func moveTrackDown(id: UUID) {
        guard let index = project.tracks.firstIndex(where: { $0.id == id }), index < project.tracks.count - 1 else { return }
        project.tracks.swapAt(index, index + 1)
        recordHistory(title: "Bajar capa en jerarquía", icon: "arrow.down")
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        objectWillChange.send()
    }

    // MARK: - Historial de Acciones (Estilo Adobe: Deshacer / Rehacer / Viaje Temporal)
    public var canUndo: Bool {
        return currentHistoryIndex > 0 && !historyStates.isEmpty
    }

    public var canRedo: Bool {
        return currentHistoryIndex < historyStates.count - 1
    }

    public func recordHistory(title: String, icon: String = "clock.arrow.circlepath") {
        guard !isRestoringHistoryState else { return }

        // Si estábamos en un punto anterior, truncamos los estados futuros
        if !historyStates.isEmpty && currentHistoryIndex < historyStates.count - 1 {
            historyStates.removeSubrange((currentHistoryIndex + 1)...)
        }

        let newState = HistoryState(
            title: title,
            icon: icon,
            timestamp: Date(),
            snapshot: self.project,
            selectedClipId: self.selectedClipId,
            playheadTime: self.playbackEngine.currentTime
        )

        historyStates.append(newState)

        if historyStates.count > maxHistoryStates {
            historyStates.removeFirst(historyStates.count - maxHistoryStates)
        }

        currentHistoryIndex = historyStates.count - 1
        hasUnsavedChanges = true
    }

    public func jumpToHistoryState(at index: Int) {
        guard index >= 0 && index < historyStates.count else { return }
        isRestoringHistoryState = true
        defer { isRestoringHistoryState = false }

        let state = historyStates[index]
        self.project = state.snapshot
        self.selectedClipId = state.selectedClipId
        self.playbackEngine.seek(to: state.playheadTime)
        self.currentHistoryIndex = index
        self.rebuildComposition()
        self.objectWillChange.send()
    }

    public func undo() {
        guard canUndo else { return }
        jumpToHistoryState(at: currentHistoryIndex - 1)
    }

    public func redo() {
        guard canRedo else { return }
        jumpToHistoryState(at: currentHistoryIndex + 1)
    }

    public func clearHistory() {
        guard currentHistoryIndex >= 0 && currentHistoryIndex < historyStates.count else { return }
        let current = historyStates[currentHistoryIndex]
        let base = HistoryState(
            title: "Estado base",
            icon: "arrow.counterclockwise",
            timestamp: Date(),
            snapshot: current.snapshot,
            selectedClipId: current.selectedClipId,
            playheadTime: current.playheadTime
        )
        historyStates = [base]
        currentHistoryIndex = 0
        objectWillChange.send()
    }

    // MARK: - Gestión de Pistas
    public func addTrack(kind: TrackKind) {
        let count = project.tracks.filter { $0.kind == kind }.count + 1
        let prefix = (kind == .video) ? "Capa V" : "Audio A"
        let newTrack = TimelineTrack(name: "\(prefix)\(count)", kind: kind)
        project.tracks.insert(newTrack, at: 0)
        hasUnsavedChanges = true
        objectWillChange.send()
    }

    /// Renombra una capa/pista con el nombre personalizado del usuario
    public func renameTrack(id: UUID, newName: String) {
        if let idx = project.tracks.firstIndex(where: { $0.id == id }) {
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                project.tracks[idx].name = trimmed
                hasUnsavedChanges = true
                objectWillChange.send()
            }
        }
    }

    /// Elimina una capa/pista y todos los clips que contiene
    public func deleteTrack(id: UUID) {
        project.tracks.removeAll { $0.id == id }
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        objectWillChange.send()
    }

    /// Duplica una capa/pista completa con todos sus clips
    public func duplicateTrack(id: UUID) {
        guard let source = project.tracks.first(where: { $0.id == id }) else { return }
        let newTrackId = UUID()
        var clonedClips: [TimelineClip] = []
        for c in source.clips {
            var clipClone = c
            clipClone.id = UUID()
            clipClone.trackId = newTrackId
            clonedClips.append(clipClone)
        }
        let finalTrack = TimelineTrack(
            id: newTrackId,
            name: "\(source.name) (Copia)",
            kind: source.kind,
            isMuted: source.isMuted,
            isLocked: source.isLocked,
            isHidden: source.isHidden,
            clips: clonedClips
        )
        if let idx = project.tracks.firstIndex(where: { $0.id == id }) {
            project.tracks.insert(finalTrack, at: idx)
        } else {
            project.tracks.append(finalTrack)
        }
        hasUnsavedChanges = true
        debouncedRebuildComposition()
        objectWillChange.send()
    }

    public func toggleMuteTrack(id: UUID) {
        if let idx = project.tracks.firstIndex(where: { $0.id == id }) {
            project.tracks[idx].isMuted.toggle()
            hasUnsavedChanges = true
            debouncedRebuildComposition()
        }
    }

    public func toggleLockTrack(id: UUID) {
        if let idx = project.tracks.firstIndex(where: { $0.id == id }) {
            project.tracks[idx].isLocked.toggle()
            hasUnsavedChanges = true
        }
    }

    public func toggleHideTrack(id: UUID) {
        if let idx = project.tracks.firstIndex(where: { $0.id == id }) {
            project.tracks[idx].isHidden.toggle()
            hasUnsavedChanges = true
            debouncedRebuildComposition()
        }
    }

    // MARK: - Construcción de Composición AVFoundation
    public func debouncedRebuildComposition() {
        compositionBuildTask?.cancel()
        compositionBuildTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000) // 120ms debounce
            guard !Task.isCancelled else { return }
            self.rebuildComposition()
        }
    }

    public func rebuildComposition() {
        Task {
            let result = await CompositionBuilder.build(
                tracks: project.tracks,
                assets: assetsById,
                configuration: project.configuration
            )
            let dur = CMTimeGetSeconds(result.totalDuration)
            let effectiveDur = max(dur.isFinite ? dur : 0.0, project.totalDuration)
            self.playbackEngine.loadComposition(
                result.composition,
                videoComposition: result.videoComposition,
                audioMix: result.audioMix,
                duration: effectiveDur
            )
        }
    }

    // MARK: - Guardado y Carga de Proyecto (.88proj)
    public func saveProject(to url: URL? = nil) {
        let destinationURL = url ?? currentProjectURL
        guard let finalURL = destinationURL else {
            promptSavePanel()
            return
        }

        do {
            project.modifiedAt = Date()
            let data = try project.serialize()
            try data.write(to: finalURL, options: .atomic)
            currentProjectURL = finalURL
            hasUnsavedChanges = false
            print("[88 Editor] Proyecto guardado exitosamente en \(finalURL.path)")
        } catch {
            print("[88 Editor] Error al guardar proyecto: \(error.localizedDescription)")
        }
    }

    public func promptSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Guardar Proyecto de 88 Editor"
        panel.nameFieldStringValue = "\(project.projectName).88proj"
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true

        if panel.runModal() == .OK, let selectedURL = panel.url {
            let finalURL = selectedURL.pathExtension == "88proj" ? selectedURL : selectedURL.appendingPathExtension("88proj")
            saveProject(to: finalURL)
        }
    }

    public func loadProject(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            var loadedProject = try ProjectDocument.deserialize(from: data)

            // Resolver Security-Scoped Bookmarks de los assets vinculados
            for (idx, asset) in loadedProject.assets.enumerated() {
                if let bookmarkData = asset.bookmarkData {
                    if let resolved = SecurityScopedBookmarkManager.shared.resolveBookmark(data: bookmarkData) {
                        loadedProject.assets[idx].fileURL = resolved.url
                    }
                }
            }

            self.project = loadedProject
            self.currentProjectURL = url
            self.hasUnsavedChanges = false
            self.selectedClipId = nil
            self.rebuildComposition()
            self.playbackEngine.seek(to: 0.0)
        } catch {
            print("[88 Editor] Error cargando proyecto desde \(url.path): \(error)")
        }
    }

    public func promptOpenProjectPanel() {
        checkUnsavedChangesBeforeAction {
            let panel = NSOpenPanel()
            panel.title = "Abrir Proyecto de 88 Editor"
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false

            if panel.runModal() == .OK, let selectedURL = panel.url {
                self.loadProject(from: selectedURL)
            }
        }
    }

    public func promptImportMediaPanel() {
        let panel = NSOpenPanel()
        panel.title = "Importar Medios a 88 Editor"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [
            .movie,
            .video,
            .quickTimeMovie,
            .mpeg4Movie,
            .audio,
            .mp3,
            .wav,
            .image,
            .png,
            .jpeg
        ]

        if panel.runModal() == .OK {
            self.importFiles(urls: panel.urls)
        }
    }

    // MARK: - Nuevo Proyecto
    public func createNewProject(with configuration: ProjectConfiguration) {
        checkUnsavedChangesBeforeAction {
            self.project = ProjectDocument(configuration: configuration)
            self.currentProjectURL = nil
            self.hasUnsavedChanges = false
            self.selectedClipId = nil
            self.playbackEngine.seek(to: 0.0)
            self.rebuildComposition()
        }
    }

    public func checkUnsavedChangesBeforeAction(action: @escaping () -> Void) {
        if hasUnsavedChanges {
            pendingActionAfterAlert = action
            showUnsavedChangesAlert = true
        } else {
            action()
        }
    }
}
