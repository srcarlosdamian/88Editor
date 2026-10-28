import Foundation
import CoreMedia

/// Tipo de interpolación entre fotogramas clave
public enum KeyframeInterpolation: String, Codable, CaseIterable {
    case linear = "Lineal"
}

/// Fotograma clave (Keyframe) para animación de propiedades en 88 Editor.
/// Almacena tiempo relativo al clip (CMTime/segundos), valor numérico e interpolación.
public struct Keyframe: Identifiable, Codable, Equatable {
    public let id: UUID
    public var seconds: Double
    public var value: Double
    public var interpolation: KeyframeInterpolation

    public init(
        id: UUID = UUID(),
        seconds: Double,
        value: Double,
        interpolation: KeyframeInterpolation = .linear
    ) {
        self.id = id
        self.seconds = max(0, seconds)
        self.value = value
        self.interpolation = interpolation
    }

    /// Posición en la línea de tiempo relativa al clip como CMTime
    public var time: CMTime {
        get {
            CMTime(seconds: seconds, preferredTimescale: 600)
        }
        set {
            let sec = CMTimeGetSeconds(newValue)
            self.seconds = sec.isFinite ? max(0, sec) : 0
        }
    }
}

// MARK: - Lógica de Interpolación Lineal
public extension Array where Element == Keyframe {
    /// Calcula el valor interpolado linealmente para un tiempo dado relativo al clip.
    /// - Si la lista está vacía, devuelve el valor base por defecto (`defaultValue`).
    /// - Si solo existe un keyframe o el tiempo está fuera de rango, mantiene el valor más próximo.
    /// - Entre dos keyframes, interpola linealmente el valor de forma continua.
    func interpolatedValue(at relativeTime: Double, defaultValue: Double) -> Double {
        guard !isEmpty else { return defaultValue }
        if count == 1 { return self[0].value }

        // Ordenamos por tiempo de menor a mayor
        let sorted = self.sorted { $0.seconds < $1.seconds }

        // Si el tiempo es menor o igual al primer keyframe, mantiene el primer valor
        guard let first = sorted.first, let last = sorted.last else { return defaultValue }

        if relativeTime <= first.seconds {
            return first.value
        }

        // Si el tiempo es mayor o igual al último keyframe, mantiene el último valor
        if relativeTime >= last.seconds {
            return last.value
        }

        // Búsqueda de los dos keyframes más cercanos
        for i in 0..<(sorted.count - 1) {
            let k1 = sorted[i]
            let k2 = sorted[i + 1]

            if relativeTime >= k1.seconds && relativeTime <= k2.seconds {
                let timeDelta = k2.seconds - k1.seconds
                guard timeDelta > 0.0001 else { return k1.value }

                let progress = (relativeTime - k1.seconds) / timeDelta
                // Interpolación lineal nativa: v = v1 + t * (v2 - v1)
                return k1.value + progress * (k2.value - k1.value)
            }
        }

        return last.value
    }
}
