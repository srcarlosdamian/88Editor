import SwiftUI

/// Regla temporal interactiva graduada en segundos y marcas de tiempo
public struct TimelineRulerView: View {
    let duration: Double
    let zoom: Double // píxeles por segundo
    let onSeek: (Double) -> Void

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = max(geo.size.width, CGFloat(duration) * CGFloat(zoom))
            let totalSeconds = Int(ceil(Double(totalWidth) / zoom))

            ZStack(alignment: .bottomLeading) {
                // Fondo de la regla
                Color(NSColor.controlBackgroundColor)

                // Marcas de tiempo y números
                ForEach(0...totalSeconds, id: \.self) { second in
                    let xPos = CGFloat(second) * CGFloat(zoom)

                    VStack(alignment: .leading, spacing: 2) {
                        if second % 5 == 0 {
                            // Marca mayor con texto
                            Text(formatRulerTime(second: second))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .offset(x: 3, y: 1)

                            Rectangle()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 1, height: 10)
                        } else {
                            // Marca menor
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 1, height: 6)
                        }
                    }
                    .position(x: xPos, y: 12)
                }

                // Línea inferior divisoria
                Rectangle()
                    .fill(DesignSystem.border)
                    .frame(height: 1)
            }
            .frame(width: totalWidth, height: 26)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clickedTime = max(0, Double(value.location.x) / zoom)
                        onSeek(clickedTime)
                    }
            )
        }
        .frame(height: 26)
    }

    private func formatRulerTime(second: Int) -> String {
        let m = second / 60
        let s = second % 60
        return String(format: "%02d:%02d", m, s)
    }
}
