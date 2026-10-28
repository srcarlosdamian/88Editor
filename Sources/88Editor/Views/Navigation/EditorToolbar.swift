import SwiftUI
import AppKit

/// Barra de herramientas unificada superior nativa de macOS.
/// Soporta doble clic en el área vacía para ajustar/maximizar la ventana al tamaño completo de la pantalla.
public struct EditorToolbar: View {
    @ObservedObject var viewModel: EditorViewModel
    @Binding var showLeftSidebar: Bool
    @Binding var showRightSidebar: Bool

    public var body: some View {
        HStack(spacing: 12) {
            // Alternar barra lateral izquierda (Media Pool)
            Button {
                showLeftSidebar.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundColor(showLeftSidebar ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help("Alternar Galería de Medios (⌘1)")

            // Título de la app y estado de cambios
            HStack(spacing: 8) {
                AppLogoIconView(size: 24, cornerRadius: 5)

                Text(viewModel.project.projectName)
                    .font(.system(size: 12, weight: .semibold))

                if viewModel.hasUnsavedChanges {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                        .help("Hay cambios sin guardar en el proyecto")
                }
            }

            // Espacio central interactivo: Doble clic ajusta la ventana a pantalla completa
            Spacer()
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    toggleWindowZoom()
                }

            // Acciones de proyecto
            HStack(spacing: 8) {
                // Nuevo Proyecto
                Button {
                    viewModel.isNewProjectSheetPresented = true
                } label: {
                    Label("Nuevo", systemImage: "plus")
                }
                .help("Crear nuevo proyecto (⌘N)")

                // Abrir Proyecto
                Button {
                    viewModel.promptOpenProjectPanel()
                } label: {
                    Label("Abrir", systemImage: "folder")
                }
                .help("Abrir proyecto .88proj (⌘O)")

                // Guardar Proyecto
                Button {
                    viewModel.saveProject()
                } label: {
                    Label("Guardar", systemImage: "square.and.arrow.down")
                }
                .help("Guardar cambios (⌘S)")

                Divider().frame(height: 16)

                // Importar Medios
                Button {
                    viewModel.promptImportMediaPanel()
                } label: {
                    Label("Importar", systemImage: "arrow.down.doc")
                }
                .help("Importar archivos multimedia sin duplicar (⌘I)")
            }

            // Alternar barra lateral derecha (Inspector)
            Button {
                showRightSidebar.toggle()
            } label: {
                Image(systemName: "sidebar.right")
                    .foregroundColor(showRightSidebar ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .help("Alternar Inspector (⌘2)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Color(NSColor.windowBackgroundColor)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    toggleWindowZoom()
                }
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DesignSystem.border),
            alignment: .bottom
        )
    }

    /// Ajusta la ventana al tamaño completo de la pantalla (Zoom de ventana nativo de macOS)
    private func toggleWindowZoom() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }
        window.performZoom(nil)
    }
}
