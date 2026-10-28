import SwiftUI
import AppKit

/// Hoja modal elegante para revisar, descargar e instalar actualizaciones de 88 Editor
public struct AppUpdateSheet: View {
    @ObservedObject var updateManager = AppUpdateManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Cabecera con icono de la app y títulos
            HStack(spacing: 16) {
                AppLogoIconView(size: 48, cornerRadius: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Actualización de 88 Editor")
                        .font(.system(size: 16, weight: .bold))

                    if updateManager.isUpdateAvailable {
                        HStack(spacing: 6) {
                            Text("Versión instalada: v\(updateManager.currentVersion)")
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Nueva: \(updateManager.latestVersion)")
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                        }
                        .font(.system(size: 12))
                    } else if updateManager.isChecking {
                        Text("Buscando actualizaciones en GitHub...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("88 Editor está al día (Versión \(updateManager.currentVersion))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            // Cuerpo del diálogo
            if updateManager.isUpdateAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Novedades de esta versión:")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if updateManager.downloadAssetSize > 0 {
                            Text(String(format: "Tamaño: %.1f MB", Double(updateManager.downloadAssetSize) / (1024 * 1024)))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Caja desplazable con notas de la versión
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(updateManager.releaseNotes.isEmpty ? "Mejoras de rendimiento y corrección de errores." : updateManager.releaseNotes)
                            .font(.system(size: 11, design: .default))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(height: 140)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DesignSystem.border, lineWidth: 1)
                    )

                    // Barra de progreso y estado de descarga
                    if updateManager.isDownloading || updateManager.isInstalling {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: updateManager.downloadProgress, total: 1.0)
                                .progressViewStyle(.linear)

                            Text(updateManager.downloadStatusMessage)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }

                    // Mensaje de error si la descarga/instalación falla
                    if let err = updateManager.updateError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
            } else if updateManager.isChecking {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Conectando con el repositorio...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.green)

                    Text("Ya tienes instalada la versión más reciente.")
                        .font(.system(size: 13, weight: .medium))

                    if let err = updateManager.updateError {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Botonera inferior
            HStack(spacing: 10) {
                if updateManager.isUpdateAvailable {
                    Button("Ver en GitHub") {
                        updateManager.openReleaseInBrowser()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .help("Abrir la página de esta versión en el navegador")
                }

                Spacer()

                if updateManager.isDownloading {
                    Button("Cancelar") {
                        updateManager.cancelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Button(updateManager.isUpdateAvailable ? "Más tarde" : "Cerrar") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if updateManager.isUpdateAvailable && !updateManager.isDownloading && !updateManager.isInstalling {
                    Button {
                        updateManager.startDownloadAndInstall()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Descargar e Instalar")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
        }
        .padding(22)
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
