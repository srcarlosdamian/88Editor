import Foundation
import CoreMedia

/// Utilidad para cálculo y formato de código de tiempo (Timecode)
/// Compatible con framerates estándar (24, 30, 60 fps).
public struct Timecode: Equatable, Hashable {
    public let hours: Int
    public let minutes: Int
    public let seconds: Int
    public let frames: Int
    public let framerate: Int

    public init(seconds totalSeconds: Double, framerate: Int = 30) {
        self.framerate = max(1, framerate)
        let clamped = max(0, totalSeconds)
        let totalFrames = Int(clamped * Double(framerate))
        
        self.frames = totalFrames % framerate
        let totalWholeSeconds = totalFrames / framerate
        self.seconds = totalWholeSeconds % 60
        let totalMinutes = totalWholeSeconds / 60
        self.minutes = totalMinutes % 60
        self.hours = totalMinutes / 60
    }

    public init(hours: Int, minutes: Int, seconds: Int, frames: Int, framerate: Int = 30) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.frames = frames
        self.framerate = framerate
    }

    /// Formato estándar SMPTE: 00:00:00:00
    public var stringValue: String {
        String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    /// Formato corto de minutos y segundos: 00:00.00
    public var shortStringValue: String {
        String(format: "%02d:%02d.%02d", minutes, seconds, frames)
    }

    /// Convierte el timecode a segundos con precisión de coma flotante
    public var totalSeconds: Double {
        let totalSec = Double(hours * 3600 + minutes * 60 + seconds)
        let frameFraction = Double(frames) / Double(framerate)
        return totalSec + frameFraction
    }

    /// Convierte a CMTime para uso directo en AVFoundation
    public var cmTime: CMTime {
        CMTime(seconds: totalSeconds, preferredTimescale: CMTimeScale(framerate * 100))
    }
}
