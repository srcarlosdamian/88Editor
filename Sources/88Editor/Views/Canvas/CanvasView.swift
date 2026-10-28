import SwiftUI
import AVFoundation

/// Vista central del Canvas para previsualización en tiempo real.
/// Soporta zoom interactivo mediante gestos de trackpad (pellizcar / pinch-to-zoom),
/// desplazamiento (pan) cuando hay zoom, atajos de teclado (⌘+, ⌘-, ⌘0) y selector de escala proxy.
public struct CanvasView: View {
    @ObservedObject var viewModel: EditorViewModel

    // Estado del Zoom y Desplazamiento interactivo del Canvas
    @State private var canvasZoom: CGFloat = 1.0
    @State private var lastCanvasZoom: CGFloat = 1.0
    @State private var canvasPanOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    // Manipulación interactiva directa en el Lienzo (Mover y Escalar con el cursor)
    @GestureState private var liveDragTranslation: CGSize = .zero
    @GestureState private var liveScaleDelta: CGFloat = 1.0

    private enum ResizeCorner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Barra superior del Canvas: información, zoom interactivo y selector de calidad proxy
            HStack(spacing: 12) {
                // Info de preset y resolución
                HStack(spacing: 8) {
                    Image(systemName: viewModel.project.configuration.preset.iconName)
                        .foregroundColor(.secondary)
                    Text(viewModel.project.configuration.preset.rawValue)
                        .font(.system(size: 11, weight: .medium))
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(viewModel.project.configuration.resolutionDisplayString)
                        .font(DesignSystem.monoFont)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Controles interactivos de Zoom del Canvas
                HStack(spacing: 4) {
                    // Botón Zoom Out (⌘-)
                    Button {
                        zoomOut()
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .help("Reducir zoom del visor (⌘-)")

                    // Menú desplegable de niveles de Zoom
                    Menu {
                        Button("Ajustar al visor (100%)") { setZoom(1.0) }
                        Divider()
                        Button("25%") { setZoom(0.25) }
                        Button("50%") { setZoom(0.50) }
                        Button("75%") { setZoom(0.75) }
                        Button("100%") { setZoom(1.0) }
                        Button("150%") { setZoom(1.5) }
                        Button("200%") { setZoom(2.0) }
                        Button("300%") { setZoom(3.0) }
                        Button("400%") { setZoom(4.0) }
                    } label: {
                        Text("\(Int(canvasZoom * 100))%")
                            .font(DesignSystem.monoFont)
                            .foregroundColor(.primary)
                            .frame(width: 46)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()

                    // Botón Zoom In (⌘+)
                    Button {
                        zoomIn()
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .help("Aumentar zoom del visor (⌘+)")

                    // Botón Restablecer si tiene zoom
                    if abs(canvasZoom - 1.0) > 0.01 || canvasPanOffset != .zero {
                        Button("Restablecer") {
                            resetZoom()
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                        .help("Restablecer vista (⌘0 o doble clic)")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DesignSystem.border, lineWidth: 1)
                )

                // Selector de escala proxy (100% vs 50% para rendimiento en M-series)
                Picker("", selection: $viewModel.playbackEngine.previewScale) {
                    ForEach(PreviewScale.allCases) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .help("Reduce la resolución de previsualización para ahorrar batería y optimizar MacBooks Air")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Contenedor del Visor con Letterboxing geométrico y Zoom/Pan por gestos
            GeometryReader { geo in
                let config = viewModel.project.configuration
                let targetAspect = config.aspectRatio
                let containerWidth = geo.size.width - 32
                let containerHeight = geo.size.height - 32

                let (fittedWidth, fittedHeight) = calculateFitDimensions(
                    containerWidth: max(50, containerWidth),
                    containerHeight: max(50, containerHeight),
                    aspectRatio: targetAspect
                )

                ZStack {
                    // Fondo de área de trabajo neutral: clic deselecciona cualquier objeto activo
                    Color(NSColor.underPageBackgroundColor)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedClipId = nil
                            viewModel.selectedTrackId = nil
                        }
                        .contextMenu {
                            if viewModel.clipboardClip != nil {
                                Button {
                                    viewModel.pasteClipAtPlayhead()
                                } label: {
                                    Label("Pegar en Cabezal (⌘V)", systemImage: "doc.on.clipboard")
                                }
                            }

                            Button {
                                viewModel.insertSheetCategory = .text
                                viewModel.isInsertSheetPresented = true
                            } label: {
                                Label("Añadir Texto (T)...", systemImage: "textformat")
                            }

                            Button {
                                viewModel.insertSheetCategory = .shape
                                viewModel.isInsertSheetPresented = true
                            } label: {
                                Label("Añadir Forma Vectorial...", systemImage: "square.on.circle")
                            }

                            Divider()

                            Button {
                                resetZoom()
                            } label: {
                                Label("Restablecer Vista (100% - ⌘0)", systemImage: "arrow.counterclockwise")
                            }

                            Button {
                                viewModel.isProjectSettingsSheetPresented = true
                            } label: {
                                Label("Ajustes del Proyecto... (⌘,)", systemImage: "slider.horizontal.3")
                            }

                            Divider()

                            Button {
                                viewModel.selectedClipId = nil
                                viewModel.selectedTrackId = nil
                            } label: {
                                Label("Deseleccionar Todo (Esc)", systemImage: "xmark.circle")
                            }
                        }

                    // Lienzo del proyecto escalable y desplazable
                    ZStack {
                        config.backgroundColor.swiftUIColor
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedClipId = nil
                                viewModel.selectedTrackId = nil
                            }

                        // Renderizado de Capas Visuales en estricto orden de jerarquía (de abajo hacia arriba)
                        ForEach(viewModel.activeVisualLayersAtPlayhead) { layer in
                            renderLayerItem(layer: layer, fittedWidth: fittedWidth, fittedHeight: fittedHeight)
                        }

                        // Caja delimitadora de selección interactiva (Mover y Escalar con el cursor)
                        // Sólo para clips visuales (formas, textos, imágenes, videos; no para audios)
                        if let selected = viewModel.selectedClip, viewModel.isClipVisual(selected) {
                            selectionBoundingBox(for: selected, fittedWidth: fittedWidth, fittedHeight: fittedHeight)
                        }
                    }
                    .frame(width: fittedWidth, height: fittedHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .coordinateSpace(name: "CanvasWorkspace")
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(DesignSystem.subtleBorder, lineWidth: 1)
                    )
                    // Transformación de Zoom y Pan interactivos
                    .scaleEffect(canvasZoom)
                    .offset(canvasPanOffset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .clipped()
                // Gesto de Pellizco para Zoom (Trackpad Pinch to Zoom)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let proposed = lastCanvasZoom * value
                            canvasZoom = min(max(proposed, 0.25), 5.0)
                        }
                        .onEnded { _ in
                            lastCanvasZoom = canvasZoom
                        }
                )
                // Gesto de Arrastre para Pan sólo cuando se tiene Zoom aplicado (> 1.0)
                .gesture(
                    canvasZoom > 1.0 ?
                    DragGesture(minimumDistance: 15)
                        .onChanged { val in
                            canvasPanOffset = CGSize(
                                width: lastPanOffset.width + val.translation.width,
                                height: lastPanOffset.height + val.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastPanOffset = canvasPanOffset
                        }
                    : nil
                )
                // Doble clic para restablecer zoom y centrado
                .onTapGesture(count: 2) {
                    resetZoom()
                }
            }

            // Barra de transporte inferior
            TransportBar(
                playbackEngine: viewModel.playbackEngine,
                framerate: viewModel.project.configuration.framerate.rawValue
            )
        }
        .background(Color(NSColor.underPageBackgroundColor))
        // Atajos de teclado para Zoom del Canvas y selección
        .background(
            ZStack {
                // Cmd + o Cmd = para Zoom In
                Button("") { zoomIn() }
                    .keyboardShortcut("=", modifiers: [.command])
                Button("") { zoomIn() }
                    .keyboardShortcut("+", modifiers: [.command])
                // Cmd - para Zoom Out
                Button("") { zoomOut() }
                    .keyboardShortcut("-", modifiers: [.command])
                // Cmd 0 para Restablecer
                Button("") { resetZoom() }
                    .keyboardShortcut("0", modifiers: [.command])
                // Esc para deseleccionar
                Button("") {
                    viewModel.selectedClipId = nil
                    viewModel.selectedTrackId = nil
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .opacity(0)
        )
    }

    // MARK: - Métodos de Zoom
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.15)) {
            let next = min(canvasZoom * 1.25, 5.0)
            canvasZoom = next
            lastCanvasZoom = next
        }
    }

    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.15)) {
            let next = max(canvasZoom / 1.25, 0.25)
            canvasZoom = next
            lastCanvasZoom = next
            if canvasZoom <= 1.0 {
                canvasPanOffset = .zero
                lastPanOffset = .zero
            }
        }
    }

    private func setZoom(_ level: CGFloat) {
        withAnimation(.easeInOut(duration: 0.18)) {
            canvasZoom = level
            lastCanvasZoom = level
            if level <= 1.0 {
                canvasPanOffset = .zero
                lastPanOffset = .zero
            }
        }
    }

    private func resetZoom() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            canvasZoom = 1.0
            lastCanvasZoom = 1.0
            canvasPanOffset = .zero
            lastPanOffset = .zero
        }
    }

    private func calculateFitDimensions(containerWidth: CGFloat, containerHeight: CGFloat, aspectRatio: Double) -> (CGFloat, CGFloat) {
        guard aspectRatio > 0, containerHeight > 0 else { return (320, 180) }
        let containerAspect = containerWidth / containerHeight

        if containerAspect > aspectRatio {
            let height = containerHeight
            let width = height * CGFloat(aspectRatio)
            return (width, height)
        } else {
            let width = containerWidth
            let height = width / CGFloat(aspectRatio)
            return (width, height)
        }
    }

    // MARK: - Cálculo de Dimensiones Reales del Elemento
    private func calculateElementDimensions(clip: TimelineClip, fittedWidth: CGFloat, fittedHeight: CGFloat) -> (CGFloat, CGFloat) {
        if clip.shapeType != nil {
            return (180, 180)
        }
        if let text = clip.textOverlay, !text.isEmpty {
            let fSize = clip.fontSize ?? 54.0
            let nsFont = NSFont(name: clip.fontName ?? "", size: fSize) ?? NSFont.systemFont(ofSize: fSize, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: nsFont]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let w = max(160, textSize.width + 40)
            let h = max(60, textSize.height + 30)
            return (min(fittedWidth, w), h)
        }
        if let asset = viewModel.asset(for: clip) {
            var w = asset.width
            var h = asset.height
            if w <= 0 || h <= 0 {
                // Fallback directo al archivo si aún no se inicializó
                if asset.mediaType == .image, let img = NSImage(contentsOf: asset.fileURL) {
                    w = Double(img.size.width)
                    h = Double(img.size.height)
                } else if asset.mediaType == .video {
                    let avAsset = AVURLAsset(url: asset.fileURL)
                    if let track = avAsset.tracks(withMediaType: .video).first {
                        let size = track.naturalSize.applying(track.preferredTransform)
                        let realW = abs(size.width)
                        let realH = abs(size.height)
                        if realW > 0 && realH > 0 {
                            w = Double(realW)
                            h = Double(realH)
                        }
                    }
                }
            }
            if w > 0 && h > 0 {
                let assetAspect = w / h
                // SIEMPRE ajusta en altura los elementos que se agregan (100% de la altura del visor, redondeo a enteros para evitar jitter):
                let elementH = fittedHeight.rounded()
                let elementW = (fittedHeight * CGFloat(assetAspect)).rounded()
                return (elementW, elementH)
            }
        }
        return (fittedWidth, fittedHeight)
    }

    // MARK: - Renderizado de Capas Visuales en el Visor
    @ViewBuilder
    private func renderLayerItem(layer: EditorViewModel.VisualLayerItem, fittedWidth: CGFloat, fittedHeight: CGFloat) -> some View {
        let clip = layer.clip
        let currentTime = viewModel.playbackEngine.currentTime
        let dynamicOpacity = clip.opacity(at: currentTime)
        let dynamicScale = clip.scale(at: currentTime)
        let dynamicRotation = clip.rotation(at: currentTime)
        let isSelected = (viewModel.selectedClipId == clip.id)
        let currentDrag = isSelected ? liveDragTranslation : .zero
        let currentScaleMult = isSelected ? liveScaleDelta : 1.0

        let (elemW, elemH) = calculateElementDimensions(clip: clip, fittedWidth: fittedWidth, fittedHeight: fittedHeight)

        Group {
            // Aviso de archivo no encontrado / eliminado del disco (Offline Media)
            if let asset = layer.asset, asset.isMissing {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.primary)
                    Text("Medio sin conexión: \(asset.fileName)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("El archivo original no existe o fue eliminado del disco.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Button("Buscar y reemplazar archivo...") {
                        viewModel.reconnectAsset(id: asset.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(width: elemW, height: elemH)
                .background(Color.black.opacity(0.85))
                .cornerRadius(4)
            }
            // A) Formas Vectoriales (Círculo, Rectángulo, Estrella, Triángulo)
            else if let shape = clip.shapeType {
                renderVectorShape(shape: shape, fillHex: clip.fillColorHex ?? "#FF3B30", strokeHex: clip.strokeColorHex, strokeWidth: clip.strokeWidth ?? 0)
                    .frame(width: elemW, height: elemH)
            }
            // B) Video Nativo con aspecto original perfecto, ajuste en altura y recorte (Crop)
            else if let asset = layer.asset, asset.mediaType == .video {
                ClipVideoPlayerView(
                    clip: clip,
                    asset: asset,
                    viewModel: viewModel
                )
                .frame(width: elemW, height: elemH)
                .clipShape(CropRectShape(left: clip.cropLeft, right: clip.cropRight, top: clip.cropTop, bottom: clip.cropBottom))
            }
            // C) Imágenes estáticas con recorte (Crop)
            else if let asset = layer.asset, asset.mediaType == .image, let img = NSImage(contentsOf: asset.fileURL) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: elemW, height: elemH)
                    .clipShape(CropRectShape(left: clip.cropLeft, right: clip.cropRight, top: clip.cropTop, bottom: clip.cropBottom))
            }
            // D) Texto Vectorial nítido con resolución robusta de fuentes
            else if let text = clip.textOverlay, !text.isEmpty {
                let textColor = Color(hex: clip.textColorHex ?? "#FF3B30")
                let fSize = clip.fontSize ?? 54.0
                Text(text)
                    .font(resolveFont(name: clip.fontName, size: fSize))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    .padding(10)
                    .frame(width: elemW, height: elemH)
            }
        }
        .overlay(
            // Detector de clic directo en el canvas para seleccionar el elemento
            Color.white.opacity(0.0001)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedClipId = clip.id
                    viewModel.selectedTrackId = clip.trackId
                }
        )
        .offset(x: clip.positionX + currentDrag.width, y: clip.positionY + currentDrag.height)
        .scaleEffect(dynamicScale * currentScaleMult)
        .rotationEffect(.degrees(dynamicRotation))
        .opacity(dynamicOpacity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedClipId = clip.id
            viewModel.selectedTrackId = clip.trackId
        }
        // Menú contextual con clic secundario en el elemento del Lienzo
        .contextMenu {
            Button {
                viewModel.selectedClipId = clip.id
                viewModel.cutSelectedClip()
            } label: {
                Label("Cortar (⌘X)", systemImage: "scissors")
            }

            Button {
                viewModel.selectedClipId = clip.id
                viewModel.copySelectedClip()
            } label: {
                Label("Copiar (⌘C)", systemImage: "doc.on.doc")
            }

            Button {
                viewModel.pasteClipAtPlayhead()
            } label: {
                Label("Pegar en Cabezal (⌘V)", systemImage: "doc.on.clipboard")
            }

            Button {
                viewModel.selectedClipId = clip.id
                viewModel.duplicateSelectedClip()
            } label: {
                Label("Duplicar en Nueva Capa (⌘D)", systemImage: "plus.square.on.square")
            }

            Button {
                viewModel.selectedClipId = clip.id
                viewModel.splitSelectedClipAtPlayhead()
            } label: {
                Label("Dividir en Cabezal (⌘B)", systemImage: "arrow.left.and.right.scissors")
            }

            Divider()

            if viewModel.isClipCroppable(clip) {
                Button {
                    viewModel.selectedClipId = clip.id
                    viewModel.selectedTrackId = clip.trackId
                    viewModel.openCropModal(for: clip)
                } label: {
                    Label("Recortar imagen/video...", systemImage: "crop")
                }

                if clip.hasCrop {
                    Button {
                        viewModel.selectedClipId = clip.id
                        viewModel.selectedTrackId = clip.trackId
                        viewModel.updateSelectedClip {
                            $0.cropLeft = 0.0
                            $0.cropRight = 0.0
                            $0.cropTop = 0.0
                            $0.cropBottom = 0.0
                        }
                        viewModel.recordHistory(title: "Restablecer recorte", icon: "crop")
                    } label: {
                        Label("Restablecer Recorte", systemImage: "arrow.counterclockwise")
                    }
                }

                Divider()
            }

            Button {
                viewModel.selectedClipId = clip.id
                viewModel.centerClipInCanvas(clipId: clip.id)
            } label: {
                Label("Centrar en Lienzo", systemImage: "scope")
            }

            Button {
                viewModel.selectedClipId = clip.id
                viewModel.resetTransform(for: clip.id)
            } label: {
                Label("Restablecer Transformación", systemImage: "arrow.counterclockwise")
            }

            Divider()

            // Jerarquía de Capas: Subir / Bajar / Traer al Frente / Enviar al Fondo
            Menu("Orden de Capas") {
                Button {
                    viewModel.bringTrackToFront(id: clip.trackId)
                } label: {
                    Label("Traer al Frente (Capa Superior)", systemImage: "arrow.up.to.line")
                }

                Button {
                    viewModel.moveTrackUp(id: clip.trackId)
                } label: {
                    Label("Subir Capa (Traer hacia adelante)", systemImage: "arrow.up")
                }

                Button {
                    viewModel.moveTrackDown(id: clip.trackId)
                } label: {
                    Label("Bajar Capa (Enviar hacia atrás)", systemImage: "arrow.down")
                }

                Button {
                    viewModel.sendTrackToBack(id: clip.trackId)
                } label: {
                    Label("Enviar al Fondo (Capa Inferior)", systemImage: "arrow.down.to.line")
                }
            }

            Divider()

            Button(role: .destructive) {
                viewModel.selectedClipId = clip.id
                viewModel.deleteSelectedClip()
            } label: {
                Label("Eliminar Elemento (Delete)", systemImage: "trash")
            }
        }
    }

    // MARK: - Bounding Box Interactiva de Selección
    @ViewBuilder
    private func selectionBoundingBox(for clip: TimelineClip, fittedWidth: CGFloat, fittedHeight: CGFloat) -> some View {
        let currentTime = viewModel.playbackEngine.currentTime
        let dynamicScale = clip.scale(at: currentTime)
        let dynamicRotation = clip.rotation(at: currentTime)

        let (baseW, baseH) = calculateElementDimensions(clip: clip, fittedWidth: fittedWidth, fittedHeight: fittedHeight)

        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(DesignSystem.selectedClipBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .background(
                    Color.white.opacity(0.0001)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedClipId = clip.id
                            viewModel.selectedTrackId = clip.trackId
                        }
                )
                .frame(width: baseW, height: baseH)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(coordinateSpace: .named("CanvasWorkspace"))
                        .updating($liveDragTranslation) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { val in
                            viewModel.updateSelectedClip {
                                $0.positionX += val.translation.width
                                $0.positionY += val.translation.height
                            }
                            viewModel.recordHistory(title: "Mover objeto en lienzo", icon: "arrow.up.and.down.and.arrow.left.and.right")
                        }
                )
                .overlay(alignment: .topLeading) {
                    handleCircle(corner: .topLeft, clip: clip, baseW: baseW, baseH: baseH, dynamicScale: dynamicScale)
                        .offset(x: -5, y: -5)
                }
                .overlay(alignment: .topTrailing) {
                    handleCircle(corner: .topRight, clip: clip, baseW: baseW, baseH: baseH, dynamicScale: dynamicScale)
                        .offset(x: 5, y: -5)
                }
                .overlay(alignment: .bottomLeading) {
                    handleCircle(corner: .bottomLeft, clip: clip, baseW: baseW, baseH: baseH, dynamicScale: dynamicScale)
                        .offset(x: -5, y: 5)
                }
                .overlay(alignment: .bottomTrailing) {
                    handleCircle(corner: .bottomRight, clip: clip, baseW: baseW, baseH: baseH, dynamicScale: dynamicScale)
                        .offset(x: 5, y: 5)
                }
                .overlay(alignment: .top) {
                    if viewModel.isClipCroppable(clip) {
                        Button {
                            viewModel.openCropModal(for: clip)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "crop")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Recortar")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.85))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.4), lineWidth: 1))
                            .shadow(radius: 3)
                        }
                        .buttonStyle(.plain)
                        .offset(y: -28)
                        .help("Recortar bordes de esta imagen o video")
                    }
                }
        }
        .offset(x: clip.positionX + liveDragTranslation.width, y: clip.positionY + liveDragTranslation.height)
        .scaleEffect(dynamicScale * liveScaleDelta)
        .rotationEffect(.degrees(dynamicRotation))
    }

    @ViewBuilder
    private func handleCircle(corner: ResizeCorner, clip: TimelineClip, baseW: CGFloat, baseH: CGFloat, dynamicScale: Double) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(DesignSystem.selectedClipBorder, lineWidth: 2))
            .shadow(radius: 2)
            .contentShape(Rectangle().inset(by: -6))
            .gesture(
                DragGesture(coordinateSpace: .named("CanvasWorkspace"))
                    .updating($liveScaleDelta) { val, state, _ in
                        let dx = val.translation.width
                        let dy = val.translation.height
                        let halfW = max(20.0, (baseW * CGFloat(dynamicScale)) / 2.0)
                        let halfH = max(20.0, (baseH * CGFloat(dynamicScale)) / 2.0)

                        let delta: CGFloat
                        switch corner {
                        case .bottomRight:
                            delta = (dx / halfW + dy / halfH) / 2.0
                        case .topRight:
                            delta = (dx / halfW - dy / halfH) / 2.0
                        case .bottomLeft:
                            delta = (-dx / halfW + dy / halfH) / 2.0
                        case .topLeft:
                            delta = (-dx / halfW - dy / halfH) / 2.0
                        }

                        let factor = max(0.05, 1.0 + delta)
                        state = factor
                    }
                    .onEnded { val in
                        let dx = val.translation.width
                        let dy = val.translation.height
                        let halfW = max(20.0, (baseW * CGFloat(dynamicScale)) / 2.0)
                        let halfH = max(20.0, (baseH * CGFloat(dynamicScale)) / 2.0)

                        let delta: CGFloat
                        switch corner {
                        case .bottomRight:
                            delta = (dx / halfW + dy / halfH) / 2.0
                        case .topRight:
                            delta = (dx / halfW - dy / halfH) / 2.0
                        case .bottomLeft:
                            delta = (-dx / halfW + dy / halfH) / 2.0
                        case .topLeft:
                            delta = (-dx / halfW - dy / halfH) / 2.0
                        }

                        let factor = max(0.05, 1.0 + delta)
                        let currentScale = clip.scale(at: viewModel.currentClipRelativeTime)
                        let newScale = max(0.05, min(10.0, currentScale * factor))
                        viewModel.updateAnimatableProperty(.scale, value: newScale)
                        viewModel.recordHistory(title: "Escalar objeto en lienzo", icon: "arrow.up.left.and.arrow.down.right")
                    }
            )
    }

    @ViewBuilder
    private func renderVectorShape(shape: String, fillHex: String, strokeHex: String?, strokeWidth: Double) -> some View {
        let fillColor = Color(hex: fillHex)
        let strokeColor = Color(hex: strokeHex ?? "#FFFFFF")

        switch shape {
        case "circle":
            Circle()
                .fill(fillColor)
                .overlay(Circle().stroke(strokeColor, lineWidth: strokeWidth))
        case "rectangle":
            Rectangle()
                .fill(fillColor)
                .overlay(Rectangle().stroke(strokeColor, lineWidth: strokeWidth))
        case "roundedRectangle":
            RoundedRectangle(cornerRadius: 24)
                .fill(fillColor)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(strokeColor, lineWidth: strokeWidth))
        case "star":
            StarShape()
                .fill(fillColor)
                .overlay(StarShape().stroke(strokeColor, lineWidth: strokeWidth))
        case "triangle":
            TriangleShape()
                .fill(fillColor)
                .overlay(TriangleShape().stroke(strokeColor, lineWidth: strokeWidth))
        default:
            Circle()
                .fill(fillColor)
        }
    }

    private func resolveFont(name: String?, size: CGFloat) -> Font {
        guard let name = name, !name.isEmpty else {
            return .system(size: size, weight: .bold)
        }
        if let nsFont = NSFont(name: name, size: size) {
            return Font(nsFont)
        }
        return .custom(name, size: size)
    }
}

/// Forma de recorte porcentual de bordes (Crop)
public struct CropRectShape: Shape, Animatable {
    public var left: Double
    public var right: Double
    public var top: Double
    public var bottom: Double

    public var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(AnimatablePair(left, right), AnimatablePair(top, bottom))
        }
        set {
            left = newValue.first.first
            right = newValue.first.second
            top = newValue.second.first
            bottom = newValue.second.second
        }
    }

    public func path(in rect: CGRect) -> Path {
        let l = max(0.0, min(0.48, left))
        let r = max(0.0, min(0.48, right))
        let t = max(0.0, min(0.48, top))
        let b = max(0.0, min(0.48, bottom))

        let x = rect.minX + rect.width * CGFloat(l)
        let y = rect.minY + rect.height * CGFloat(t)
        let w = rect.width * CGFloat(max(0.01, 1.0 - l - r))
        let h = rect.height * CGFloat(max(0.01, 1.0 - t - b))
        return Path(CGRect(x: x, y: y, width: w, height: h))
    }
}
