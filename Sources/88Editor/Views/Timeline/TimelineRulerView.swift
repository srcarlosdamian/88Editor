import SwiftUI
import AppKit

/// Control nativo AppKit NSView para el arrastre y clic inmediato en la regla temporal.
/// Garantiza respuesta instantánea al ratón en macOS sin interferencias de scrollviews o capas superpuestas.
final class NativeTimelineRulerScrubber: NSView {
    var onSeek: ((Double) -> Void)?
    var zoom: Double = 60.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        handleSeek(event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        handleSeek(event: event)
    }

    private func handleSeek(event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let safeZoom = max(1.0, zoom)
        let clickedTime = max(0.0, Double(loc.x) / safeZoom)
        onSeek?(clickedTime)
    }
}

struct NativeRulerScrubberRepresentable: NSViewRepresentable {
    let zoom: Double
    let onSeek: (Double) -> Void

    func makeNSView(context: Context) -> NativeTimelineRulerScrubber {
        let view = NativeTimelineRulerScrubber()
        view.zoom = zoom
        view.onSeek = onSeek
        return view
    }

    func updateNSView(_ nsView: NativeTimelineRulerScrubber, context: Context) {
        nsView.zoom = zoom
        nsView.onSeek = onSeek
    }
}

/// Regla temporal interactiva graduada en segundos con marcas de tiempo,
/// soporte de Área de Trabajo / Rango de Renderizado (Puntos In y Out) arrastrables y atajos de teclado (I / O / ⌥X).
public struct TimelineRulerView: View {
    let duration: Double
    let zoom: Double // píxeles por segundo
    let workAreaIn: Double?
    let workAreaOut: Double?
    let onSeek: (Double) -> Void
    var onSetWorkAreaIn: ((Double) -> Void)? = nil
    var onSetWorkAreaOut: ((Double) -> Void)? = nil
    var onShiftWorkArea: ((Double) -> Void)? = nil
    var onResetWorkArea: (() -> Void)? = nil

    @State private var dragInitialIn: Double? = nil
    @State private var dragInitialOut: Double? = nil

    public init(
        duration: Double,
        zoom: Double,
        workAreaIn: Double? = nil,
        workAreaOut: Double? = nil,
        onSeek: @escaping (Double) -> Void,
        onSetWorkAreaIn: ((Double) -> Void)? = nil,
        onSetWorkAreaOut: ((Double) -> Void)? = nil,
        onShiftWorkArea: ((Double) -> Void)? = nil,
        onResetWorkArea: (() -> Void)? = nil
    ) {
        self.duration = duration
        self.zoom = zoom
        self.workAreaIn = workAreaIn
        self.workAreaOut = workAreaOut
        self.onSeek = onSeek
        self.onSetWorkAreaIn = onSetWorkAreaIn
        self.onSetWorkAreaOut = onSetWorkAreaOut
        self.onShiftWorkArea = onShiftWorkArea
        self.onResetWorkArea = onResetWorkArea
    }

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = max(geo.size.width, CGFloat(duration) * CGFloat(zoom))
            let totalSeconds = Int(ceil(Double(totalWidth) / zoom))

            // Rango de renderizado / In & Out
            let effIn = max(0.0, workAreaIn ?? 0.0)
            let effOut = max(effIn + 0.1, min(duration, workAreaOut ?? duration))
            let inX = CGFloat(effIn) * CGFloat(zoom)
            let outX = CGFloat(effOut) * CGFloat(zoom)
            let barWidth = max(4, outX - inX)

            ZStack(alignment: .bottomLeading) {
                // 1. Fondo base de la regla
                Color(NSColor.controlBackgroundColor)

                // 2. Marcas de tiempo y números
                ForEach(0...totalSeconds, id: \.self) { second in
                    let xPos = CGFloat(second) * CGFloat(zoom)

                    VStack(alignment: .leading, spacing: 2) {
                        if second % 5 == 0 {
                            Text(formatRulerTime(second: second))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .offset(x: 3, y: 1)

                            Rectangle()
                                .fill(Color.secondary.opacity(0.5))
                                .frame(width: 1, height: 10)
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 1, height: 6)
                        }
                    }
                    .position(x: xPos, y: 12)
                    .allowsHitTesting(false)
                }

                // 3. Franja visual del Área de Trabajo (In / Out) decorativa (no intercepta clics)
                if outX > inX {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: barWidth, height: 26)

                        // Barra superior horizontal que une los corchetes
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: barWidth, height: 3.0)
                    }
                    .position(x: inX + barWidth / 2, y: 13)
                    .allowsHitTesting(false)
                }

                // 4. Capturador nativo de clics y arrastre en la regla (100% confiable y fluido)
                NativeRulerScrubberRepresentable(zoom: zoom, onSeek: onSeek)
                    .frame(width: totalWidth, height: 26)

                // 5. Extremo Izquierdo: Corchete de Entrada (Punto In `[`)
                WorkAreaBracketShape(isLeft: true)
                    .fill(Color.white)
                    .frame(width: 12, height: 22)
                    .position(x: inX + 6, y: 13)
                    .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .contentShape(Rectangle())
                    .help("Extremo In: Arrastrar para ajustar punto de entrada")
                    .zIndex(20)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                let newTime = max(0, min(effOut - 0.1, Double(val.location.x) / zoom))
                                onSetWorkAreaIn?(newTime)
                            }
                    )

                // 6. Extremo Derecho: Corchete de Salida (Punto Out `]`)
                WorkAreaBracketShape(isLeft: false)
                    .fill(Color.white)
                    .frame(width: 12, height: 22)
                    .position(x: outX - 6, y: 13)
                    .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                    .contentShape(Rectangle())
                    .help("Extremo Out: Arrastrar para ajustar punto de salida")
                    .zIndex(20)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                let newTime = max(effIn + 0.1, min(duration, Double(val.location.x) / zoom))
                                onSetWorkAreaOut?(newTime)
                            }
                    )

                // Línea inferior divisoria
                Rectangle()
                    .fill(DesignSystem.border)
                    .frame(height: 1)
                    .allowsHitTesting(false)
            }
            .frame(width: totalWidth, height: 26)
            .contextMenu {
                Button {
                    onSetWorkAreaIn?(effIn)
                } label: {
                    Label("Fijar Punto de Entrada aquí (I)", systemImage: "arrow.right.to.line")
                }

                Button {
                    onSetWorkAreaOut?(effOut)
                } label: {
                    Label("Fijar Punto de Salida aquí (O)", systemImage: "arrow.left.to.line")
                }

                Divider()

                Button {
                    onResetWorkArea?()
                } label: {
                    Label("Abarcar Duración Completa (⌥X)", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .frame(height: 26)
    }

    private func formatRulerTime(second: Int) -> String {
        let m = second / 60
        let s = second % 60
        return String(format: "%02d:%02d", m, s)
    }
}

/// Forma de corchete para los puntos In y Out del Área de Trabajo
struct WorkAreaBracketShape: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isLeft {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 2.5))
            path.addLine(to: CGPoint(x: rect.minX + 2.5, y: rect.maxY - 2.5))
            path.addLine(to: CGPoint(x: rect.minX + 2.5, y: rect.minY + 2.5))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 2.5))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 2.5))
            path.addLine(to: CGPoint(x: rect.maxX - 2.5, y: rect.maxY - 2.5))
            path.addLine(to: CGPoint(x: rect.maxX - 2.5, y: rect.minY + 2.5))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 2.5))
        }
        path.closeSubpath()
        return path
    }
}
