import SwiftUI
import UniformTypeIdentifiers

/// Panel Inferior: Línea de Tiempo Multicapa Responsiva y No Magnética
/// Soporta zoom en video y audio por gestos de trackpad (pellizcar / pinch-to-zoom),
/// zoom vertical de altura de pistas (para ver ondas de audio en detalle),
/// ajuste automático a la ventana (Shift + Z) y regla continua.
public struct TimelineView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State private var isTimelineDropTargeted: Bool = false
    @State private var lastPinchZoom: Double = 60.0

    private let headerWidth: CGFloat = 160

    public var body: some View {
        VStack(spacing: 0) {
            // Barra superior de herramientas del Timeline
            HStack(spacing: 10) {
                // Herramienta de corte: Cmd + B
                Button {
                    viewModel.splitSelectedClipAtPlayhead()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "scissors")
                            .font(.system(size: 11))
                        Text("Dividir")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut("b", modifiers: [.command])
                .disabled(viewModel.selectedClip == nil)
                .help("Dividir clip en el cabezal (⌘B o tecla B)")

                // Botón Eliminar clip
                Button {
                    viewModel.deleteSelectedClip()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Eliminar")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.selectedClip == nil)
                .help("Eliminar clip seleccionado (Delete / Supr)")

                Divider().frame(height: 16)

                // Menú Añadir Pistas
                Menu {
                    Button("Añadir Pista de Video (V)") {
                        viewModel.addTrack(kind: .video)
                    }
                    Button("Añadir Pista de Audio (A)") {
                        viewModel.addTrack(kind: .audio)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 11))
                        Text("Pista")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Menú Insertar Objetos Vectoriales (Texto y Formas)
                Menu {
                    Button {
                        viewModel.insertSheetCategory = .text
                        viewModel.isInsertSheetPresented = true
                    } label: {
                        Label("Texto Vectorial...", systemImage: "character.textbox")
                    }

                    Button {
                        viewModel.insertSheetCategory = .shape
                        viewModel.isInsertSheetPresented = true
                    } label: {
                        Label("Forma Vectorial (Círculo, etc.)...", systemImage: "circle.fill")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 11))
                        Text("Insertar")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Insertar objetos vectoriales (texto y formas) con calidad infinita")

                Divider().frame(height: 16)

                // Botón Ajuste Magnético (Snapping inteligente entre capas)
                Button {
                    viewModel.isSnappingEnabled.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isSnappingEnabled ? "magnet.fill" : "magnet")
                            .font(.system(size: 11))
                        Text("Magnetismo")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(viewModel.isSnappingEnabled ? .primary : .secondary.opacity(0.6))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Ajuste magnético automático entre clips y capas (Tecla N)")

                Divider().frame(height: 16)

                // Acciones de Clip: Copiar / Pegar / Duplicar
                Button {
                    viewModel.copySelectedClip()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.selectedClip == nil)
                .help("Copiar clip (⌘C)")

                Button {
                    viewModel.pasteClipAtPlayhead()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.clipboardClip == nil)
                .help("Pegar clip en el cabezal (⌘V)")

                Button {
                    viewModel.duplicateSelectedClip()
                } label: {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.selectedClip == nil)
                .help("Duplicar clip (⌘D)")

                Spacer()

                // Zoom Vertical (Altura de Pistas de Audio y Video)
                Menu {
                    Button("Compacta (36px)") { withAnimation { viewModel.trackHeight = 36 } }
                    Button("Estándar (50px)") { withAnimation { viewModel.trackHeight = 50 } }
                    Button("Ampliada (72px)") { withAnimation { viewModel.trackHeight = 72 } }
                    Button("Detalle de Ondas (95px)") { withAnimation { viewModel.trackHeight = 95 } }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: 10))
                        Text("Altura pistas")
                            .font(.system(size: 10))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Ajusta la altura vertical de las pistas para ver con mayor claridad formas de onda y miniaturas")

                Divider().frame(height: 16)

                // Botón Ajustar Línea de Tiempo (Shift + Z)
                Button("Ajustar (⇧Z)") {
                    viewModel.fitTimelineToWindow(availableWidth: 800)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .help("Ajustar toda la línea de tiempo en pantalla (Shift + Z)")

                // Zoom Horizontal del Timeline (Pellizcar en trackpad o slider)
                HStack(spacing: 5) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.zoomOutTimeline()
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Reducir zoom temporal del timeline")

                    Slider(value: $viewModel.timelineZoom, in: 15...350)
                        .frame(width: 90)
                        .controlSize(.mini)
                        .tint(.secondary)

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.zoomInTimeline()
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .help("Aumentar zoom temporal del timeline")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Contenedor principal responsivo
            GeometryReader { geo in
                let availableLaneWidth = max(geo.size.width - headerWidth, 300)
                let contentDurationWidth = CGFloat(viewModel.project.totalDuration) * CGFloat(viewModel.timelineZoom) + 150
                let effectiveLaneWidth = max(availableLaneWidth, contentDurationWidth)

                if viewModel.project.tracks.isEmpty || viewModel.project.tracks.allSatisfy({ $0.clips.isEmpty }) {
                    // Estado vacío elegante: No hay pistas ni clips en la línea de tiempo
                    VStack(spacing: 12) {
                        Image(systemName: isTimelineDropTargeted ? "arrow.down.circle.fill" : "film.stack")
                            .font(.system(size: 32))
                            .foregroundColor(isTimelineDropTargeted ? .accentColor : .secondary)

                        VStack(spacing: 3) {
                            Text("Línea de tiempo vacía")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Arrastra videos o audios aquí para comenzar, o crea una pista")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 10) {
                            Button("+ Pista Video (V1)") {
                                viewModel.addTrack(kind: .video)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("+ Pista Audio (A1)") {
                                viewModel.addTrack(kind: .audio)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.underPageBackgroundColor).opacity(0.4))
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTimelineDropTargeted) { providers in
                        handleDropToEmptyTimeline(providers: providers)
                    }
                } else {
                    // Vista completa con Regla Temporal FIJA arriba y desplazamiento sincronizado
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 1. REGLA TEMPORAL SUPERIOR FIJA (No se desplaza al hacer scroll vertical en pistas)
                            ZStack(alignment: .topLeading) {
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color(NSColor.controlBackgroundColor))
                                        .frame(width: headerWidth, height: 26)
                                        .overlay(
                                            Text("PISTAS")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 10),
                                            alignment: .leading
                                        )
                                        .overlay(
                                            Rectangle()
                                                .frame(width: 1)
                                                .foregroundColor(DesignSystem.border),
                                            alignment: .trailing
                                        )

                                    TimelineRulerView(
                                        duration: max(viewModel.project.totalDuration, Double(effectiveLaneWidth) / viewModel.timelineZoom),
                                        zoom: viewModel.timelineZoom,
                                        onSeek: { newTime in
                                            viewModel.playbackEngine.seek(to: newTime)
                                        }
                                    )
                                    .frame(width: effectiveLaneWidth, height: 26)
                                }

                                // Indicador / Aguja superior roja del Playhead en la regla fija
                                let playheadX = headerWidth + CGFloat(viewModel.playbackEngine.currentTime) * CGFloat(viewModel.timelineZoom)
                                PlayheadNeedleShape()
                                    .fill(DesignSystem.playhead)
                                    .frame(width: 14, height: 14)
                                    .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                                    .position(x: playheadX, y: 19)
                                    .allowsHitTesting(false)
                            }
                            .frame(width: effectiveLaneWidth + headerWidth, height: 26)
                            .zIndex(100)

                            // Línea divisoria bajo la regla fija
                            Rectangle()
                                .fill(DesignSystem.border)
                                .frame(width: effectiveLaneWidth + headerWidth, height: 1)
                                .zIndex(99)

                            // 2. PISTAS CON SCROLL VERTICAL INDEPENDIENTE
                            let tracksTotalHeight = CGFloat(viewModel.project.tracks.count) * viewModel.trackHeight
                            ScrollView(.vertical, showsIndicators: false) {
                                ZStack(alignment: .topLeading) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(viewModel.project.tracks) { track in
                                            TimelineTrackView(
                                                track: track,
                                                viewModel: viewModel,
                                                timelineWidth: effectiveLaneWidth
                                            )
                                        }
                                    }

                                    // Línea de Guía Magnética (Snap Guide Line entre capas)
                                    if let snapTime = viewModel.snapGuideLineTime {
                                        let snapX = headerWidth + CGFloat(snapTime) * CGFloat(viewModel.timelineZoom)
                                        Rectangle()
                                            .fill(Color.primary.opacity(0.8))
                                            .frame(width: 2)
                                            .frame(height: max(geo.size.height - 27, tracksTotalHeight))
                                            .position(x: snapX, y: max(geo.size.height - 27, tracksTotalHeight) / 2)
                                            .shadow(color: Color.primary.opacity(0.6), radius: 3)
                                            .allowsHitTesting(false)
                                    }

                                    // Línea vertical roja del Playhead a través de todas las pistas
                                    let playheadX = headerWidth + CGFloat(viewModel.playbackEngine.currentTime) * CGFloat(viewModel.timelineZoom)
                                    Rectangle()
                                        .fill(DesignSystem.playhead)
                                        .frame(width: 1.5)
                                        .frame(height: max(geo.size.height - 27, tracksTotalHeight))
                                        .position(x: playheadX, y: max(geo.size.height - 27, tracksTotalHeight) / 2)
                                        .allowsHitTesting(false)
                                }
                                .frame(width: effectiveLaneWidth + headerWidth, alignment: .leading)
                            }
                            .frame(maxHeight: .infinity)
                        }
                        .frame(width: effectiveLaneWidth + headerWidth, alignment: .leading)
                    }
                    .background(Color(NSColor.underPageBackgroundColor))
                    // Gesto de Pellizco en el Trackpad para Zoom del Timeline (Pinch to zoom)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                if lastPinchZoom == 60.0 {
                                    lastPinchZoom = viewModel.timelineZoom
                                }
                                let proposed = lastPinchZoom * Double(value)
                                viewModel.timelineZoom = min(max(proposed, 15.0), 380.0)
                            }
                            .onEnded { _ in
                                lastPinchZoom = viewModel.timelineZoom
                            }
                    )
                }
            }
        }
    }

    private func handleDropToEmptyTimeline(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = item as? URL ?? (item as? Data).flatMap({ URL(dataRepresentation: $0, relativeTo: nil) }) {
                        DispatchQueue.main.async {
                            viewModel.importFiles(urls: [url])
                            if let newAsset = viewModel.project.assets.last {
                                viewModel.addClipToTimeline(assetId: newAsset.id)
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
