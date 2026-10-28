import SwiftUI
import AppKit

/// Vista principal de 88 Editor:
/// Arquitectura de 3 Columnas (Media Pool, Canvas, Inspector) + Línea de Tiempo Inferior Multicapa Responsiva.
/// Modo Oscuro por defecto e integración completa de atajos de teclado profesionales mediante KeyboardManager.
public struct MainEditorView: View {
    @StateObject private var viewModel = EditorViewModel()
    @StateObject private var keyboardManager = KeyboardManager()
    @State private var timelineHeight: CGFloat = 220
    @State private var showLeftSidebar: Bool = true
    @State private var showRightSidebar: Bool = true

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Barra de herramientas superior nativa con alternadores de barra lateral
            EditorToolbar(
                viewModel: viewModel,
                showLeftSidebar: $showLeftSidebar,
                showRightSidebar: $showRightSidebar
            )

            // Panel Superior Responsivo: 3 Columnas
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Columna 1: Media Pool / Galería de Medios (Colapsable)
                    if showLeftSidebar {
                        let leftWidth = max(220, min(280, geo.size.width * 0.22))
                        MediaPoolView(viewModel: viewModel)
                            .frame(width: leftWidth)
                            .transition(.move(edge: .leading))

                        Rectangle()
                            .fill(DesignSystem.border)
                            .frame(width: 1)
                    }

                    // Columna 2: Canvas Central de Previsualización (Ocupa todo el espacio restante)
                    CanvasView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    // Columna 3: Inspector Contextual (Colapsable)
                    if showRightSidebar {
                        Rectangle()
                            .fill(DesignSystem.border)
                            .frame(width: 1)

                        let rightWidth = max(240, min(300, geo.size.width * 0.24))
                        InspectorView(viewModel: viewModel)
                            .frame(width: rightWidth)
                            .transition(.move(edge: .trailing))
                    }
                }
            }

            // Divisor interactivo con cursor de redimensionamiento vertical para el Timeline
            ZStack {
                Rectangle()
                    .fill(DesignSystem.border)
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 36, height: 2)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { val in
                        let proposed = timelineHeight - val.translation.height
                        timelineHeight = min(max(proposed, 140), 500)
                    }
            )

            // Panel Inferior: Línea de Tiempo Multicapa (Altura adaptable)
            TimelineView(viewModel: viewModel)
                .frame(height: timelineHeight)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.18), value: showLeftSidebar)
        .animation(.easeInOut(duration: 0.18), value: showRightSidebar)
        // Inicializar monitoreo de atajos de teclado globales y evitar autofoco indebido en el buscador
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            keyboardManager.startMonitoring(
                viewModel: viewModel,
                toggleLeftSidebar: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showLeftSidebar.toggle()
                    }
                },
                toggleRightSidebar: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showRightSidebar.toggle()
                    }
                }
            )
        }
        .onDisappear {
            keyboardManager.stopMonitoring()
        }
        // Conexión con comandos del Menú superior de macOS
        .onReceive(NotificationCenter.default.publisher(for: .promptNewProject)) { _ in
            viewModel.isNewProjectSheetPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptOpenProject)) { _ in
            viewModel.promptOpenProjectPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptSaveProject)) { _ in
            viewModel.saveProject()
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptSaveProjectAs)) { _ in
            viewModel.promptSavePanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptImportMedia)) { _ in
            viewModel.promptImportMediaPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptExportRender)) { _ in
            viewModel.promptExportRenderPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptProjectSettings)) { _ in
            viewModel.isProjectSettingsSheetPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .splitClipAtPlayhead)) { _ in
            viewModel.splitSelectedClipAtPlayhead()
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePlayback)) { _ in
            viewModel.playbackEngine.togglePlayPause()
        }
        .onReceive(NotificationCenter.default.publisher(for: .undoAction)) { _ in
            viewModel.undo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .redoAction)) { _ in
            viewModel.redo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRecentProjectURL)) { notif in
            if let url = notif.object as? URL {
                viewModel.loadProject(from: url)
            }
        }
        // Modal inicial de proyecto
        .sheet(isPresented: $viewModel.isNewProjectSheetPresented) {
            NewProjectSheet(viewModel: viewModel)
        }
        // Modal de edición de ajustes y tamaño del proyecto
        .sheet(isPresented: $viewModel.isProjectSettingsSheetPresented) {
            ProjectSettingsSheet(viewModel: viewModel)
        }
        // Modal de configuración versátil de exportación (presets, calidad, contenedor, peso)
        .sheet(isPresented: $viewModel.isExportSettingsSheetPresented) {
            ExportSettingsSheet(viewModel: viewModel)
        }
        // Modal de progreso de renderizado
        .sheet(isPresented: $viewModel.isExportSheetPresented) {
            ExportRenderSheet(viewModel: viewModel)
        }
        // Modal interactivo de recorte espacial de bordes (Crop)
        .sheet(isPresented: $viewModel.isCropSheetPresented) {
            if let clip = viewModel.clipBeingCropped {
                CropSheet(viewModel: viewModel, clip: clip)
            }
        }
        // Modal de selección de fuentes nativas (NSFontManager)
        .sheet(isPresented: $viewModel.isFontPickerPresented) {
            FontPickerSheet(viewModel: viewModel)
        }
        // Modal de inserción de texto y formas vectoriales
        .sheet(isPresented: $viewModel.isInsertSheetPresented) {
            InsertItemSheet(viewModel: viewModel, initialCategory: viewModel.insertSheetCategory)
        }
        // Alerta nativa de cambios sin guardar
        .alert("Cambios sin guardar", isPresented: $viewModel.showUnsavedChangesAlert) {
            Button("Guardar y Continuar") {
                viewModel.saveProject()
                viewModel.pendingActionAfterAlert?()
                viewModel.pendingActionAfterAlert = nil
            }
            Button("Descartar Cambios", role: .destructive) {
                viewModel.hasUnsavedChanges = false
                viewModel.pendingActionAfterAlert?()
                viewModel.pendingActionAfterAlert = nil
            }
            Button("Cancelar", role: .cancel) {
                viewModel.pendingActionAfterAlert = nil
            }
        } message: {
            Text("El proyecto actual '\(viewModel.project.projectName)' tiene cambios sin guardar. Si continúas sin guardar, perderás las modificaciones recientes.")
        }
        // Alerta de formato no compatible (ej. MKV)
        .alert("Formato no compatible", isPresented: $viewModel.showUnsupportedFormatAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(viewModel.unsupportedFormatAlertMessage ?? "El formato del archivo no es compatible con AVFoundation en macOS.")
        }
    }
}
