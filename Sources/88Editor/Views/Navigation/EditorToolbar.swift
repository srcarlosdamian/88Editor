import SwiftUI
import AppKit

/// Barra de herramientas unificada superior nativa de macOS.
/// Soporta doble clic en el área vacía para ajustar/maximizar la ventana al tamaño completo de la pantalla.
public struct EditorToolbar: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject private var updateManager = AppUpdateManager.shared
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

            // Título de la app y estado de cambios / autoguardado
            HStack(spacing: 8) {
                AppLogoIconView(size: 24, cornerRadius: 5)

                Text(viewModel.project.projectName)
                    .font(.system(size: 12, weight: .semibold))

                if viewModel.hasUnsavedChanges {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Cambios sin guardar")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .help("Hay cambios sin guardar (Autoguardado activo cada 30s o pulsa ⌘S)")
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(viewModel.autosaveStatusMessage)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .help("Proyecto e historial guardados")
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
                // Botón neutro y lineal para actualizar sin bloquear el flujo de trabajo
                if updateManager.isUpdateAvailable {
                    Button {
                        updateManager.isUpdateSheetPresented = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 11, weight: .medium))
                            Text("Actualizar (\(updateManager.latestVersion))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.primary.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Nueva versión disponible (\(updateManager.latestVersion)). Haz clic aquí para actualizar cuando estés lista.")
                    .transition(.opacity.combined(with: .scale))
                }

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

                // Editar Ajustes de Proyecto (Tamaños, Resolución, etc.)
                Button {
                    viewModel.isProjectSettingsSheetPresented = true
                } label: {
                    Label("Editar", systemImage: "slider.horizontal.3")
                }
                .help("Editar tamaño, resolución y ajustes del proyecto")

                // Importar Medios
                Button {
                    viewModel.promptImportMediaPanel()
                } label: {
                    Label("Importar", systemImage: "arrow.down.doc")
                }
                .help("Importar archivos multimedia sin duplicar (⌘I)")

                // Exportar / Renderizar Video
                Button {
                    viewModel.promptExportRenderPanel()
                } label: {
                    Label("Exportar", systemImage: "arrow.up.forward.app")
                }
                .help("Renderizar y exportar video final (⌘E)")
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
