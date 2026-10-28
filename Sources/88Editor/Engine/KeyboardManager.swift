import AppKit
import SwiftUI

/// Administrador central de atajos de teclado nativos para 88 Editor.
/// Monitorea eventos de teclado globales con NSEvent.addLocalMonitorForEvents,
/// ejecutando eliminación con Delete/Backspace, navegación cuadro a cuadro con flechas,
/// atajos J/K/L, corte con Cmd+B y silenciado con M, sin interferir al escribir texto.
@MainActor
public final class KeyboardManager: ObservableObject {
    private var eventMonitor: Any?

    public init() {}

    public func startMonitoring(
        viewModel: EditorViewModel,
        toggleLeftSidebar: @escaping () -> Void,
        toggleRightSidebar: @escaping () -> Void
    ) {
        stopMonitoring()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak viewModel] event in
            guard let viewModel = viewModel else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keyCode = event.keyCode
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

            // 1. BARRA ESPACIADORA (Play / Pausa) - keyCode 49
            if keyCode == 49 && flags.isEmpty {
                // Si el foco quedó atrapado en el buscador pero está vacío o no se está redactando:
                if self.isUserEditingText() {
                    if viewModel.mediaSearchText.isEmpty {
                        // Liberar foco del buscador y ejecutar reproducción
                        NSApp.keyWindow?.makeFirstResponder(nil)
                        viewModel.playbackEngine.togglePlayPause()
                        return nil
                    }
                    // Usuario redactando búsqueda con texto previo: permitir carácter espacio
                    return event
                }
                viewModel.playbackEngine.togglePlayPause()
                return nil
            }

            // 2. ESCAPE (keyCode 53): Cerrar modales activos, liberar foco de texto o deseleccionar
            if keyCode == 53 {
                // A) Si hay algún modal/hoja activa, cancelarla y cerrarla inmediatamente
                if viewModel.isProjectSettingsSheetPresented {
                    viewModel.isProjectSettingsSheetPresented = false
                    return nil
                }
                if viewModel.isInsertSheetPresented {
                    viewModel.isInsertSheetPresented = false
                    return nil
                }
                if viewModel.isFontPickerPresented {
                    viewModel.isFontPickerPresented = false
                    return nil
                }
                if viewModel.isExportSheetPresented {
                    viewModel.cancelExport()
                    return nil
                }
                if viewModel.isNewProjectSheetPresented {
                    viewModel.isNewProjectSheetPresented = false
                    return nil
                }
                if self.isUserEditingText() {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    return nil
                }
                if viewModel.selectedClipId != nil {
                    viewModel.selectedClipId = nil
                    return nil
                }
                if viewModel.selectedTrackId != nil {
                    viewModel.selectedTrackId = nil
                    return nil
                }
                return nil
            }

            // 3. TECLA DELETE / RETROCESO (keyCode 51 = Backspace, keyCode 117 = Forward Delete)
            if keyCode == 51 || keyCode == 117 {
                // Prioridad 1: Si hay un clip seleccionado en la línea de tiempo, SIEMPRE eliminar el clip
                if viewModel.selectedClip != nil {
                    viewModel.deleteSelectedClip()
                    return nil // Evento consumido
                }

                // Prioridad 2: Si hay una capa/pista seleccionada:
                if let trackId = viewModel.selectedTrackId {
                    viewModel.deleteTrack(id: trackId)
                    return nil
                }

                // Prioridad 3: Si hay un archivo seleccionado en la galería:
                if let assetId = viewModel.selectedAssetId {
                    // Si el usuario no está redactando activamente texto en el buscador (o el buscador está vacío)
                    if !self.isUserEditingText() || viewModel.mediaSearchText.isEmpty {
                        viewModel.removeAsset(id: assetId)
                        return nil // Evento consumido
                    }
                }
            }

            // Si el usuario está escribiendo activamente en un campo de texto, respetar entrada
            if self.isUserEditingText() {
                return event
            }

            // 3. CORTE: Cmd + B o tecla C / B directa
            if (flags.contains(.command) && chars == "b") || (flags.isEmpty && (chars == "b" || chars == "c")) {
                viewModel.splitSelectedClipAtPlayhead()
                return nil
            }

            // 4. NAVEGACIÓN Y SHUTTLE J / K / L
            if flags.isEmpty && chars == "k" {
                viewModel.playbackEngine.pause()
                return nil
            }
            if flags.isEmpty && chars == "l" {
                viewModel.playbackEngine.play()
                return nil
            }
            if flags.isEmpty && chars == "j" {
                viewModel.playbackEngine.stepFrameBackward(fps: 30)
                return nil
            }

            // 5. NAVEGACIÓN CUADRO A CUADRO CON FLECHAS
            if keyCode == 123 { // Flecha Izquierda ←
                if flags.contains(.command) {
                    viewModel.playbackEngine.seek(to: 0.0) // Inicio
                } else if flags.contains(.shift) {
                    let newTime = max(0, viewModel.playbackEngine.currentTime - 1.0)
                    viewModel.playbackEngine.seek(to: newTime) // 1 seg atrás
                } else {
                    viewModel.playbackEngine.stepFrameBackward(fps: viewModel.project.configuration.framerate.rawValue)
                }
                return nil
            }

            if keyCode == 124 { // Flecha Derecha →
                if flags.contains(.command) {
                    viewModel.playbackEngine.seek(to: viewModel.project.totalDuration) // Fin
                } else if flags.contains(.shift) {
                    let newTime = min(viewModel.project.totalDuration, viewModel.playbackEngine.currentTime + 1.0)
                    viewModel.playbackEngine.seek(to: newTime) // 1 seg adelante
                } else {
                    viewModel.playbackEngine.stepFrameForward(fps: viewModel.project.configuration.framerate.rawValue)
                }
                return nil
            }

            // 6. NAVEGACIÓN ENTRE CORTES (Flecha Arriba ↑ / Abajo ↓)
            if keyCode == 126 && flags.isEmpty {
                viewModel.jumpToPreviousCut()
                return nil
            }
            if keyCode == 125 && flags.isEmpty {
                viewModel.jumpToNextCut()
                return nil
            }

            // 7. INICIO / FIN (Home / End en teclados extendidos)
            if keyCode == 115 { // Home
                viewModel.playbackEngine.seek(to: 0.0)
                return nil
            }
            if keyCode == 119 { // End
                viewModel.playbackEngine.seek(to: viewModel.project.totalDuration)
                return nil
            }

            // 8. SILENCIAR CLIP SELECCIONADO (Tecla M)
            if flags.isEmpty && chars == "m" {
                viewModel.toggleMuteSelectedClip()
                return nil
            }

            // 9. AJUSTAR LÍNEA DE TIEMPO (Shift + Z)
            if flags == .shift && chars == "z" {
                viewModel.fitTimelineToWindow(availableWidth: 800)
                return nil
            }

            // 10. ZOOM DE LÍNEA DE TIEMPO (Option + / Option - / Option Arriba / Option Abajo)
            if flags == .option {
                switch chars {
                case "+", "=":
                    viewModel.zoomInTimeline()
                    return nil
                case "-":
                    viewModel.zoomOutTimeline()
                    return nil
                default:
                    break
                }

                if keyCode == 126 { // Option + Arriba (Aumentar altura de pistas)
                    viewModel.trackHeight = min(100, viewModel.trackHeight + 10)
                    return nil
                }
                if keyCode == 125 { // Option + Abajo (Reducir altura de pistas)
                    viewModel.trackHeight = max(32, viewModel.trackHeight - 10)
                    return nil
                }
            }

            // 11. DESELECCIONAR (Escape)
            if keyCode == 53 {
                if viewModel.selectedClipId != nil {
                    viewModel.selectedClipId = nil
                    return nil
                }
            }

            // 12. COPIAR, PEGAR Y DUPLICAR CLIP (Cmd+C / Cmd+V / Cmd+D)
            if flags == .command {
                switch chars {
                case "c":
                    viewModel.copySelectedClip()
                    return nil
                case "v":
                    viewModel.pasteClipAtPlayhead()
                    return nil
                case "d":
                    viewModel.duplicateSelectedClip()
                    return nil
                default:
                    break
                }
            }

            // 13. ACTIVAR / DESACTIVAR MAGNETISMO (Tecla N)
            if flags.isEmpty && chars == "n" {
                viewModel.isSnappingEnabled.toggle()
                return nil
            }

            // 14. DESHACER / REHACER (Historial estilo Adobe: Cmd+Z / Cmd+Shift+Z / Cmd+Y)
            if flags == .command && chars == "z" {
                viewModel.undo()
                return nil
            }
            if (flags == [.command, .shift] && chars == "z") || (flags == .command && chars == "y") {
                viewModel.redo()
                return nil
            }

            // 15. ATAJOS DE APLICACIÓN CON COMMAND
            if flags.contains(.command) {
                // Cmd + Shift + S: Guardar como...
                if flags.contains(.shift) && chars == "s" {
                    viewModel.promptSavePanel()
                    return nil
                }
                // Cmd + Shift + Z: Rehacer
                if flags.contains(.shift) && chars == "z" {
                    viewModel.redo()
                    return nil
                }
                switch chars {
                case "s":
                    viewModel.saveProject()
                    return nil
                case "o":
                    viewModel.promptOpenProjectPanel()
                    return nil
                case "n":
                    viewModel.isNewProjectSheetPresented = true
                    return nil
                case "e":
                    viewModel.promptExportRenderPanel()
                    return nil
                case "i":
                    viewModel.promptImportMediaPanel()
                    return nil
                case ",":
                    viewModel.isProjectSettingsSheetPresented = true
                    return nil
                case "1":
                    toggleLeftSidebar()
                    return nil
                case "2":
                    toggleRightSidebar()
                    return nil
                default:
                    break
                }
            }

            return event
        }
    }

    public func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func isUserEditingText() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        if responder is NSTextView || responder is NSTextField {
            return true
        }
        return false
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
