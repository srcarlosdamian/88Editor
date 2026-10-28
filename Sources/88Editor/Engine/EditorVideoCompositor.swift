import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import AppKit
import VideoToolbox

// MARK: - Generador de Pista Base / Reloj Maestro de Video
public final class BlankVideoTrackGenerator: Sendable {
    /// Retorna una pista de video base de 1 segundo para garantizar que la composición
    /// contenga un track de video maestro en todo momento (incluso en proyectos de sólo fotos/texto/audio).
    public static func getOrCreateBlankVideoTrack() async throws -> AVAssetTrack? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("88Editor_clock_base_1s.mp4")
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            try await generateBlankMP4(at: tempURL)
        }

        let asset = AVURLAsset(url: tempURL)
        if let track = try? await asset.loadTracks(withMediaType: .video).first {
            return track
        } else {
            // Reintentar regeneración limpia si el archivo previo estaba corrupto
            try? FileManager.default.removeItem(at: tempURL)
            try await generateBlankMP4(at: tempURL)
            let freshAsset = AVURLAsset(url: tempURL)
            return try? await freshAsset.loadTracks(withMediaType: .video).first
        }
    }

    private static func generateBlankMP4(at url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(url: url, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 1280,
                kCVPixelBufferHeightKey as String: 720
            ]
        )
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1280, 720, kCVPixelFormatType_32BGRA, nil, &buffer)
        if let pb = buffer {
            adaptor.append(pb, withPresentationTime: .zero)
            let oneSec = CMTime(seconds: 1.0, preferredTimescale: 600)
            adaptor.append(pb, withPresentationTime: oneSec)
        }
        input.markAsFinished()
        await writer.finishWriting()
    }
}

// MARK: - Instrucción de Composición de Video
public final class EditorVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    public var timeRange: CMTimeRange
    public var enablePostProcessing: Bool = false
    public var containsTweening: Bool = true
    public var requiredSourceTrackIDs: [NSValue]?
    public var passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    public let tracks: [TimelineTrack]
    public let assets: [UUID: MediaAsset]
    public let trackToCompID: [UUID: CMPersistentTrackID]
    public let configuration: ProjectConfiguration

    public init(
        timeRange: CMTimeRange,
        tracks: [TimelineTrack],
        assets: [UUID: MediaAsset],
        trackToCompID: [UUID: CMPersistentTrackID],
        configuration: ProjectConfiguration,
        requiredSourceTrackIDs: [NSValue]?
    ) {
        self.timeRange = timeRange
        self.tracks = tracks
        self.assets = assets
        self.trackToCompID = trackToCompID
        self.configuration = configuration
        self.requiredSourceTrackIDs = requiredSourceTrackIDs
        super.init()
    }
}

// MARK: - Compositor de Video Profesional Multicapa
/// Renderiza todas las capas de la línea de tiempo (Videos, Imágenes, Textos y Formas Vectoriales)
/// con interpolación precisa de Keyframes (Escala, Rotación, Opacidad, Posición y Recorte).
public final class EditorVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private static let imageCache = NSCache<NSURL, NSImage>()

    public var sourcePixelBufferAttributes: [String : Any]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }

    public var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    public func cancelAllPendingVideoCompositionRequests() {}

    public func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? EditorVideoCompositionInstruction else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "EditorVideoCompositor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Instrucción de composición inválida"]))
            return
        }

        guard let outputBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
            asyncVideoCompositionRequest.finish(with: NSError(domain: "EditorVideoCompositor", code: -2, userInfo: [NSLocalizedDescriptionKey: "No se pudo asignar búfer de salida"]))
            return
        }

        let currentTime = asyncVideoCompositionRequest.compositionTime.seconds
        let config = instruction.configuration
        let targetW = CGFloat(config.width)
        let targetH = CGFloat(config.height)

        CVPixelBufferLockBaseAddress(outputBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(outputBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(outputBuffer) else {
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputBuffer)
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: baseAddress,
            width: Int(targetW),
            height: Int(targetH),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputBuffer)
            return
        }

        let gc = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc

        // 1. Fondo negro base neutro de la composición
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: targetW, height: targetH).fill()

        // 2. Iterar pistas en orden de capas (Pista 0 al fondo, Pista N al frente)
        for track in instruction.tracks {
            guard !track.isHidden else { continue }

            // Buscar clip activo en el tiempo exacto del fotograma
            guard let clip = track.clips.first(where: { $0.startTime <= currentTime && $0.endTime > currentTime }) else {
                continue
            }

            // Opacidad interpolada (Keyframes o estática)
            let dynamicOpacity = clip.opacity(at: currentTime)
            guard dynamicOpacity > 0.001 else { continue }

            // Escala y Rotación interpoladas
            let dynamicScale = clip.scale(at: currentTime)
            let dynamicRotation = clip.rotation(at: currentTime)

            let (elemW, elemH) = calculateDimensions(
                clip: clip,
                assets: instruction.assets,
                targetW: targetW,
                targetH: targetH
            )

            // Posicionamiento centrado en el visor con offsets de usuario
            let centerX = targetW / 2.0 + CGFloat(clip.positionX)
            let centerY = targetH / 2.0 + CGFloat(clip.positionY)

            ctx.saveGState()
            ctx.setAlpha(CGFloat(dynamicOpacity))

            // Aplicar transformaciones espaciales: traslación, rotación y escala
            ctx.translateBy(x: centerX, y: centerY)
            ctx.rotate(by: CGFloat(dynamicRotation) * .pi / 180.0)
            ctx.scaleBy(x: CGFloat(dynamicScale), y: CGFloat(dynamicScale))

            let localRect = NSRect(x: -elemW / 2.0, y: -elemH / 2.0, width: elemW, height: elemH)

            // Recorte espacial (Crop)
            if clip.hasCrop {
                let cropX = localRect.minX + elemW * CGFloat(clip.cropLeft)
                let cropY = localRect.minY + elemH * CGFloat(clip.cropTop)
                let cropW = elemW * max(0.001, 1.0 - CGFloat(clip.cropLeft) - CGFloat(clip.cropRight))
                let cropH = elemH * max(0.001, 1.0 - CGFloat(clip.cropTop) - CGFloat(clip.cropBottom))
                ctx.clip(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH))
            }

            // Dibujar según el tipo de elemento
            if let shape = clip.shapeType {
                drawVectorShape(shape: shape, fillHex: clip.fillColorHex ?? "#FF3B30", in: localRect)
            } else if let text = clip.textOverlay, !text.isEmpty {
                drawTextOverlay(clip: clip, text: text, in: localRect)
            } else if let asset = instruction.assets[clip.assetId] {
                if asset.mediaType == .image {
                    if let img = Self.loadImage(from: asset.fileURL) {
                        img.draw(in: localRect)
                    }
                } else if asset.mediaType == .video {
                    if let compTrackID = instruction.trackToCompID[track.id],
                       let sourceBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: compTrackID) {
                        var videoCG: CGImage?
                        if VTCreateCGImageFromCVPixelBuffer(sourceBuffer, options: nil, imageOut: &videoCG) == 0, let vCG = videoCG {
                            let nsVideoImg = NSImage(cgImage: vCG, size: localRect.size)
                            nsVideoImg.draw(in: localRect)
                        }
                    }
                }
            }

            ctx.restoreGState()
        }

        NSGraphicsContext.restoreGraphicsState()
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputBuffer)
    }

    // MARK: - Dimensionamiento Proporcional (Idéntico a CanvasView)
    private func calculateDimensions(
        clip: TimelineClip,
        assets: [UUID: MediaAsset],
        targetW: CGFloat,
        targetH: CGFloat
    ) -> (CGFloat, CGFloat) {
        if clip.shapeType != nil {
            let dim: CGFloat = 160.0
            return (dim, dim)
        }

        if let text = clip.textOverlay, !text.isEmpty {
            let fSize = CGFloat(clip.fontSize ?? 54.0)
            let font = resolveFont(name: clip.fontName, size: fSize)
            let size = (text as NSString).size(withAttributes: [.font: font])
            let w = max(160, size.width + 40)
            let h = max(60, size.height + 24)
            return (min(targetW, w), h)
        }

        if let asset = assets[clip.assetId] {
            var w = asset.width
            var h = asset.height
            if w <= 0 || h <= 0 {
                if asset.mediaType == .image, let img = Self.loadImage(from: asset.fileURL) {
                    w = Double(img.size.width)
                    h = Double(img.size.height)
                }
            }
            if w > 0 && h > 0 {
                let aspect = w / h
                let elemH = targetH.rounded()
                let elemW = (targetH * CGFloat(aspect)).rounded()
                return (elemW, elemH)
            }
        }

        return (targetW, targetH)
    }

    // MARK: - Dibujo de Formas Vectoriales
    private func drawVectorShape(shape: String, fillHex: String, in rect: NSRect) {
        let fill = NSColor(hex: fillHex)
        fill.setFill()

        switch shape.lowercased() {
        case "circle":
            NSBezierPath(ovalIn: rect).fill()
        case "star":
            let path = createStarPath(in: rect, points: 5)
            path.fill()
        case "triangle":
            let path = createTrianglePath(in: rect)
            path.fill()
        default:
            NSBezierPath(rect: rect).fill()
        }
    }

    private func createStarPath(in rect: NSRect, points: Int) -> NSBezierPath {
        let path = NSBezierPath()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2.0
        let innerRadius = outerRadius * 0.45
        let angleStep = .pi / CGFloat(points)
        var currentAngle: CGFloat = -.pi / 2.0

        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + radius * cos(currentAngle)
            let y = center.y + radius * sin(currentAngle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.line(to: CGPoint(x: x, y: y))
            }
            currentAngle += angleStep
        }
        path.close()
        return path
    }

    private func createTrianglePath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.close()
        return path
    }

    // MARK: - Dibujo de Textos
    private func drawTextOverlay(clip: TimelineClip, text: String, in rect: NSRect) {
        let textColor = NSColor(hex: clip.textColorHex ?? "#FFFFFF")
        let fSize = CGFloat(clip.fontSize ?? 54.0)
        let font = resolveFont(name: clip.fontName, size: fSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 4

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .shadow: shadow
        ]

        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    private func resolveFont(name: String?, size: CGFloat) -> NSFont {
        if let name = name, let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.boldSystemFont(ofSize: size)
    }

    // MARK: - Caché de Imágenes
    private static func loadImage(from url: URL) -> NSImage? {
        let nsURL = url as NSURL
        if let cached = imageCache.object(forKey: nsURL) {
            return cached
        }
        if let img = NSImage(contentsOf: url) {
            imageCache.setObject(img, forKey: nsURL)
            return img
        }
        return nil
    }
}

// MARK: - Extensión de NSColor para soporte Hexadecimal en AppKit
extension NSColor {
    convenience init(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        let r, g, b, a: CGFloat
        if clean.count == 6 {
            r = CGFloat((rgb >> 16) & 0xFF) / 255.0
            g = CGFloat((rgb >> 8) & 0xFF) / 255.0
            b = CGFloat(rgb & 0xFF) / 255.0
            a = 1.0
        } else if clean.count == 8 {
            r = CGFloat((rgb >> 24) & 0xFF) / 255.0
            g = CGFloat((rgb >> 16) & 0xFF) / 255.0
            b = CGFloat((rgb >> 8) & 0xFF) / 255.0
            a = CGFloat(rgb & 0xFF) / 255.0
        } else {
            r = 1.0; g = 1.0; b = 1.0; a = 1.0
        }

        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
