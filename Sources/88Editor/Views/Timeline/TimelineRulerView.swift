import SwiftUI

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
    var onResetWorkArea: (() -> Void)? = nil

    @State private var draggingHandle: WorkAreaHandle? = nil

    private enum WorkAreaHandle {
        case inPoint
        case outPoint
    }

    public init(
        duration: Double,
        zoom: Double,
        workAreaIn: Double? = nil,
        workAreaOut: Double? = nil,
        onSeek: @escaping (Double) -> Void,
        onSetWorkAreaIn: ((Double) -> Void)? = nil,
        onSetWorkAreaOut: ((Double) -> Void)? = nil,
        onResetWorkArea: (() -> Void)? = nil
    ) {
        self.duration = duration
        self.zoom = zoom
        self.workAreaIn = workAreaIn
        self.workAreaOut = workAreaOut
        self.onSeek = onSeek
        self.onSetWorkAreaIn = onSetWorkAreaIn
        self.onSetWorkAreaOut = onSetWorkAreaOut
        self.onResetWorkArea = onResetWorkArea
    }

    public var body: some View {
        GeometryReader { geo in
            let totalWidth = max(geo.size.width, CGFloat(duration) * CGFloat(zoom))
            let totalSeconds = Int(ceil(Double(totalWidth) / zoom))

            let effIn = max(0.0, workAreaIn ?? 0.0)
            let effOut = min(duration, workAreaOut ?? duration)
            let inX = CGFloat(effIn) * CGFloat(zoom)
            let outX = CGFloat(effOut) * CGFloat(zoom)
            let hasCustomArea = workAreaIn != nil || workAreaOut != nil

            ZStack(alignment: .bottomLeading) {
                // Fondo base de la regla
                Color(NSColor.controlBackgroundColor)

                // Resaltado de la franja del Área de Trabajo / Rango de Renderizado
                if hasCustomArea && outX > inX {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: max(2, outX - inX), height: 26)
                        .position(x: inX + (outX - inX) / 2, y: 13)

                    // Barra superior indicadora de rango de renderizado
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: max(2, outX - inX), height: 3)
                        .position(x: inX + (outX - inX) / 2, y: 1.5)
                }

                // Marcas de tiempo y números
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
                }

                // Tirador / Corchete Izquierdo (Punto In)
                if hasCustomArea {
                    WorkAreaBracketShape(isLeft: true)
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 16)
                        .position(x: inX + 4, y: 13)
                        .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newTime = max(0, Double(val.location.x) / zoom)
                                    onSetWorkAreaIn?(newTime)
                                }
                        )

                    // Tirador / Corchete Derecho (Punto Out)
                    WorkAreaBracketShape(isLeft: false)
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 16)
                        .position(x: outX - 4, y: 13)
                        .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    let newTime = max(effIn + 0.1, Double(val.location.x) / zoom)
                                    onSetWorkAreaOut?(newTime)
                                }
                        )
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
            .contextMenu {
                Button {
                    let clickedTime = max(0, Double(inX) / zoom)
                    onSetWorkAreaIn?(clickedTime)
                } label: {
                    Label("Fijar Punto de Entrada aquí (I)", systemImage: "arrow.right.to.line")
                }

                Button {
                    let clickedTime = max(0, Double(outX) / zoom)
                    onSetWorkAreaOut?(clickedTime)
                } label: {
                    Label("Fijar Punto de Salida aquí (O)", systemImage: "arrow.left.to.line")
                }

                if hasCustomArea {
                    Divider()

                    Button {
                        onResetWorkArea?()
                    } label: {
                        Label("Restablecer Rango de Renderizado (⌥X)", systemImage: "arrow.counterclockwise")
                    }
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
