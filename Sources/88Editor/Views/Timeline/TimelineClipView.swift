import SwiftUI
import AppKit

/// Vista visual de un Clip dentro de una pista en la línea de tiempo.
/// Soporta arrastre libre con ratón en el tiempo y entre capas (pistas),
/// visualización de rombos de fotogramas clave (Keyframes), recorte de bordes (Trim In/Out)
/// y menú contextual completo.
public struct TimelineClipView: View {
    let clip: TimelineClip
    let isSelected: Bool
    let zoom: Double // px por segundo
    let isTrackLocked: Bool
    let height: CGFloat
    let isAudioTrack: Bool
    let availableTracks: [TimelineTrack]
    let currentTrack: TimelineTrack

    let onSelect: () -> Void
    let onMove: (_ newStartTime: Double, _ verticalDelta: CGFloat) -> Void
    let onMoveToSpecificTrack: (UUID) -> Void
    var onDragging: ((_ proposedStartTime: Double) -> Double)? = nil
    var onDragEnded: (() -> Void)? = nil
    let onTrimIn: (Double) -> Void
    let onTrimOut: (Double) -> Void
    let onDuplicate: () -> Void
    var onCopy: (() -> Void)? = nil
    var onPaste: (() -> Void)? = nil
    let onSplit: () -> Void
    let onToggleMute: () -> Void
    let onDelete: () -> Void
    var isMissing: Bool = false
    var onReconnect: (() -> Void)? = nil

    @State private var dragOffsetX: CGFloat = 0
    @State private var dragOffsetY: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var trimInOffset: CGFloat = 0
    @State private var trimOutOffset: CGFloat = 0
    @State private var isHoveringLeftHandle: Bool = false
    @State private var isHoveringRightHandle: Bool = false

    private var clipWidth: CGFloat {
        max(20, CGFloat(clip.duration) * CGFloat(zoom) + trimOutOffset - trimInOffset)
    }

    private var clipX: CGFloat {
        max(0, CGFloat(clip.startTime) * CGFloat(zoom) + trimInOffset + dragOffsetX)
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            // Fondo / Cuerpo principal del clip
            RoundedRectangle(cornerRadius: 5)
                .fill(clipColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? DesignSystem.selectedClipBorder : DesignSystem.clipBorder, lineWidth: isSelected ? 2 : 1)
                )

            // Visualización de onda de audio para pistas de audio
            if isAudioTrack && height >= 38 {
                let barCount = max(2, Int(clipWidth / 4))
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<min(barCount, 400), id: \.self) { i in
                        let pseudoRandomHeight = abs(sin(Double(i) * 0.45) * cos(Double(i) * 0.2)) * Double(height * 0.55) + 4
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 2, height: CGFloat(pseudoRandomHeight))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .allowsHitTesting(false)
            }

            // Cabecera del clip con título y duración
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: isMissing ? "exclamationmark.triangle.fill" : (isAudioTrack ? "waveform" : "film"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.85))

                    Text(clip.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if isMissing && clipWidth > 90 {
                        Text("Sin conexión")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(3)
                    }

                    Spacer()

                    Text(String(format: "%.1fs", clip.duration))
                        .font(DesignSystem.monoFont)
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                Spacer()
            }

            // Visualización de Rombos de Keyframes en la Línea de Tiempo
            if isSelected && !clip.allKeyframeTimes.isEmpty {
                ForEach(clip.allKeyframeTimes, id: \.self) { kfTime in
                    let kfX = CGFloat(kfTime) * CGFloat(zoom)
                    if kfX >= 0 && kfX <= clipWidth {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(DesignSystem.selectedClipBorder)
                            .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
                            .position(x: kfX, y: max(14, height - 12))
                            .help(String(format: "Fotograma clave en +%.2fs", kfTime))
                    }
                }
            }

            // Mango izquierdo de recorte (Trim In)
            if !isTrackLocked {
                Rectangle()
                    .fill(isHoveringLeftHandle || trimInOffset != 0 ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                    .frame(width: 8)
                    .cornerRadius(3, corners: [.topLeft, .bottomLeft])
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 2, height: max(12, height * 0.4))
                    )
                    .zIndex(20)
                    .onHover { hovering in
                        isHoveringLeftHandle = hovering
                        if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                trimInOffset = value.translation.width
                            }
                            .onEnded { value in
                                let deltaSeconds = Double(value.translation.width) / zoom
                                onTrimIn(deltaSeconds)
                                trimInOffset = 0
                            }
                    )

                // Mango derecho de recorte (Trim Out)
                Rectangle()
                    .fill(isHoveringRightHandle || trimOutOffset != 0 ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                    .frame(width: 8)
                    .cornerRadius(3, corners: [.topRight, .bottomRight])
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 2, height: max(12, height * 0.4))
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .zIndex(20)
                    .onHover { hovering in
                        isHoveringRightHandle = hovering
                        if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                trimOutOffset = value.translation.width
                            }
                            .onEnded { value in
                                let deltaSeconds = Double(value.translation.width) / zoom
                                onTrimOut(deltaSeconds)
                                trimOutOffset = 0
                            }
                    )
            }
        }
        .frame(width: clipWidth, height: max(26, height - 6))
        .offset(x: clipX, y: dragOffsetY)
        .zIndex(isDragging ? 999 : (isSelected ? 10 : 1))
        .opacity(isDragging ? 0.88 : 1.0)
        .shadow(color: Color.black.opacity(isDragging ? 0.5 : (isSelected ? 0.25 : 0)), radius: isDragging ? 10 : 3, x: 0, y: isDragging ? 5 : 1)
        // Gesto unificado: selección instantánea al hacer clic y arrastre temporal / vertical
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isSelected {
                        onSelect()
                    }
                    NSApp.keyWindow?.makeFirstResponder(nil)

                    guard !isTrackLocked else { return }

                    if hypot(value.translation.width, value.translation.height) >= 3 {
                        isDragging = true
                        dragOffsetY = value.translation.height

                        let rawProposed = max(0, clip.startTime + Double(value.translation.width) / zoom)
                        if let snapCalc = onDragging {
                            let snappedTime = snapCalc(rawProposed)
                            dragOffsetX = CGFloat(snappedTime - clip.startTime) * CGFloat(zoom)
                        } else {
                            dragOffsetX = value.translation.width
                        }
                    }
                }
                .onEnded { value in
                    onDragEnded?()
                    if !isTrackLocked && isDragging && hypot(value.translation.width, value.translation.height) >= 3 {
                        isDragging = false
                        let finalStartTime = max(0, clip.startTime + Double(dragOffsetX) / zoom)
                        onMove(finalStartTime, value.translation.height)
                    } else {
                        isDragging = false
                        onSelect()
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
                    dragOffsetX = 0
                    dragOffsetY = 0
                }
        )
        // Menú contextual con clic derecho
        .contextMenu {
            if isMissing {
                Button {
                    onReconnect?()
                } label: {
                    Label("Reconectar o reemplazar archivo original...", systemImage: "arrow.triangle.2.circlepath")
                }
                Divider()
            }

            let compatibleTracks = availableTracks.filter { $0.kind == currentTrack.kind && $0.id != currentTrack.id }
            if !compatibleTracks.isEmpty {
                Menu("Mover a otra pista") {
                    ForEach(compatibleTracks) { targetTrack in
                        Button("Pista \(targetTrack.name)") {
                            onMoveToSpecificTrack(targetTrack.id)
                        }
                    }
                }
            }

            Button {
                onCopy?()
            } label: {
                Label("Copiar clip (⌘C)", systemImage: "doc.on.doc")
            }

            Button {
                onDuplicate()
            } label: {
                Label("Duplicar clip (⌘D)", systemImage: "plus.square.on.square")
            }

            Button {
                onPaste?()
            } label: {
                Label("Pegar clip (⌘V)", systemImage: "doc.on.clipboard")
            }

            Button {
                onSplit()
            } label: {
                Label("Dividir en cabezal (⌘B)", systemImage: "scissors")
            }

            Button {
                onToggleMute()
            } label: {
                Label(clip.isMuted ? "Activar audio" : "Silenciar clip (M)", systemImage: clip.isMuted ? "speaker.wave.2" : "speaker.slash")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar clip (Delete)", systemImage: "trash")
            }
        }
    }

    private var clipColor: Color {
        if clip.isMuted {
            return Color.gray.opacity(0.4)
        }
        return isAudioTrack ? DesignSystem.audioClip : DesignSystem.videoClip
    }
}

// Extensión para esquinas específicas redondeadas
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

public struct RectCorner: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let topLeft = RectCorner(rawValue: 1 << 0)
    public static let topRight = RectCorner(rawValue: 1 << 1)
    public static let bottomLeft = RectCorner(rawValue: 1 << 2)
    public static let bottomRight = RectCorner(rawValue: 1 << 3)
    public static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

public struct RoundedCornerShape: Shape {
    public var radius: CGFloat = .infinity
    public var corners: RectCorner = .allCorners

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + (corners.contains(.topLeft) ? radius : 0), y: rect.minY))

        // Top edge and top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - (corners.contains(.topRight) ? radius : 0), y: rect.minY))
        if corners.contains(.topRight) {
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }

        // Right edge and bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - (corners.contains(.bottomRight) ? radius : 0)))
        if corners.contains(.bottomRight) {
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }

        // Bottom edge and bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + (corners.contains(.bottomLeft) ? radius : 0), y: rect.maxY))
        if corners.contains(.bottomLeft) {
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }

        // Left edge and top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + (corners.contains(.topLeft) ? radius : 0)))
        if corners.contains(.topLeft) {
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        return path
    }
}
