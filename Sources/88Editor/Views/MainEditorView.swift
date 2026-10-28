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
                    if showLeftSidebar {
                        let leftWidth = max(220, min(280, geo.size.width * 0.22))
                        MediaPoolView(viewModel: viewModel)
                            .frame(width: leftWidth)
                            .transition(.move(edge: .leading))

                        Rectangle()
                            .fill(DesignSystem.border)
                            .frame(width: 1)
                    }

                    CanvasView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

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
            timelineResizeHandle

            // Panel Inferior: Línea de Tiempo Multicapa (Altura adaptable)
            TimelineView(viewModel: viewModel)
                .frame(height: timelineHeight)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.18), value: showLeftSidebar)
        .animation(.easeInOut(duration: 0.18), value: showRightSidebar)
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
        .overlay(alignment: .top) {
            toastOverlay
        }
        .modifier(EditorProjectNotificationHandler(viewModel: viewModel))
        .modifier(EditorClipNotificationHandler(viewModel: viewModel))
        .modifier(EditorPlaybackNotificationHandler(viewModel: viewModel))
        .modifier(EditorSheetsHandler(viewModel: viewModel))
    }

    private var timelineResizeHandle: some View {
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
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toastMsg = viewModel.notificationToastMessage {
            HStack(spacing: 8) {
                Image(systemName: viewModel.notificationToastIcon)
                    .foregroundColor(.primary)
                    .font(.system(size: 13, weight: .semibold))

                Text(toastMsg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Button {
                    viewModel.notificationToastMessage = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
            .padding(.top, 42)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(999)
        }
    }
}

// MARK: - Manejadores modulares para evitar saturar el verificador de tipos de Swift
private struct EditorProjectNotificationHandler: ViewModifier {
    @ObservedObject var viewModel: EditorViewModel

    func body(content: Content) -> some View {
        content
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
    }
}

private struct EditorClipNotificationHandler: ViewModifier {
    @ObservedObject var viewModel: EditorViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .cutClipAction)) { _ in
                viewModel.cutSelectedClip()
            }
            .onReceive(NotificationCenter.default.publisher(for: .copyClipAction)) { _ in
                viewModel.copySelectedClip()
            }
            .onReceive(NotificationCenter.default.publisher(for: .pasteClipAction)) { _ in
                viewModel.pasteClipAtPlayhead()
            }
            .onReceive(NotificationCenter.default.publisher(for: .duplicateClipAction)) { _ in
                viewModel.duplicateSelectedClip()
            }
            .onReceive(NotificationCenter.default.publisher(for: .deleteClipAction)) { _ in
                viewModel.deleteSelectedClip()
            }
            .onReceive(NotificationCenter.default.publisher(for: .splitClipAtPlayhead)) { _ in
                viewModel.splitSelectedClipAtPlayhead()
            }
    }
}

private struct EditorPlaybackNotificationHandler: ViewModifier {
    @ObservedObject var viewModel: EditorViewModel

    func body(content: Content) -> some View {
        content
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
    }
}

private struct EditorSheetsHandler: ViewModifier {
    @ObservedObject var viewModel: EditorViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.isNewProjectSheetPresented) {
                NewProjectSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isProjectSettingsSheetPresented) {
                ProjectSettingsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isExportSettingsSheetPresented) {
                ExportSettingsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isExportSheetPresented) {
                ExportRenderSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isCropSheetPresented) {
                if let clip = viewModel.clipBeingCropped {
                    CropSheet(viewModel: viewModel, clip: clip)
                }
            }
            .sheet(isPresented: $viewModel.isFontPickerPresented) {
                FontPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isInsertSheetPresented) {
                InsertItemSheet(viewModel: viewModel, initialCategory: viewModel.insertSheetCategory)
            }
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
            .alert("Formato no compatible", isPresented: $viewModel.showUnsupportedFormatAlert) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(viewModel.unsupportedFormatAlertMessage ?? "El formato del archivo no es compatible con AVFoundation en macOS.")
            }
    }
}
