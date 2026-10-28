import Foundation
import AVFoundation
import CoreMedia

/// Constructor de composición para AVFoundation en 88 Editor.
/// Genera AVMutableComposition, AVMutableVideoComposition y AVMutableAudioMix
/// garantizando reproducción de video fluido y audio sincronizado tanto en pistas de video como de audio.
public final class CompositionBuilder {

    public struct CompositionResult {
        public let composition: AVMutableComposition
        public let videoComposition: AVVideoComposition?
        public let audioMix: AVMutableAudioMix?
        public let totalDuration: CMTime
    }

    /// Construye una composición completa de AVFoundation con video y audio entrelazados.
    public static func build(
        tracks: [TimelineTrack],
        assets: [UUID: MediaAsset],
        configuration: ProjectConfiguration? = nil
    ) async -> CompositionResult {
        let composition = AVMutableComposition()
        var audioMixParameters: [AVMutableAudioMixInputParameters] = []

        // Filtramos pistas visibles
        for track in tracks {
            guard !track.isHidden else { continue }

            if track.kind == .video {
                // 1. Pista de Video en la composición
                guard let compVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else { continue }

                // 2. Pista de Audio complementaria para el sonido propio de los videos
                let compAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )

                var videoAudioParams: AVMutableAudioMixInputParameters?
                if let audioTrack = compAudioTrack {
                    videoAudioParams = AVMutableAudioMixInputParameters(track: audioTrack)
                    if track.isMuted {
                        videoAudioParams?.setVolume(0.0, at: .zero)
                    }
                }

                // Ordenamos clips secuencialmente por tiempo de inicio
                let sortedClips = track.clips.sorted { $0.startTime < $1.startTime }

                for clip in sortedClips {
                    guard let assetMeta = assets[clip.assetId] else { continue }
                    let avAsset = AVURLAsset(url: assetMeta.fileURL)

                    let clipStartTime = CMTime(seconds: clip.startTime, preferredTimescale: 600)
                    let sourceInTime = CMTime(seconds: clip.sourceIn, preferredTimescale: 600)
                    let clipDuration = CMTime(seconds: clip.duration, preferredTimescale: 600)
                    let sourceTimeRange = CMTimeRange(start: sourceInTime, duration: clipDuration)

                    // A) Insertar canal de Video
                    if let sourceVideoTrack = try? await avAsset.loadTracks(withMediaType: .video).first {
                        do {
                            try compVideoTrack.insertTimeRange(sourceTimeRange, of: sourceVideoTrack, at: clipStartTime)
                        } catch {
                            print("[88 Editor] Error insertando pista de video: \(error.localizedDescription)")
                        }
                    }

                    // B) Insertar canal de Audio integrado del video (si el archivo tiene sonido)
                    if let audioTrack = compAudioTrack,
                       let sourceAudioTrack = try? await avAsset.loadTracks(withMediaType: .audio).first {
                        do {
                            try audioTrack.insertTimeRange(sourceTimeRange, of: sourceAudioTrack, at: clipStartTime)
                            if let params = videoAudioParams {
                                applyVolumeKeyframes(
                                    clip: clip,
                                    isTrackMuted: track.isMuted,
                                    clipStartTime: clipStartTime,
                                    clipDuration: clipDuration,
                                    params: params
                                )
                            }
                        } catch {
                            print("[88 Editor] Error insertando audio de video: \(error.localizedDescription)")
                        }
                    }
                }

                if let params = videoAudioParams {
                    audioMixParameters.append(params)
                }

            } else {
                // Pista de Audio dedicada (A1, A2, etc.)
                guard let compAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else { continue }

                let audioInputParams = AVMutableAudioMixInputParameters(track: compAudioTrack)
                if track.isMuted {
                    audioInputParams.setVolume(0.0, at: .zero)
                }

                let sortedClips = track.clips.sorted { $0.startTime < $1.startTime }

                for clip in sortedClips {
                    guard let assetMeta = assets[clip.assetId] else { continue }
                    let avAsset = AVURLAsset(url: assetMeta.fileURL)

                    guard let sourceAudioTrack = try? await avAsset.loadTracks(withMediaType: .audio).first else {
                        continue
                    }

                    let clipStartTime = CMTime(seconds: clip.startTime, preferredTimescale: 600)
                    let sourceInTime = CMTime(seconds: clip.sourceIn, preferredTimescale: 600)
                    let clipDuration = CMTime(seconds: clip.duration, preferredTimescale: 600)
                    let sourceTimeRange = CMTimeRange(start: sourceInTime, duration: clipDuration)

                    do {
                        try compAudioTrack.insertTimeRange(sourceTimeRange, of: sourceAudioTrack, at: clipStartTime)
                        applyVolumeKeyframes(
                            clip: clip,
                            isTrackMuted: track.isMuted,
                            clipStartTime: clipStartTime,
                            clipDuration: clipDuration,
                            params: audioInputParams
                        )
                    } catch {
                        print("[88 Editor] Error insertando pista de audio dedicada: \(error.localizedDescription)")
                    }
                }

                audioMixParameters.append(audioInputParams)
            }
        }

        var audioMix: AVMutableAudioMix?
        if !audioMixParameters.isEmpty {
            let mix = AVMutableAudioMix()
            mix.inputParameters = audioMixParameters
            audioMix = mix
        }

        // Construir VideoComposition si hay pistas de video presentes
        var videoComposition: AVVideoComposition?
        let videoTracks = composition.tracks(withMediaType: .video)
        if !videoTracks.isEmpty {
            let mutableVideoComp = AVMutableVideoComposition(propertiesOf: composition)
            if let config = configuration {
                mutableVideoComp.renderSize = CGSize(width: config.width, height: config.height)
                mutableVideoComp.frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.framerate.rawValue))
            }
            videoComposition = mutableVideoComp
        }

        let duration = composition.duration
        return CompositionResult(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
            totalDuration: duration
        )
    }

    /// Aplica transiciones y rampas graduales de volumen basadas en fotogramas clave (Keyframes)
    private static func applyVolumeKeyframes(
        clip: TimelineClip,
        isTrackMuted: Bool,
        clipStartTime: CMTime,
        clipDuration: CMTime,
        params: AVMutableAudioMixInputParameters
    ) {
        if isTrackMuted || clip.isMuted {
            params.setVolume(0.0, at: clipStartTime)
            return
        }

        let baseVolume = Float(clip.volume)

        if clip.volumeKeyframes.isEmpty {
            params.setVolume(baseVolume, at: clipStartTime)
            return
        }

        let sortedKeyframes = clip.volumeKeyframes.sorted { $0.seconds < $1.seconds }

        // Si el primer keyframe está después del inicio del clip:
        if let first = sortedKeyframes.first {
            if first.seconds > 0.01 {
                let firstTime = CMTime(seconds: clip.startTime + first.seconds, preferredTimescale: 600)
                let range = CMTimeRange(start: clipStartTime, end: firstTime)
                params.setVolumeRamp(fromStartVolume: baseVolume, toEndVolume: Float(first.value), timeRange: range)
            } else {
                params.setVolume(Float(first.value), at: clipStartTime)
            }
        }

        // Interpolaciones intermedias entre pares de fotogramas clave
        for i in 0..<(sortedKeyframes.count - 1) {
            let k1 = sortedKeyframes[i]
            let k2 = sortedKeyframes[i + 1]

            let t1 = CMTime(seconds: clip.startTime + k1.seconds, preferredTimescale: 600)
            let t2 = CMTime(seconds: clip.startTime + k2.seconds, preferredTimescale: 600)

            if t2 > t1 {
                let range = CMTimeRange(start: t1, end: t2)
                params.setVolumeRamp(fromStartVolume: Float(k1.value), toEndVolume: Float(k2.value), timeRange: range)
            }
        }

        // Después del último keyframe mantener su valor hasta el final del clip
        if let last = sortedKeyframes.last {
            let lastTime = CMTime(seconds: clip.startTime + last.seconds, preferredTimescale: 600)
            let clipEndTime = CMTimeAdd(clipStartTime, clipDuration)
            if clipEndTime > lastTime {
                let range = CMTimeRange(start: lastTime, end: clipEndTime)
                params.setVolumeRamp(fromStartVolume: Float(last.value), toEndVolume: Float(last.value), timeRange: range)
            }
        }
    }
}
