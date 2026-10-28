import Foundation
import AVFoundation
import CoreMedia

/// Constructor de composición para AVFoundation en 88 Editor.
/// Genera AVMutableComposition, AVMutableVideoComposition y AVMutableAudioMix
/// garantizando reproducción y exportación perfecta de Videos, Imágenes, Textos y Formas Vectoriales
/// con animaciones de Keyframes en todas las pistas.
public final class CompositionBuilder {

    public struct CompositionResult {
        public let composition: AVMutableComposition
        public let videoComposition: AVVideoComposition?
        public let audioMix: AVMutableAudioMix?
        public let totalDuration: CMTime
    }

    /// Construye una composición completa de AVFoundation con video, imágenes, animaciones y audio entrelazados.
    public static func build(
        tracks: [TimelineTrack],
        assets: [UUID: MediaAsset],
        configuration: ProjectConfiguration? = nil
    ) async -> CompositionResult {
        let composition = AVMutableComposition()
        var audioMixParameters: [AVMutableAudioMixInputParameters] = []

        var trackToCompID: [UUID: CMPersistentTrackID] = [:]
        var requiredTrackIDs: [NSValue] = []

        // 1. Calcular duración total real del proyecto
        let maxClipEnd = tracks.flatMap { $0.clips }.map { $0.endTime }.max() ?? 0.0
        let totalDurationSeconds = max(maxClipEnd, 1.0)
        let totalDurationCMTime = CMTime(seconds: totalDurationSeconds, preferredTimescale: 600)

        // 2. Insertar Pista Base Maestra de Video (Garantiza reloj continuo para exportar fotos/texto/audio)
        if let blankTrack = try? await BlankVideoTrackGenerator.getOrCreateBlankVideoTrack(),
           let compMasterTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            let loopCount = Int(ceil(totalDurationSeconds))
            for i in 0..<loopCount {
                let insertAt = CMTime(seconds: Double(i), preferredTimescale: 600)
                let remaining = totalDurationSeconds - Double(i)
                let dur = min(1.0, remaining)
                let range = CMTimeRange(start: .zero, duration: CMTime(seconds: dur, preferredTimescale: 600))
                try? compMasterTrack.insertTimeRange(range, of: blankTrack, at: insertAt)
            }
        }

        // 3. Procesar pistas de usuario (Videos, Imágenes, Textos y Audio)
        for track in tracks {
            guard !track.isHidden else { continue }

            if track.kind == .video {
                // Verificar si esta pista contiene clips de video reales que requieran decodificación hardware
                let hasVideoClips = track.clips.contains { clip in
                    if let asset = assets[clip.assetId], asset.mediaType == .video {
                        return true
                    }
                    return false
                }

                var compVideoTrack: AVMutableCompositionTrack?
                if hasVideoClips {
                    compVideoTrack = composition.addMutableTrack(
                        withMediaType: .video,
                        preferredTrackID: kCMPersistentTrackID_Invalid
                    )
                    if let cvt = compVideoTrack {
                        trackToCompID[track.id] = cvt.trackID
                        requiredTrackIDs.append(NSNumber(value: cvt.trackID) as NSValue)
                    }
                }

                // Pista de Audio complementaria para el sonido propio de los videos en esta pista
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

                    // A) Si es video: insertar en la pista de video para decodificación de fotogramas
                    if assetMeta.mediaType == .video, let compTrack = compVideoTrack {
                        if let sourceVideoTrack = try? await avAsset.loadTracks(withMediaType: .video).first {
                            try? compTrack.insertTimeRange(sourceTimeRange, of: sourceVideoTrack, at: clipStartTime)
                        }
                    }

                    // B) Audio integrado del archivo de video
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

        // 4. Construir VideoComposition con el Compositor Multicapa Profesional (EditorVideoCompositor)
        let config = configuration ?? ProjectConfiguration(preset: .fullHD16x9, customWidth: 1920, customHeight: 1080, framerate: .fps30)
        let targetW = CGFloat(config.width)
        let targetH = CGFloat(config.height)

        let mutableVideoComp = AVMutableVideoComposition()
        mutableVideoComp.customVideoCompositorClass = EditorVideoCompositor.self
        mutableVideoComp.renderSize = CGSize(width: targetW, height: targetH)
        mutableVideoComp.frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.framerate.rawValue))

        let instruction = EditorVideoCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: totalDurationCMTime),
            tracks: tracks,
            assets: assets,
            trackToCompID: trackToCompID,
            configuration: config,
            requiredSourceTrackIDs: requiredTrackIDs.isEmpty ? nil : requiredTrackIDs
        )
        mutableVideoComp.instructions = [instruction]

        return CompositionResult(
            composition: composition,
            videoComposition: mutableVideoComp,
            audioMix: audioMix,
            totalDuration: totalDurationCMTime
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
