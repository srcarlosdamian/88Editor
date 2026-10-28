import Foundation
import AVFoundation
import Combine
import CoreMedia

/// Escala de previsualización para balancear calidad y consumo de batería en MacBook Air
public enum PreviewScale: String, CaseIterable, Identifiable {
    case full = "100% (Calidad Completa)"
    case threeQuarter = "75% (Alta Calidad)"
    case half = "50% (Rendimiento / Apple Silicon M)"
    case quarter = "25% (Ahorro de Batería)"
    case eighth = "12.5% (Borrador Rápido)"

    public var id: String { rawValue }

    public var scaleFactor: CGFloat {
        switch self {
        case .full: return 1.0
        case .threeQuarter: return 0.75
        case .half: return 0.5
        case .quarter: return 0.25
        case .eighth: return 0.125
        }
    }
}

/// Motor de reproducción de alto rendimiento basado en AVPlayer.
/// Mantiene sincronía milimétrica con el playhead del lienzo y la línea de tiempo.
@MainActor
public final class PlaybackEngine: ObservableObject {
    public let player = AVPlayer()

    @Published public private(set) var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var totalDuration: Double = 10.0
    @Published public var previewScale: PreviewScale = .full
    @Published public private(set) var isScrubbing: Bool = false

    private var timeObserverToken: Any?
    private var itemDidEndObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingTimeInternally: Bool = false
    private var playbackDisplayTimer: Timer?

    public init() {
        configurePlayer()
        setupTimeObserver()
    }

    private func configurePlayer() {
        player.actionAtItemEnd = .pause
        // Optimización de buffers para Apple Silicon
        player.automaticallyWaitsToMinimizeStalling = true
    }

    /// Configura el observador periódico de tiempo para sincronizar el playhead a 30 o 60 fps
    private func setupTimeObserver() {
        let interval = CMTime(value: 1, timescale: 30) // ~33ms (fluido y eficiente)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, !self.isScrubbing else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite && !seconds.isNaN {
                    self.currentTime = max(0, seconds)
                    if self.currentTime >= self.totalDuration && self.isPlaying {
                        self.pause()
                    }
                }
            }
        }
    }

    /// Carga una nueva composición en el reproductor
    public func loadComposition(
        _ composition: AVComposition,
        videoComposition: AVVideoComposition? = nil,
        audioMix: AVAudioMix? = nil,
        duration: Double
    ) {
        let item = AVPlayerItem(asset: composition)
        if let videoComp = videoComposition {
            item.videoComposition = videoComp
        }
        item.audioMix = audioMix

        // Limpiar observador de fin anterior
        if let observer = itemDidEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        itemDidEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Solo pausar si verdaderamente se llegó al final de la duración total del proyecto
                if self.currentTime >= self.totalDuration - 0.15 {
                    self.pause()
                    self.seek(to: 0.0)
                }
            }
        }

        self.totalDuration = max(duration, 1.0)
        player.replaceCurrentItem(with: item)

        // Restaurar posición actual
        seek(to: currentTime)
    }

    /// Alterna entre reproducción y pausa (Barra espaciadora)
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        if currentTime >= totalDuration - 0.05 {
            seek(to: 0.0)
        }
        player.play()
        isPlaying = true
        startPlaybackTimer()
    }

    public func pause() {
        stopPlaybackTimer()
        player.pause()
        isPlaying = false
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying, !self.isScrubbing else { return }

                // Si AVPlayer está avanzando fluidamente (con video o audio):
                if self.player.rate > 0 {
                    let sec = CMTimeGetSeconds(self.player.currentTime())
                    if sec.isFinite && !sec.isNaN {
                        self.currentTime = max(0, sec)
                    }
                } else {
                    // Si AVPlayer se detuvo por falta de pista AV (sobre imágenes fijas o vacíos):
                    let nextTime = self.currentTime + (1.0 / 30.0)
                    if nextTime >= self.totalDuration {
                        self.pause()
                        self.seek(to: 0.0)
                    } else {
                        self.currentTime = nextTime
                        // Sincronizar AVPlayer
                        let targetCM = CMTime(seconds: nextTime, preferredTimescale: 600)
                        self.player.seek(to: targetCM, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                }
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackDisplayTimer?.invalidate()
        playbackDisplayTimer = nil
    }

    /// Desplazamiento preciso al tiempo indicado
    public func seek(to timeInSeconds: Double, precise: Bool = true) {
        let clampedTime = max(0, min(timeInSeconds, totalDuration))
        currentTime = clampedTime

        let targetCM = CMTime(seconds: clampedTime, preferredTimescale: 600)
        let tolerance: CMTime = precise ? .zero : CMTime(value: 1, timescale: 30)

        player.seek(to: targetCM, toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    /// Inicia arrastre manual del playhead (scrubbing)
    public func startScrubbing() {
        isScrubbing = true
        if isPlaying {
            pause()
        }
    }

    /// Finaliza arrastre manual del playhead
    public func endScrubbing() {
        isScrubbing = false
        seek(to: currentTime, precise: true)
    }

    /// Avanza un fotograma (frame step forward)
    public func stepFrameForward(fps: Int = 30) {
        pause()
        let step = 1.0 / Double(fps)
        seek(to: currentTime + step)
    }

    /// Retrocede un fotograma (frame step backward)
    public func stepFrameBackward(fps: Int = 30) {
        pause()
        let step = 1.0 / Double(fps)
        seek(to: currentTime - step)
    }

    /// Cambia la escala de previsualización (100% o 50% proxy)
    public func setPreviewScale(_ scale: PreviewScale) {
        self.previewScale = scale
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let observer = itemDidEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
