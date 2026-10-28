import SwiftUI

/// Comandos del menú principal del sistema macOS para 88 Editor
public struct EditorMenuCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Importar Medios...") {
                NotificationCenter.default.post(name: .promptImportMedia, object: nil)
            }
            .keyboardShortcut("i", modifiers: [.command])
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
        }
    }
}

public extension Notification.Name {
    static let promptImportMedia = Notification.Name("88Editor.promptImportMedia")
    static let splitClipAtPlayhead = Notification.Name("88Editor.splitClipAtPlayhead")
    static let togglePlayback = Notification.Name("88Editor.togglePlayback")
}
