import SwiftUI

/// Barra de transporte y control de reproducción minimalista nativa de macOS
public struct TransportBar: View {
    @ObservedObject var playbackEngine: PlaybackEngine
    let framerate: Int

    public var body: some View {
        HStack(spacing: 16) {
            // Código de tiempo actual
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))

                let tc = Timecode(seconds: playbackEngine.currentTime, framerate: framerate)
                Text(tc.stringValue)
                    .font(DesignSystem.timecodeFont)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignSystem.border, lineWidth: 1)
            )

            Spacer()

            // Controles de transporte
            HStack(spacing: 8) {
                // Ir al inicio
                Button {
                    playbackEngine.seek(to: 0.0)
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Ir al inicio")

                // Cuadro anterior
                Button {
                    playbackEngine.stepFrameBackward(fps: framerate)
                } label: {
                    Image(systemName: "backward.frame.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Fotograma anterior")

                // Reproducir / Pausa principal (Barra espaciadora)
                Button {
                    playbackEngine.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 32, height: 32)

                        Image(systemName: playbackEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .help("Reproducir / Pausa (Barra espaciadora)")

                // Cuadro siguiente
                Button {
                    playbackEngine.stepFrameForward(fps: framerate)
                } label: {
                    Image(systemName: "forward.frame.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Fotograma siguiente")

                // Ir al final
                Button {
                    playbackEngine.seek(to: playbackEngine.totalDuration)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Ir al final")
            }

            Spacer()

            // Duración total
            HStack(spacing: 6) {
                Text("TOTAL")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                let totalTC = Timecode(seconds: playbackEngine.totalDuration, framerate: framerate)
                Text(totalTC.stringValue)
                    .font(DesignSystem.timecodeFont)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignSystem.border, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
