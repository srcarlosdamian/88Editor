import Foundation
import CoreGraphics
import CoreMedia

/// Propiedades animables mediante fotogramas clave (Keyframes)
public enum AnimatableProperty: String, CaseIterable, Identifiable {
    case opacity = "Opacidad"
    case volume = "Volumen"
    case scale = "Escala"
    case rotation = "Rotación"

    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

/// Un clip situado en la línea de tiempo multicapa independiente.
/// Soporta pistas de animación por fotogramas clave (Keyframes) para Opacidad, Volumen, Escala y Rotación.
public struct TimelineClip: Identifiable, Codable, Equatable {
    public var id: UUID
    public var assetId: UUID
    public var trackId: UUID
    public var name: String

    // Posicionamiento temporal (en segundos de la línea de tiempo)
    public var startTime: Double
    public var duration: Double

    // Recorte en el archivo original (puntos In / Out en segundos de origen)
    public var sourceIn: Double
    public var sourceOut: Double

    // Transformación espacial básica (Valores base)
    public var positionX: Double
    public var positionY: Double
    public var scale: Double
    public var rotation: Double // Grados (-180° a +180°)

    // Composición y audio (Valores base)
    public var opacity: Double // 0.0 a 1.0
    public var volume: Double  // 0.0 a 1.0
    public var isMuted: Bool

    // Pistas de Fotogramas Clave (Keyframes)
    public var opacityKeyframes: [Keyframe]
    public var volumeKeyframes: [Keyframe]
    public var scaleKeyframes: [Keyframe]
    public var rotationKeyframes: [Keyframe]

    // Propiedades tipográficas opcionales (títulos / texto)
    public var textOverlay: String?
    public var fontName: String?
    public var fontSize: Double?
    public var textColorHex: String?

    // Propiedades de formas vectoriales (círculo, rectángulo, estrella, triángulo)
    public var shapeType: String?
    public var fillColorHex: String?
    public var strokeColorHex: String?
    public var strokeWidth: Double?

    // Recorte espacial (Crop en porcentajes: 0.0 a 0.5)
    public var cropLeft: Double
    public var cropRight: Double
    public var cropTop: Double
    public var cropBottom: Double

    public var hasCrop: Bool {
        cropLeft > 0.001 || cropRight > 0.001 || cropTop > 0.001 || cropBottom > 0.001
    }

    public init(
        id: UUID = UUID(),
        assetId: UUID,
        trackId: UUID,
        name: String,
        startTime: Double,
        duration: Double,
        sourceIn: Double = 0.0,
        sourceOut: Double? = nil,
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        opacity: Double = 1.0,
        volume: Double = 1.0,
        isMuted: Bool = false,
        opacityKeyframes: [Keyframe] = [],
        volumeKeyframes: [Keyframe] = [],
        scaleKeyframes: [Keyframe] = [],
        rotationKeyframes: [Keyframe] = [],
        textOverlay: String? = nil,
        fontName: String? = nil,
        fontSize: Double? = nil,
        textColorHex: String? = nil,
        shapeType: String? = nil,
        fillColorHex: String? = nil,
        strokeColorHex: String? = nil,
        strokeWidth: Double? = nil,
        cropLeft: Double = 0.0,
        cropRight: Double = 0.0,
        cropTop: Double = 0.0,
        cropBottom: Double = 0.0
    ) {
        self.id = id
        self.assetId = assetId
        self.trackId = trackId
        self.name = name
        self.startTime = max(0, startTime)
        self.duration = max(0.1, duration)
        self.sourceIn = max(0, sourceIn)
        self.sourceOut = sourceOut ?? (self.sourceIn + self.duration)
        self.positionX = positionX
        self.positionY = positionY
        self.scale = max(0.1, min(scale, 5.0))
        self.rotation = rotation
        self.opacity = max(0.0, min(1.0, opacity))
        self.volume = max(0.0, min(1.0, volume))
        self.isMuted = isMuted
        self.opacityKeyframes = opacityKeyframes
        self.volumeKeyframes = volumeKeyframes
        self.scaleKeyframes = scaleKeyframes
        self.rotationKeyframes = rotationKeyframes
        self.textOverlay = textOverlay
        self.fontName = fontName
        self.fontSize = fontSize
        self.textColorHex = textColorHex ?? "#FFFFFF"
        self.shapeType = shapeType
        self.fillColorHex = fillColorHex ?? "#FF3B30"
        self.strokeColorHex = strokeColorHex
        self.strokeWidth = strokeWidth ?? 0.0
        self.cropLeft = max(0.0, min(0.48, cropLeft))
        self.cropRight = max(0.0, min(0.48, cropRight))
        self.cropTop = max(0.0, min(0.48, cropTop))
        self.cropBottom = max(0.0, min(0.48, cropBottom))
    }

    /// Punto final en la línea de tiempo
    public var endTime: Double {
        startTime + duration
    }

    // MARK: - Consulta de Valores Interpolados
    /// Retorna la opacidad interpolada en el tiempo absoluto de la línea de tiempo
    public func opacity(at timelineTime: Double) -> Double {
        let relativeTime = timelineTime - startTime
        return opacityKeyframes.interpolatedValue(at: relativeTime, defaultValue: opacity)
    }

    /// Retorna el volumen interpolado en el tiempo absoluto de la línea de tiempo
    public func volume(at timelineTime: Double) -> Double {
        guard !isMuted else { return 0.0 }
        let relativeTime = timelineTime - startTime
        return volumeKeyframes.interpolatedValue(at: relativeTime, defaultValue: volume)
    }

    /// Retorna la escala interpolada en el tiempo absoluto de la línea de tiempo
    public func scale(at timelineTime: Double) -> Double {
        let relativeTime = timelineTime - startTime
        return scaleKeyframes.interpolatedValue(at: relativeTime, defaultValue: scale)
    }

    /// Retorna la rotación interpolada en el tiempo absoluto de la línea de tiempo
    public func rotation(at timelineTime: Double) -> Double {
        let relativeTime = timelineTime - startTime
        return rotationKeyframes.interpolatedValue(at: relativeTime, defaultValue: rotation)
    }

    // MARK: - Gestión de Keyframes
    /// Comprueba si existe un keyframe dentro de una tolerancia temporal
    public func hasKeyframe(for property: AnimatableProperty, at relativeTime: Double, tolerance: Double = 0.08) -> Bool {
        switch property {
        case .opacity:
            return opacityKeyframes.contains { abs($0.seconds - relativeTime) < tolerance }
        case .volume:
            return volumeKeyframes.contains { abs($0.seconds - relativeTime) < tolerance }
        case .scale:
            return scaleKeyframes.contains { abs($0.seconds - relativeTime) < tolerance }
        case .rotation:
            return rotationKeyframes.contains { abs($0.seconds - relativeTime) < tolerance }
        }
    }

    /// Alterna un keyframe: si existe lo elimina; si no existe, lo agrega con el valor indicado
    public mutating func toggleKeyframe(for property: AnimatableProperty, at relativeTime: Double, currentValue: Double) {
        let clampedTime = max(0, min(relativeTime, duration))
        if hasKeyframe(for: property, at: clampedTime) {
            removeKeyframe(for: property, at: clampedTime)
        } else {
            setKeyframe(for: property, at: clampedTime, value: currentValue)
        }
    }

    /// Agrega o actualiza un keyframe
    public mutating func setKeyframe(for property: AnimatableProperty, at relativeTime: Double, value: Double) {
        let clampedTime = max(0, min(relativeTime, duration))
        switch property {
        case .opacity:
            upsertKeyframe(in: &opacityKeyframes, at: clampedTime, value: value)
        case .volume:
            upsertKeyframe(in: &volumeKeyframes, at: clampedTime, value: value)
        case .scale:
            upsertKeyframe(in: &scaleKeyframes, at: clampedTime, value: value)
        case .rotation:
            upsertKeyframe(in: &rotationKeyframes, at: clampedTime, value: value)
        }
    }

    /// Elimina el keyframe más cercano
    public mutating func removeKeyframe(for property: AnimatableProperty, at relativeTime: Double, tolerance: Double = 0.08) {
        switch property {
        case .opacity:
            opacityKeyframes.removeAll { abs($0.seconds - relativeTime) < tolerance }
        case .volume:
            volumeKeyframes.removeAll { abs($0.seconds - relativeTime) < tolerance }
        case .scale:
            scaleKeyframes.removeAll { abs($0.seconds - relativeTime) < tolerance }
        case .rotation:
            rotationKeyframes.removeAll { abs($0.seconds - relativeTime) < tolerance }
        }
    }

    private func upsertKeyframe(in list: inout [Keyframe], at time: Double, value: Double, tolerance: Double = 0.08) {
        if let idx = list.firstIndex(where: { abs($0.seconds - time) < tolerance }) {
            list[idx].value = value
        } else {
            let kf = Keyframe(seconds: time, value: value)
            list.append(kf)
            list.sort { $0.seconds < $1.seconds }
        }
    }

    /// Todos los keyframes de cualquier propiedad ordenados para dibujarlos en el Timeline
    public var allKeyframeTimes: [Double] {
        var times = Set<Double>()
        for k in opacityKeyframes { times.insert(k.seconds) }
        for k in volumeKeyframes { times.insert(k.seconds) }
        for k in scaleKeyframes { times.insert(k.seconds) }
        for k in rotationKeyframes { times.insert(k.seconds) }
        return times.sorted()
    }

    /// Divide el clip en dos partes independientes en el tiempo especificado (Cmd + B)
    public func split(at timelineTime: Double) -> (TimelineClip, TimelineClip)? {
        guard timelineTime > startTime + 0.05 && timelineTime < endTime - 0.05 else {
            return nil
        }

        let firstDuration = timelineTime - startTime
        let secondDuration = duration - firstDuration

        // Primera mitad
        var firstClip = self
        firstClip.duration = firstDuration
        firstClip.sourceOut = firstClip.sourceIn + firstDuration
        firstClip.opacityKeyframes = opacityKeyframes.filter { $0.seconds <= firstDuration }
        firstClip.volumeKeyframes = volumeKeyframes.filter { $0.seconds <= firstDuration }
        firstClip.scaleKeyframes = scaleKeyframes.filter { $0.seconds <= firstDuration }
        firstClip.rotationKeyframes = rotationKeyframes.filter { $0.seconds <= firstDuration }

        // Segunda mitad
        let secondClip = TimelineClip(
            id: UUID(),
            assetId: self.assetId,
            trackId: self.trackId,
            name: "\(self.name) (Copia)",
            startTime: timelineTime,
            duration: secondDuration,
            sourceIn: self.sourceIn + firstDuration,
            sourceOut: self.sourceOut,
            positionX: self.positionX,
            positionY: self.positionY,
            scale: self.scale,
            rotation: self.rotation,
            opacity: self.opacity,
            volume: self.volume,
            isMuted: self.isMuted,
            opacityKeyframes: opacityKeyframes.filter { $0.seconds > firstDuration }.map { Keyframe(seconds: $0.seconds - firstDuration, value: $0.value) },
            volumeKeyframes: volumeKeyframes.filter { $0.seconds > firstDuration }.map { Keyframe(seconds: $0.seconds - firstDuration, value: $0.value) },
            scaleKeyframes: scaleKeyframes.filter { $0.seconds > firstDuration }.map { Keyframe(seconds: $0.seconds - firstDuration, value: $0.value) },
            rotationKeyframes: rotationKeyframes.filter { $0.seconds > firstDuration }.map { Keyframe(seconds: $0.seconds - firstDuration, value: $0.value) },
            textOverlay: self.textOverlay,
            fontName: self.fontName,
            fontSize: self.fontSize,
            textColorHex: self.textColorHex,
            shapeType: self.shapeType,
            fillColorHex: self.fillColorHex,
            strokeColorHex: self.strokeColorHex,
            strokeWidth: self.strokeWidth,
            cropLeft: self.cropLeft,
            cropRight: self.cropRight,
            cropTop: self.cropTop,
            cropBottom: self.cropBottom
        )
        return (firstClip, secondClip)
    }

    /// Ajusta el recorte In
    public mutating func trimIn(deltaSeconds: Double, maxAssetDuration: Double) {
        let proposedIn = max(0, sourceIn + deltaSeconds)
        let maxAllowedIn = sourceOut - 0.1
        let newIn = min(proposedIn, maxAllowedIn)
        let actualDelta = newIn - sourceIn

        self.sourceIn = newIn
        self.startTime = max(0, self.startTime + actualDelta)
        self.duration = max(0.1, self.sourceOut - self.sourceIn)
    }

    /// Ajusta el recorte Out
    public mutating func trimOut(deltaSeconds: Double, maxAssetDuration: Double) {
        let proposedOut = sourceOut + deltaSeconds
        let minAllowedOut = sourceIn + 0.1
        let clampedOut = min(max(proposedOut, minAllowedOut), maxAssetDuration > 0 ? maxAssetDuration : Double.greatestFiniteMagnitude)
        
        self.sourceOut = clampedOut
        self.duration = max(0.1, self.sourceOut - self.sourceIn)
    }
}
