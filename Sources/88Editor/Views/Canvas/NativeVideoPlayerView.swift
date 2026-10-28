import SwiftUI
import AVFoundation
import AppKit

/// Vista nativa NSView de macOS que aloja un AVPlayerLayer optimizado para Apple Silicon.
public struct NativeVideoPlayerView: NSViewRepresentable {
    public let player: AVPlayer
    public var previewScale: CGFloat

    public init(player: AVPlayer, previewScale: CGFloat = 1.0) {
        self.player = player
        self.previewScale = previewScale
    }

    public func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.wantsLayer = true
        return view
    }

    public func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        if nsView.playerLayer.player != player {
            nsView.playerLayer.player = player
        }
        if nsView.previewScale != previewScale {
            nsView.previewScale = previewScale
        }
    }

    public static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: ()) {
        nsView.playerLayer.player = nil
    }

    public final class PlayerContainerView: NSView {
        public let playerLayer = AVPlayerLayer()
        public var previewScale: CGFloat = 1.0 {
            didSet {
                if oldValue != previewScale {
                    needsLayout = true
                }
            }
        }

        public override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            setupLayer()
        }

        public required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupLayer()
        }

        private func setupLayer() {
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
            playerLayer.needsDisplayOnBoundsChange = false
            playerLayer.actions = [
                "bounds": NSNull(),
                "position": NSNull(),
                "transform": NSNull(),
                "contents": NSNull()
            ]
            playerLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(playerLayer)
        }

        public override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds.integral
            CATransaction.commit()
        }
    }
}

/// Vista que renderiza el video de un clip individual con su relación de aspecto original intacta,
/// respetando videos verticales (9:16), horizontales (16:9), cuadrados (1:1), etc.,
/// y manteniéndose sincronizado con el motor de reproducción.
public struct ClipVideoPlayerView: View {
    public let clip: TimelineClip
    public let asset: MediaAsset
    @ObservedObject public var viewModel: EditorViewModel

    public init(clip: TimelineClip, asset: MediaAsset, viewModel: EditorViewModel) {
        self.clip = clip
        self.asset = asset
        self.viewModel = viewModel
    }

    public var body: some View {
        let player = viewModel.player(for: clip, asset: asset)
        NativeVideoPlayerView(
            player: player,
            previewScale: viewModel.playbackEngine.previewScale.scaleFactor
        )
    }
}
