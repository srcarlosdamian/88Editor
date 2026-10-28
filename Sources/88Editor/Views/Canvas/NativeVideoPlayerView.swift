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
        view.playerLayer.videoGravity = .resizeAspect
        view.wantsLayer = true
        return view
    }

    public func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        if nsView.playerLayer.player != player {
            nsView.playerLayer.player = player
        }
        // Aplicar escala de proxy en caso de previsualización al 50%
        nsView.previewScale = previewScale
    }

    public static func dismantleNSView(_ nsView: PlayerContainerView, coordinator: ()) {
        nsView.playerLayer.player = nil
    }

    public final class PlayerContainerView: NSView {
        public let playerLayer = AVPlayerLayer()
        public var previewScale: CGFloat = 1.0 {
            didSet {
                needsLayout = true
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
            playerLayer.needsDisplayOnBoundsChange = true
            layer?.addSublayer(playerLayer)
        }

        public override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
