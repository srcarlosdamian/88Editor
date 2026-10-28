import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import AppKit
import CoreText
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
/// con orientación derecha vertical (upright), interpolación de Keyframes y recorte (Crop).
public final class EditorVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private static let cgImageCache = NSCache<NSURL, CGImage>()

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

        // 1. Fondo base neutro en coordenadas estándar CoreGraphics (y=0 abajo en memoria cartesiana)
        ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: targetW, height: targetH))

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

            // Posicionamiento centrado en el visor con offsets de usuario (interpolado con fotogramas clave)
            // En SwiftUI, positionY positivo baja. En CoreGraphics cartesiano, bajar es restar.
            let dynamicPosX = clip.positionX(at: currentTime)
            let dynamicPosY = clip.positionY(at: currentTime)
            let centerX = targetW / 2.0 + CGFloat(dynamicPosX)
            let centerY = targetH / 2.0 - CGFloat(dynamicPosY)

            ctx.saveGState()
            ctx.setAlpha(CGFloat(dynamicOpacity))

            // Aplicar transformaciones espaciales estándar CoreGraphics
            ctx.translateBy(x: centerX, y: centerY)
            // En SwiftUI los grados horarios son positivos. En trigonometría/CoreGraphics son negativos:
            ctx.rotate(by: -CGFloat(dynamicRotation) * .pi / 180.0)
            ctx.scaleBy(x: CGFloat(dynamicScale), y: CGFloat(dynamicScale))

            let localRect = CGRect(x: -elemW / 2.0, y: -elemH / 2.0, width: elemW, height: elemH)

            // Recorte espacial (Crop) en coordenadas cartesianas estándar
            if clip.hasCrop {
                let cropX = localRect.minX + elemW * CGFloat(clip.cropLeft)
                let cropW = elemW * max(0.001, 1.0 - CGFloat(clip.cropLeft) - CGFloat(clip.cropRight))
                let cropY = localRect.minY + elemH * CGFloat(clip.cropBottom)
                let cropH = elemH * max(0.001, 1.0 - CGFloat(clip.cropTop) - CGFloat(clip.cropBottom))
                ctx.clip(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH))
            }

            // Dibujar según el tipo de elemento
            if let shape = clip.shapeType {
                drawVectorShape(ctx: ctx, shape: shape, fillHex: clip.fillColorHex ?? "#FF3B30", in: localRect)
            } else if let text = clip.textOverlay, !text.isEmpty {
                drawTextOverlay(ctx: ctx, clip: clip, text: text, in: localRect)
            } else if let asset = instruction.assets[clip.assetId] {
                if asset.mediaType == .image {
                    if let img = Self.loadCGImage(from: asset.fileURL) {
                        ctx.draw(img, in: localRect)
                    }
                } else if asset.mediaType == .video {
                    if let compTrackID = instruction.trackToCompID[track.id],
                       let sourceBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: compTrackID) {
                        var videoCG: CGImage?
                        if VTCreateCGImageFromCVPixelBuffer(sourceBuffer, options: nil, imageOut: &videoCG) == 0, let vCG = videoCG {
                            ctx.draw(vCG, in: localRect)
                        }
                    }
                }
            }

            ctx.restoreGState()
        }

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
            let font = resolveCTFont(name: clip.fontName, size: fSize)
            let attrStr = CFAttributedStringCreate(
                nil,
                text as CFString,
                [kCTFontAttributeName: font] as CFDictionary
            )!
            let line = CTLineCreateWithAttributedString(attrStr)
            let bounds = CTLineGetBoundsWithOptions(line, [])
            let w = max(160, bounds.width + 40)
            let h = max(60, bounds.height + 24)
            return (min(targetW, w), h)
        }

        if let asset = assets[clip.assetId] {
            var w = asset.width
            var h = asset.height
            if w <= 0 || h <= 0 {
                if asset.mediaType == .image, let img = Self.loadCGImage(from: asset.fileURL) {
                    w = Double(img.width)
                    h = Double(img.height)
                }
            }
            if w > 0 && h > 0 {
                // Ajuste proporcional completo (Fit): el elemento cabe íntegro en el render sin cortarse nunca
                let scale = min(targetW / CGFloat(w), targetH / CGFloat(h))
                let elemW = (CGFloat(w) * scale).rounded()
                let elemH = (CGFloat(h) * scale).rounded()
                return (elemW, elemH)
            }
        }

        return (targetW, targetH)
    }

    // MARK: - Dibujo de Formas Vectoriales en CoreGraphics Estándar
    private func drawVectorShape(ctx: CGContext, shape: String, fillHex: String, in rect: CGRect) {
        let (r, g, b, a) = parseHexColor(fillHex)
        ctx.setFillColor(red: r, green: g, blue: b, alpha: a)

        switch shape.lowercased() {
        case "circle":
            ctx.fillEllipse(in: rect)
        case "star":
            let path = CGMutablePath()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outerRadius = min(rect.width, rect.height) / 2.0
            let innerRadius = outerRadius * 0.45
            let points = 5
            let angleStep = .pi / CGFloat(points)
            var currentAngle: CGFloat = .pi / 2.0 // Punta superior en cartesiano

            for i in 0..<(points * 2) {
                let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let x = center.x + radius * cos(currentAngle)
                let y = center.y + radius * sin(currentAngle)
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                currentAngle += angleStep
            }
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        case "triangle":
            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY)) // Vértice superior
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // Esquina inferior derecha
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)) // Esquina inferior izquierda
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        default:
            ctx.fill(rect)
        }
    }

    // MARK: - Dibujo de Textos con CoreText (Sin inversión vertical)
    private func drawTextOverlay(ctx: CGContext, clip: TimelineClip, text: String, in rect: CGRect) {
        let fSize = CGFloat(clip.fontSize ?? 54.0)
        let font = resolveCTFont(name: clip.fontName, size: fSize)
        let (r, g, b, a) = parseHexColor(clip.textColorHex ?? "#FFFFFF")
        let textColor = CGColor(srgbRed: r, green: g, blue: b, alpha: a)

        let attrStr = CFAttributedStringCreate(
            nil,
            text as CFString,
            [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: textColor
            ] as CFDictionary
        )!

        let line = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(line, [])

        // Centrar texto dentro del rectángulo
        let posX = rect.midX - bounds.width / 2.0
        let posY = rect.midY - bounds.height / 2.0

        ctx.textPosition = CGPoint(x: posX, y: posY)
        CTLineDraw(line, ctx)
    }

    private func resolveCTFont(name: String?, size: CGFloat) -> CTFont {
        if let name = name, !name.isEmpty {
            return CTFontCreateWithName(name as CFString, size, nil)
        }
        return CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }

    // MARK: - Caché y Carga de CGImage
    private static func loadCGImage(from url: URL) -> CGImage? {
        let nsURL = url as NSURL
        if let cached = cgImageCache.object(forKey: nsURL) {
            return cached
        }
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        cgImageCache.setObject(cgImage, forKey: nsURL)
        return cgImage
    }

    private func parseHexColor(_ hex: String) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        if clean.count == 6 {
            let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
            let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
            let b = CGFloat(rgb & 0xFF) / 255.0
            return (r, g, b, 1.0)
        } else if clean.count == 8 {
            let r = CGFloat((rgb >> 24) & 0xFF) / 255.0
            let g = CGFloat((rgb >> 16) & 0xFF) / 255.0
            let b = CGFloat((rgb >> 8) & 0xFF) / 255.0
            let a = CGFloat(rgb & 0xFF) / 255.0
            return (r, g, b, a)
        }
        return (1.0, 1.0, 1.0, 1.0)
    }
}
