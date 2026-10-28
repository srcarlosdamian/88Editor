import SwiftUI

/// Comandos del menú principal del sistema macOS para 88 Editor
public struct EditorMenuCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nuevo Proyecto...") {
                NotificationCenter.default.post(name: .promptNewProject, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Abrir Proyecto...") {
                NotificationCenter.default.post(name: .promptOpenProject, object: nil)
            }
            .keyboardShortcut("o", modifiers: [.command])

            Menu("Abrir Recientes") {
                RecentProjectsMenuView()
            }

            Divider()

            Button("Guardar Proyecto") {
                NotificationCenter.default.post(name: .promptSaveProject, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button("Guardar Proyecto Como...") {
                NotificationCenter.default.post(name: .promptSaveProjectAs, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("Importar Medios...") {
                NotificationCenter.default.post(name: .promptImportMedia, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button("Exportar y Renderizar Video...") {
                NotificationCenter.default.post(name: .promptExportRender, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command])
        }

        CommandGroup(after: .appSettings) {
            Button("Ajustes del Proyecto...") {
                NotificationCenter.default.post(name: .promptProjectSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cortar") {
                NotificationCenter.default.post(name: .cutClipAction, object: nil)
            }
            .keyboardShortcut("x", modifiers: [.command])

            Button("Copiar") {
                NotificationCenter.default.post(name: .copyClipAction, object: nil)
            }
            .keyboardShortcut("c", modifiers: [.command])

            Button("Pegar") {
                NotificationCenter.default.post(name: .pasteClipAction, object: nil)
            }
            .keyboardShortcut("v", modifiers: [.command])

            Button("Duplicar") {
                NotificationCenter.default.post(name: .duplicateClipAction, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command])

            Divider()

            Button("Eliminar") {
                NotificationCenter.default.post(name: .deleteClipAction, object: nil)
            }
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Deshacer") {
                NotificationCenter.default.post(name: .undoAction, object: nil)
            }
            .keyboardShortcut("z", modifiers: [.command])

            Button("Rehacer") {
                NotificationCenter.default.post(name: .redoAction, object: nil)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandMenu("Edición de Video") {
            Button("Dividir Clip en Cabezal (Split)") {
                NotificationCenter.default.post(name: .splitClipAtPlayhead, object: nil)
            }
            .keyboardShortcut("b", modifiers: [.command])

            Divider()

            Button("Reproducir / Pausa") {
                NotificationCenter.default.post(name: .togglePlayback, object: nil)
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Reproducir en Bucle (Loop)") {
                NotificationCenter.default.post(name: .toggleLoopPlayback, object: nil)
            }
            .keyboardShortcut("l", modifiers: [.command])
        }
    }
}

public struct RecentProjectsMenuView: View {
    @ObservedObject var manager = RecentProjectsManager.shared

    public init() {}

    public var body: some View {
        if manager.recentProjects.isEmpty {
            Text("No hay proyectos recientes")
        } else {
            ForEach(manager.recentProjects) { item in
                Button(item.name) {
                    NotificationCenter.default.post(name: .openRecentProjectURL, object: item.url)
                }
            }
            Divider()
            Button("Borrar menú de recientes") {
                manager.clear()
            }
        }
    }
}

public extension Notification.Name {
    static let promptNewProject = Notification.Name("88Editor.promptNewProject")
    static let promptOpenProject = Notification.Name("88Editor.promptOpenProject")
    static let promptSaveProject = Notification.Name("88Editor.promptSaveProject")
    static let promptSaveProjectAs = Notification.Name("88Editor.promptSaveProjectAs")
    static let promptImportMedia = Notification.Name("88Editor.promptImportMedia")
    static let promptExportRender = Notification.Name("88Editor.promptExportRender")
    static let promptProjectSettings = Notification.Name("88Editor.promptProjectSettings")
    static let cutClipAction = Notification.Name("88Editor.cutClipAction")
    static let copyClipAction = Notification.Name("88Editor.copyClipAction")
    static let pasteClipAction = Notification.Name("88Editor.pasteClipAction")
    static let duplicateClipAction = Notification.Name("88Editor.duplicateClipAction")
    static let deleteClipAction = Notification.Name("88Editor.deleteClipAction")
    static let splitClipAtPlayhead = Notification.Name("88Editor.splitClipAtPlayhead")
    static let togglePlayback = Notification.Name("88Editor.togglePlayback")
    static let toggleLoopPlayback = Notification.Name("88Editor.toggleLoopPlayback")
    static let undoAction = Notification.Name("88Editor.undoAction")
    static let redoAction = Notification.Name("88Editor.redoAction")
    static let openRecentProjectURL = Notification.Name("88Editor.openRecentProjectURL")
}
