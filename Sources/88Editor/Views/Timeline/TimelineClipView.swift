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
    var onCut: (() -> Void)? = nil
    var onCopy: (() -> Void)? = nil
    var onPaste: (() -> Void)? = nil
    let onSplit: () -> Void
    let onToggleMute: () -> Void
    let onDelete: () -> Void
    var isMissing: Bool = false
    var onReconnect: (() -> Void)? = nil
    var onCrop: (() -> Void)? = nil
    var onResetCrop: (() -> Void)? = nil
    var onResetTransform: (() -> Void)? = nil
    var onCenterInCanvas: (() -> Void)? = nil
    var onMoveTrackUp: (() -> Void)? = nil
    var onMoveTrackDown: (() -> Void)? = nil
    var onBringToFront: (() -> Void)? = nil
    var onSendToBack: (() -> Void)? = nil
    var playheadTime: Double = 0.0
    var onSeekToKeyframe: ((Double) -> Void)? = nil
    var onUpdateKeyframeValue: ((AnimatableProperty, UUID, Double) -> Void)? = nil

    @State private var activePropertyOverride: AnimatableProperty? = nil
    @State private var draggingKeyframeId: UUID? = nil
    @State private var draggingKeyframeValue: Double? = nil
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

    private var hasAutomationSublane: Bool {
        return !clip.allKeyframeTimes.isEmpty || (isAudioTrack && !clip.volumeKeyframes.isEmpty)
    }

    private var animatedProperties: [AnimatableProperty] {
        AnimatableProperty.allCases.filter { !clip.keyframes(for: $0).isEmpty }
    }

    private var activeProperty: AnimatableProperty {
        if let overrideProp = activePropertyOverride, !clip.keyframes(for: overrideProp).isEmpty {
            return overrideProp
        }
        if isAudioTrack || !clip.volumeKeyframes.isEmpty {
            return .volume
        }
        if !clip.positionXKeyframes.isEmpty { return .positionX }
        if !clip.positionYKeyframes.isEmpty { return .positionY }
        if !clip.opacityKeyframes.isEmpty { return .opacity }
        if !clip.scaleKeyframes.isEmpty { return .scale }
        if !clip.rotationKeyframes.isEmpty { return .rotation }
        return isAudioTrack ? .volume : .opacity
    }

    private var sublaneHeight: CGFloat {
        max(16, min(22, height * 0.36))
    }

    private func cycleNextProperty() {
        let props = animatedProperties
        guard props.count > 1 else { return }
        if let idx = props.firstIndex(of: activeProperty) {
            let nextIdx = (idx + 1) % props.count
            activePropertyOverride = props[nextIdx]
        } else {
            activePropertyOverride = props.first
        }
    }

    private func badgeColor(for property: AnimatableProperty) -> Color {
        switch property {
        case .volume: return Color(red: 0.25, green: 0.8, blue: 1.0)
        case .positionX, .positionY: return Color(red: 1.0, green: 0.75, blue: 0.25)
        case .opacity: return Color(red: 0.85, green: 0.55, blue: 1.0)
        case .scale: return Color(red: 0.35, green: 0.9, blue: 0.55)
        case .rotation: return Color(red: 1.0, green: 0.45, blue: 0.45)
        }
    }

    public static func yForValue(_ value: Double, property: AnimatableProperty, sublaneH: CGFloat) -> CGFloat {
        let usableH = max(4.0, sublaneH - 6.0)
        let norm: Double
        switch property {
        case .volume, .opacity:
            norm = max(0.0, min(1.0, value))
        case .scale:
            norm = max(0.0, min(1.0, (value - 0.05) / 2.95))
        case .rotation:
            norm = max(0.0, min(1.0, (value + 180.0) / 360.0))
        case .positionX, .positionY:
            norm = max(0.0, min(1.0, (value + 400.0) / 800.0))
        }
        return (sublaneH - 3.0) - CGFloat(norm) * usableH
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

            // Visualización de onda de audio para pistas de audio (despejada en la parte superior sin tapar)
            if isAudioTrack && height >= 34 {
                let barCount = max(2, Int(clipWidth / 4))
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<min(barCount, 400), id: \.self) { i in
                        let pseudoRandomHeight = abs(sin(Double(i) * 0.45) * cos(Double(i) * 0.2)) * Double(max(6, (height - (hasAutomationSublane ? sublaneHeight : 0)) * 0.52)) + 4
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 2, height: CGFloat(pseudoRandomHeight))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 16)
                .padding(.bottom, hasAutomationSublane ? sublaneHeight + 2 : 4)
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

            // Carril inferior minimalista de automatización (Organizado por propiedad, ej. 🔊 VOLUMEN, ✥ POSICIÓN)
            if hasAutomationSublane && height >= 32 {
                let prop = activeProperty
                let kfs = clip.keyframes(for: prop).sorted(by: { $0.seconds < $1.seconds })

                ZStack(alignment: .bottomLeading) {
                    // Fondo oscuro del carril de automatización
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.90))
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 1),
                            alignment: .top
                        )

                    // Línea continua de automatización entre fotogramas clave
                    if !kfs.isEmpty {
                        TimelineAutomationCurveView(
                            keyframes: kfs,
                            clipWidth: clipWidth,
                            sublaneHeight: sublaneHeight,
                            zoom: zoom,
                            property: prop,
                            draggingKeyframeId: draggingKeyframeId,
                            draggingKeyframeValue: draggingKeyframeValue
                        )
                        .allowsHitTesting(false)

                        // Rombos interactivos de fotogramas clave en el carril inferior
                        ForEach(kfs) { kf in
                            let kfX = CGFloat(kf.seconds) * CGFloat(zoom)
                            if kfX >= 0 && kfX <= clipWidth {
                                let currentVal = (draggingKeyframeId == kf.id ? (draggingKeyframeValue ?? kf.value) : kf.value)
                                let kfY = TimelineClipView.yForValue(currentVal, property: prop, sublaneH: sublaneHeight)
                                let isNearPlayhead = abs(playheadTime - (clip.startTime + kf.seconds)) <= 0.15

                                KeyframeDiamondNode(
                                    keyframe: kf,
                                    property: prop,
                                    value: currentVal,
                                    isNearPlayhead: isNearPlayhead,
                                    onTap: {
                                        onSelect()
                                        onSeekToKeyframe?(clip.startTime + kf.seconds)
                                    },
                                    onDragValue: { newVal in
                                        draggingKeyframeId = kf.id
                                        draggingKeyframeValue = newVal
                                        onUpdateKeyframeValue?(prop, kf.id, newVal)
                                    },
                                    onDragEnd: {
                                        draggingKeyframeId = nil
                                        draggingKeyframeValue = nil
                                    }
                                )
                                .position(x: max(6, min(clipWidth - 6, kfX)), y: kfY)
                            }
                        }
                    }

                    // Etiqueta minimalista inferior que indica la propiedad (ej. 🔊 VOLUMEN, ✥ POSICIÓN)
                    Button {
                        cycleNextProperty()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: prop.iconName)
                                .font(.system(size: 7.5, weight: .bold))
                            Text(prop.displayName.uppercased())
                                .font(.system(size: 7.5, weight: .heavy))

                            if animatedProperties.count > 1 {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 6))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .foregroundColor(badgeColor(for: prop))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(badgeColor(for: prop).opacity(0.18))
                        .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 5)
                    .padding(.bottom, 2)
                    .help(animatedProperties.count > 1 ? "Propiedad activa: \(prop.displayName). Clic para alternar (\(animatedProperties.count))" : "Automatización de \(prop.displayName)")
                }
                .frame(height: sublaneHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 3))
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
        .simultaneousGesture(
            TapGesture().onEnded {
                onSelect()
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        )
        .gesture(
            DragGesture(minimumDistance: 3)
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
        // Menú contextual con clic derecho completo
        .contextMenu {
            Button {
                onSelect()
                onCut?()
            } label: {
                Label("Cortar (⌘X)", systemImage: "scissors")
            }

            Button {
                onSelect()
                onCopy?()
            } label: {
                Label("Copiar (⌘C)", systemImage: "doc.on.doc")
            }

            Button {
                onSelect()
                onPaste?()
            } label: {
                Label("Pegar en cabezal (⌘V)", systemImage: "doc.on.clipboard")
            }

            Button {
                onSelect()
                onDuplicate()
            } label: {
                Label("Duplicar en nueva capa (⌘D)", systemImage: "plus.square.on.square")
            }

            Button {
                onSelect()
                onSplit()
            } label: {
                Label("Dividir en cabezal (⌘B)", systemImage: "scissors")
            }

            Divider()

            if !isAudioTrack {
                Button {
                    onSelect()
                    onCrop?()
                } label: {
                    Label("Recortar...", systemImage: "crop")
                }

                if clip.hasCrop {
                    Button {
                        onSelect()
                        onResetCrop?()
                    } label: {
                        Label("Restablecer Recorte", systemImage: "arrow.counterclockwise")
                    }
                }

                Button {
                    onSelect()
                    onCenterInCanvas?()
                } label: {
                    Label("Centrar en Lienzo", systemImage: "scope")
                }

                Button {
                    onSelect()
                    onResetTransform?()
                } label: {
                    Label("Restablecer Transformación", systemImage: "arrow.counterclockwise")
                }

                Divider()
            }

            Menu("Orden de Capas") {
                Button {
                    onSelect()
                    onBringToFront?()
                } label: {
                    Label("Traer al Frente (Capa Superior)", systemImage: "arrow.up.to.line")
                }
                Button {
                    onSelect()
                    onMoveTrackUp?()
                } label: {
                    Label("Subir Capa (Traer adelante)", systemImage: "arrow.up")
                }
                Button {
                    onSelect()
                    onMoveTrackDown?()
                } label: {
                    Label("Bajar Capa (Enviar atrás)", systemImage: "arrow.down")
                }
                Button {
                    onSelect()
                    onSendToBack?()
                } label: {
                    Label("Enviar al Fondo (Capa Inferior)", systemImage: "arrow.down.to.line")
                }
            }

            let compatibleTracks = availableTracks.filter { $0.kind == currentTrack.kind && $0.id != currentTrack.id }
            if !compatibleTracks.isEmpty {
                Menu("Mover a otra capa existente") {
                    ForEach(compatibleTracks) { targetTrack in
                        Button(targetTrack.name) {
                            onSelect()
                            onMoveToSpecificTrack(targetTrack.id)
                        }
                    }
                }
            }

            Button {
                onSelect()
                onToggleMute()
            } label: {
                Label(clip.isMuted ? "Activar audio" : "Silenciar clip (M)", systemImage: clip.isMuted ? "speaker.wave.2" : "speaker.slash")
            }

            if isMissing {
                Divider()
                Button {
                    onSelect()
                    onReconnect?()
                } label: {
                    Label("Reconectar o reemplazar archivo original...", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Divider()

            Button(role: .destructive) {
                onSelect()
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

// MARK: - Curva de Automatización Continua
struct TimelineAutomationCurveView: View {
    let keyframes: [Keyframe]
    let clipWidth: CGFloat
    let sublaneHeight: CGFloat
    let zoom: Double
    let property: AnimatableProperty
    let draggingKeyframeId: UUID?
    let draggingKeyframeValue: Double?

    var body: some View {
        Path { path in
            guard let first = keyframes.first, let last = keyframes.last else { return }

            let firstVal = (draggingKeyframeId == first.id ? (draggingKeyframeValue ?? first.value) : first.value)
            let firstY = TimelineClipView.yForValue(firstVal, property: property, sublaneH: sublaneHeight)
            let firstX = CGFloat(first.seconds) * CGFloat(zoom)

            // Línea inicial desde el borde izquierdo del clip hasta el primer keyframe
            path.move(to: CGPoint(x: 0, y: firstY))
            path.addLine(to: CGPoint(x: firstX, y: firstY))

            // Tramos interpolados entre keyframes consecutivos
            for i in 0..<(keyframes.count - 1) {
                let k1 = keyframes[i]
                let k2 = keyframes[i + 1]

                let v1 = (draggingKeyframeId == k1.id ? (draggingKeyframeValue ?? k1.value) : k1.value)
                let v2 = (draggingKeyframeId == k2.id ? (draggingKeyframeValue ?? k2.value) : k2.value)

                let p1 = CGPoint(x: CGFloat(k1.seconds) * CGFloat(zoom), y: TimelineClipView.yForValue(v1, property: property, sublaneH: sublaneHeight))
                let p2 = CGPoint(x: CGFloat(k2.seconds) * CGFloat(zoom), y: TimelineClipView.yForValue(v2, property: property, sublaneH: sublaneHeight))

                path.addLine(to: p1)
                path.addLine(to: p2)
            }

            // Tramo final desde el último keyframe hasta el borde derecho del clip
            let lastVal = (draggingKeyframeId == last.id ? (draggingKeyframeValue ?? last.value) : last.value)
            let lastY = TimelineClipView.yForValue(lastVal, property: property, sublaneH: sublaneHeight)
            let lastX = CGFloat(last.seconds) * CGFloat(zoom)
            path.addLine(to: CGPoint(x: lastX, y: lastY))
            path.addLine(to: CGPoint(x: clipWidth, y: lastY))
        }
        .stroke(DesignSystem.selectedClipBorder.opacity(0.85), lineWidth: 1.5)
    }
}

// MARK: - Rombo Interactivo de Keyframe en la Línea de Tiempo
struct KeyframeDiamondNode: View {
    let keyframe: Keyframe
    let property: AnimatableProperty
    let value: Double
    let isNearPlayhead: Bool
    let onTap: () -> Void
    let onDragValue: (Double) -> Void
    let onDragEnd: () -> Void

    @State private var dragStartValue: Double? = nil
    @State private var isDragging: Bool = false

    var body: some View {
        ZStack {
            // Halo brillante al pasar cabezal o al arrastrar
            if isNearPlayhead || isDragging {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 14, height: 14)
            }

            Image(systemName: "diamond.fill")
                .font(.system(size: isNearPlayhead ? 10 : 8.5, weight: .bold))
                .foregroundColor(isNearPlayhead ? .white : DesignSystem.selectedClipBorder)
                .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
        }
        .frame(width: 16, height: 16)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    isDragging = true
                    if dragStartValue == nil {
                        dragStartValue = value
                    }
                    let base = dragStartValue ?? value
                    let deltaY = -gesture.translation.height
                    let stepFraction = Double(deltaY / 25.0)

                    switch property {
                    case .volume, .opacity:
                        let newVal = max(0.0, min(1.0, base + stepFraction))
                        onDragValue(newVal)
                    case .scale:
                        let newVal = max(0.05, min(5.0, base + stepFraction * 1.5))
                        onDragValue(newVal)
                    case .rotation:
                        let newVal = max(-180.0, min(180.0, base + Double(deltaY) * 2.0))
                        onDragValue(newVal)
                    case .positionX, .positionY:
                        let newVal = base + Double(deltaY) * 4.0
                        onDragValue(newVal)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    dragStartValue = nil
                    onDragEnd()
                }
        )
        .help(tooltipText)
    }

    private var tooltipText: String {
        switch property {
        case .volume:
            return String(format: "Volumen: %d%% (+%.2fs)\n• Clic para cabezal\n• Arrastra verticalmente para cambiar volumen", Int(value * 100), keyframe.seconds)
        case .opacity:
            return String(format: "Opacidad: %d%% (+%.2fs)\n• Clic para cabezal\n• Arrastra verticalmente para cambiar opacidad", Int(value * 100), keyframe.seconds)
        case .positionX, .positionY:
            return String(format: "%@: %.0fpx (+%.2fs)\n• Clic para cabezal\n• Arrastra para cambiar posición", property.displayName, value, keyframe.seconds)
        case .scale:
            return String(format: "Escala: %.0f%% (+%.2fs)\n• Clic para cabezal\n• Arrastra para cambiar escala", value * 100, keyframe.seconds)
        case .rotation:
            return String(format: "Rotación: %.0f° (+%.2fs)\n• Clic para cabezal\n• Arrastra para cambiar rotación", value, keyframe.seconds)
        }
    }
}
