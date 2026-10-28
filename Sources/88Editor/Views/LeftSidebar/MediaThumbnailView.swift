import SwiftUI
import AppKit
import AVFoundation
import QuickLookThumbnailing

/// Caché global en memoria de miniaturas de alta velocidad
@MainActor
public final class ThumbnailCache {
    public static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 300
    }

    public func thumbnail(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    public func setThumbnail(_ image: NSImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// Componente visual que genera y muestra la miniatura real de videos, fotos (PNG, JPG, PSD, WebP) o audio
public struct MediaThumbnailView: View {
    let asset: MediaAsset
    let size: CGSize

    @State private var thumbnail: NSImage? = nil

    public init(asset: MediaAsset, size: CGSize = CGSize(width: 52, height: 36)) {
        self.asset = asset
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(NSColor.controlBackgroundColor))

            if let thumb = thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                // Placeholder con icono del tipo de archivo mientras carga
                Image(systemName: asset.mediaType.systemIcon)
                    .font(.system(size: min(size.width, size.height) * 0.42))
                    .foregroundColor(colorForType(asset.mediaType).opacity(0.8))
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        if asset.mediaType == .text || asset.mediaType == .shape {
            return
        }

        let url = asset.fileURL
        let mediaType = asset.mediaType
        let duration = asset.duration
        let targetSize = size

        // 1. Revisar si ya está en caché
        if let cached = ThumbnailCache.shared.thumbnail(for: url) {
            self.thumbnail = cached
            return
        }

        // 2. Generar miniatura en segundo plano
        Task.detached(priority: .userInitiated) {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            var loadedImage: NSImage? = nil

            // A) Si es imagen estática (PNG, JPG, PSD, HEIC, WebP, etc.)
            if mediaType == .image {
                if let direct = NSImage(contentsOf: url) {
                    loadedImage = direct
                }
            }

            // B) Si es video, extraer un fotograma real a los 0.5 segundos
            if loadedImage == nil && mediaType == .video {
                let avAsset = AVURLAsset(url: url)
                let generator = AVAssetImageGenerator(asset: avAsset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: targetSize.width * 2, height: targetSize.height * 2)

                let targetTime = CMTime(seconds: min(0.5, duration / 2), preferredTimescale: 600)
                if let cgImage = try? generator.copyCGImage(at: targetTime, actualTime: nil) {
                    loadedImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
            }

            // C) QuickLook de macOS como respaldo de alta fidelidad
            if loadedImage == nil {
                let reqSize = CGSize(width: targetSize.width * 2, height: targetSize.height * 2)
                let request = QLThumbnailGenerator.Request(fileAt: url, size: reqSize, scale: 2.0, representationTypes: .thumbnail)
                if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                    loadedImage = rep.nsImage
                }
            }

            if let finalThumb = loadedImage {
                await MainActor.run {
                    ThumbnailCache.shared.setThumbnail(finalThumb, for: url)
                    self.thumbnail = finalThumb
                }
            }
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
