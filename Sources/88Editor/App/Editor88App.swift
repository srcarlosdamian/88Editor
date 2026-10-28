import SwiftUI
import AppKit

/// Punto de entrada principal de la aplicación nativa macOS "88 Editor"
@main
struct Editor88App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainEditorView()
                .frame(minWidth: 1024, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            EditorMenuCommands()
        }
    }
}

/// Delegado de aplicación macOS para gestionar ciclo de vida y confirmación de cierre
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Establecer Modo Oscuro por defecto en toda la aplicación (macOS Dark Aqua)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false

        // Establecer el icono oficial con esquinas redondeadas en el Dock de macOS
        if let iconURL = Bundle.module.url(forResource: "AppIcon_Rounded", withExtension: "png") ?? Bundle.main.url(forResource: "AppIcon_Rounded", withExtension: "png"),
           let iconImg = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImg
        } else if let fallback = NSImage(contentsOfFile: "Sources/88Editor/Resources/AppIcon_Rounded.png") {
            NSApp.applicationIconImage = fallback
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let vm = EditorViewModel.activeInstance else { return .terminateNow }

        if vm.hasMeaningfulWork {
            let alert = NSAlert()
            alert.messageText = "¿Deseas guardar los cambios en '\(vm.project.projectName)' antes de salir?"
            alert.informativeText = "Si sales sin guardar, se perderán las ediciones recientes."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Guardar y Salir")
            alert.addButton(withTitle: "No Guardar")
            alert.addButton(withTitle: "Cancelar")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn: // Guardar y Salir
                vm.saveProject()
                if vm.hasUnsavedChanges {
                    return .terminateCancel
                }
                return .terminateNow
            case .alertSecondButtonReturn: // No Guardar
                return .terminateNow
            default: // Cancelar
                return .terminateCancel
            }
        }
        return .terminateNow
    }
}
