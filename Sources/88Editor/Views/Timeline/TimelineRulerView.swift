import SwiftUI

/// Regla temporal interactiva graduada en segundos con marcas de tiempo,
/// soporte de Área de Trabajo / Rango de Renderizado (Puntos In y Out) arrastrables ÚNICAMENTE desde sus extremos
/// y navegación libre (Seek / Scrub) en el centro y a lo largo de toda la regla.
public struct TimelineRulerView: View {
    let duration: Double
    let zoom: Double // píxeles por segundo
    let workAreaIn: Double?
    let workAreaOut: Double?
    let onSeek: (Double) -> Void
    var onSetWorkAreaIn: ((Double) -> Void)? = nil
    var onSetWorkAreaOut: ((Double) -> Void)? = nil
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
            let projectEndX = CGFloat(duration) * CGFloat(zoom)
            let outOfBoundsWidth = max(0, totalWidth - projectEndX)

            // Rango de renderizado / In & Out
            let hasCustomArea = workAreaIn != nil || workAreaOut != nil
            let effIn = max(0.0, workAreaIn ?? 0.0)
            let effOut = max(effIn + 0.2, min(duration, workAreaOut ?? duration))
            let inX = CGFloat(effIn) * CGFloat(zoom)
            let outX = CGFloat(effOut) * CGFloat(zoom)
            let barWidth = max(4, outX - inX)

            ZStack(alignment: .topLeading) {
                // 1. Fondo base de la regla
                Color(NSColor.controlBackgroundColor)
                    .frame(width: totalWidth, height: 26)

                // 2. Marcas de tiempo y números (Atenuadas si sobrepasan el fin del proyecto)
                ForEach(0...totalSeconds, id: \.self) { second in
                    let xPos = CGFloat(second) * CGFloat(zoom)
                    let isPastEnd = Double(second) > duration

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
                    .opacity(isPastEnd ? 0.2 : 1.0)
                    .position(x: xPos, y: 12)
                    .allowsHitTesting(false)
                }

                // 3. Zona oscurecida fuera del proyecto y delimitador de FIN
                if outOfBoundsWidth > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.42))
                        .frame(width: outOfBoundsWidth, height: 26)
                        .position(x: projectEndX + outOfBoundsWidth / 2, y: 13)
                        .allowsHitTesting(false)

                    // Línea vertical que marca el fin de la duración
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 1.5, height: 26)
                        .position(x: projectEndX, y: 13)
                        .allowsHitTesting(false)

                    // Etiqueta destacada de FIN DE PROYECTO
                    HStack(spacing: 3) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 8))
                        Text("FIN \(formatRulerTime(second: Int(duration)))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .position(x: max(35, projectEndX - 34), y: 12)
                    .allowsHitTesting(false)
                }

                // 4. Franja visual del Área de Trabajo (In / Out) decorativa: NO intercepta clics
                // Permitiendo que cualquier clic o arrastre en el medio desplace el cabezal (Seek) sin alterar In/Out
                if hasCustomArea && outX > inX {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: barWidth, height: 26)

                        // Barra superior horizontal que une los corchetes
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: barWidth, height: 3.0)
                    }
                    .frame(width: barWidth, height: 26)
                    .offset(x: inX, y: 0)
                    .allowsHitTesting(false)
                }

                // 5. Extremos interactivos: SOLO se mueven desde los extremos (corchetes)
                if hasCustomArea {
                    // Extremo Izquierdo: Corchete de Entrada (Punto In `[`)
                    WorkAreaBracketView(isLeft: true)
                        .frame(width: 14, height: 24)
                        .offset(x: max(0, inX), y: 1)
                        .zIndex(30)
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { val in
                                    if dragInitialIn == nil {
                                        dragInitialIn = effIn
                                    }
                                    let start = dragInitialIn ?? effIn
                                    let deltaSeconds = Double(val.translation.width) / zoom
                                    let newTime = max(0, min(effOut - 0.2, start + deltaSeconds))
                                    onSetWorkAreaIn?(newTime)
                                }
                                .onEnded { _ in
                                    dragInitialIn = nil
                                }
                        )

                    // Extremo Derecho: Corchete de Salida (Punto Out `]`)
                    WorkAreaBracketView(isLeft: false)
                        .frame(width: 14, height: 24)
                        .offset(x: max(inX + 14, outX - 14), y: 1)
                        .zIndex(30)
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { val in
                                    if dragInitialOut == nil {
                                        dragInitialOut = effOut
                                    }
                                    let start = dragInitialOut ?? effOut
                                    let deltaSeconds = Double(val.translation.width) / zoom
                                    let newTime = max(effIn + 0.2, min(duration, start + deltaSeconds))
                                    onSetWorkAreaOut?(newTime)
                                }
                                .onEnded { _ in
                                    dragInitialOut = nil
                                }
                        )
                }

                // Línea inferior divisoria
                Rectangle()
                    .fill(DesignSystem.border)
                    .frame(width: totalWidth, height: 1)
                    .offset(x: 0, y: 25)
                    .allowsHitTesting(false)
            }
            .frame(width: totalWidth, height: 26, alignment: .topLeading)
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
                    onSetWorkAreaIn?(effIn)
                } label: {
                    Label("Fijar Punto de Entrada aquí (I)", systemImage: "arrow.right.to.line")
                }

                Button {
                    onSetWorkAreaOut?(effOut)
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

/// Vista del tirador del corchete para ajustar In u Out con feedback visual y cursor nativo
struct WorkAreaBracketView: View {
    let isLeft: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack {
            // Fondo para fácil agarre con el ratón
            Color.clear
                .contentShape(Rectangle())

            WorkAreaBracketShape(isLeft: isLeft)
                .fill(isHovering ? Color.accentColor : Color.white)
                .frame(width: 12, height: 22)
                .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)

            // Letra de guía sutil indicativa de Extremo
            Text(isLeft ? "I" : "O")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(isHovering ? .white : Color.primary.opacity(0.75))
                .offset(x: isLeft ? 1 : -1, y: 0)
                .allowsHitTesting(false)
        }
        .frame(width: 14, height: 24)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .help(isLeft ? "Extremo In: Arrastra este tirador para ajustar el punto de entrada" : "Extremo Out: Arrastra este tirador para ajustar el punto de salida")
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
