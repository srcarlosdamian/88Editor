import SwiftUI
import AppKit

/// Fila individual minimalista para un recurso multimedia vinculado en el Media Pool
public struct MediaAssetRow: View {
    let asset: MediaAsset
    let isSelected: Bool
    let onAddToTimeline: () -> Void
    let onDelete: () -> Void
    var onReconnect: (() -> Void)? = nil

    public var body: some View {
        HStack(spacing: 10) {
            // Miniatura visual real del contenido (video frame, imagen o audio)
            ZStack {
                MediaThumbnailView(asset: asset, size: CGSize(width: 52, height: 36))
                if asset.isMissing {
                    Color.black.opacity(0.6)
                        .cornerRadius(4)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.primary)
                        .font(.system(size: 14))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if asset.isMissing {
                    Text("Archivo no encontrado")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 6) {
                        Text(asset.formattedDuration)
                            .font(DesignSystem.monoFont)
                            .foregroundColor(.secondary)

                        if asset.width > 0 && asset.height > 0 {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(asset.resolutionString)
                                .font(DesignSystem.monoFont)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Botón de reconectar si el archivo no existe
            if asset.isMissing {
                Button {
                    onReconnect?()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.primary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Reconectar o reemplazar archivo eliminado / movido")
            }

            // Botón rápido de eliminar de la galería
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Eliminar de la galería (Delete)")

            // Botón de inserción directa a la línea de tiempo
            Button(action: onAddToTimeline) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("Añadir a la línea de tiempo")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button("Reemplazar objeto / archivo...") {
                onReconnect?()
            }
            Button("Buscar / Localizar en Finder...") {
                onReconnect?()
            }
            Divider()
            Button("Añadir a la línea de tiempo", action: onAddToTimeline)
            if !asset.isMissing {
                Button("Mostrar en Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([asset.fileURL])
                }
            }
            Divider()
            Button("Eliminar de la galería...", role: .destructive, action: onDelete)
        }
        .onDrag {
            NSItemProvider(object: asset.id.uuidString as NSString)
        }
    }

    private func colorForType(_ type: MediaType) -> Color {
        switch type {
        case .video: return DesignSystem.videoClip
        case .audio: return DesignSystem.audioClip
        case .image: return DesignSystem.imageClip
        case .text: return DesignSystem.textClip
        case .shape: return DesignSystem.shapeClip
        }
    }
}
