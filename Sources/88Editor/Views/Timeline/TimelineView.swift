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

                // Botón Añadir Capa (El concepto unificado de 88 Editor son Capas)
                Button {
                    viewModel.addTrack(kind: .video)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 11))
                        Text("Capa")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Añadir nueva capa al proyecto")

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

                // Herramientas de Área de Trabajo y Rango de Renderizado (Puntos In y Out)
                HStack(spacing: 4) {
                    Button {
                        viewModel.setWorkAreaInAtPlayhead()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.right.to.line")
                                .font(.system(size: 9))
                            Text("In (I)")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Fijar punto de entrada para recortar renderizado al cabezal actual (Tecla I)")

                    Button {
                        viewModel.setWorkAreaOutAtPlayhead()
                    } label: {
                        HStack(spacing: 2) {
                            Text("Out (O)")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "arrow.left.to.line")
                                .font(.system(size: 9))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Fijar punto de salida para recortar renderizado al cabezal actual (Tecla O)")

                    if viewModel.project.hasCustomWorkArea {
                        Button {
                            viewModel.resetWorkArea()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Restablecer rango de renderizado a todo el proyecto (⌥X)")

                        Text(String(format: "%.1fs - %.1fs (%.1fs)", viewModel.project.effectiveRenderIn, viewModel.project.effectiveRenderOut, viewModel.project.effectiveRenderDuration))
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.primary)
                            .cornerRadius(4)
                    }
                }

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

                // Duración Total del Timeline y Acceso Rápido para Añadir Tiempo
                HStack(spacing: 6) {
                    Menu {
                        Button("+ 5 segundos") { viewModel.addProjectDuration(seconds: 5) }
                        Button("+ 10 segundos") { viewModel.addProjectDuration(seconds: 10) }
                        Button("+ 30 segundos") { viewModel.addProjectDuration(seconds: 30) }
                        Button("+ 1 minuto") { viewModel.addProjectDuration(seconds: 60) }
                        Divider()
                        Button("15s (Reels / TikTok / Shorts)") { viewModel.setProjectDuration(seconds: 15) }
                        Button("30s (Story / Comercial)") { viewModel.setProjectDuration(seconds: 30) }
                        Button("60s (1 minuto)") { viewModel.setProjectDuration(seconds: 60) }
                        Button("120s (2 minutos)") { viewModel.setProjectDuration(seconds: 120) }
                        Button("300s (5 minutos)") { viewModel.setProjectDuration(seconds: 300) }
                        Divider()
                        Button("Ajustes del Proyecto...") { viewModel.isProjectSettingsSheetPresented = true }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("Duración: \(String(format: "%.0fs", viewModel.project.totalDuration))")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Duración total de la línea de tiempo. Clic para cambiar o añadir tiempo.")

                    Button("+10s") {
                        viewModel.addProjectDuration(seconds: 10)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .font(.system(size: 9, weight: .semibold))
                    .help("Añadir 10 segundos adicionales a la línea de tiempo")
                }

                Divider().frame(height: 16)

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

                // Control interactivo de Altura de Capas (32px a 200px)
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.split.3x1")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .help("Altura de las capas")

                    Slider(value: $viewModel.trackHeight, in: 32...200)
                        .frame(width: 80)
                        .controlSize(.mini)
                        .tint(.secondary)
                        .help("Ajustar altura de las capas (\(Int(viewModel.trackHeight))px)")
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
                            .foregroundColor(isTimelineDropTargeted ? .primary : .secondary)

                        VStack(spacing: 3) {
                            Text("Línea de tiempo vacía")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Arrastra videos o audios aquí para comenzar, o crea una pista")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 10) {
                            Button("+ Nueva Capa") {
                                viewModel.addTrack(kind: .video)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Importar Medios...") {
                                viewModel.promptImportMediaPanel()
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
                                            Text("CAPAS")
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
                                        duration: viewModel.project.totalDuration,
                                        zoom: viewModel.timelineZoom,
                                        workAreaIn: viewModel.project.workAreaIn,
                                        workAreaOut: viewModel.project.workAreaOut,
                                        onSeek: { newTime in
                                            viewModel.playbackEngine.seek(to: newTime)
                                        },
                                        onSetWorkAreaIn: { newIn in
                                            viewModel.setWorkAreaIn(to: newIn)
                                        },
                                        onSetWorkAreaOut: { newOut in
                                            viewModel.setWorkAreaOut(to: newOut)
                                        },
                                        onShiftWorkArea: { delta in
                                            viewModel.shiftWorkArea(by: delta)
                                        },
                                        onResetWorkArea: {
                                            viewModel.resetWorkArea()
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
                                    // Fondo interactivo: clic o arrastre en área vacía mueve el cabezal (Seek) y deselecciona clips
                                    Color.clear
                                        .frame(width: effectiveLaneWidth + headerWidth, height: max(geo.size.height - 27, tracksTotalHeight + 120))
                                        .contentShape(Rectangle())
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    let trackLaneX = value.location.x - headerWidth
                                                    let clickedTime = max(0.0, Double(trackLaneX) / viewModel.timelineZoom)
                                                    viewModel.playbackEngine.seek(to: clickedTime)
                                                    viewModel.selectedClipId = nil
                                                    viewModel.selectedTrackId = nil
                                                }
                                        )

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

                                    // Zona oscurecida posterior al fin del proyecto y delimitador vertical a través de las capas
                                    let projEndTrackX = headerWidth + CGFloat(viewModel.project.totalDuration) * CGFloat(viewModel.timelineZoom)
                                    let tracksAreaHeight = max(geo.size.height - 27, tracksTotalHeight + 120)
                                    let outOfBoundsTracksWidth = max(0, (effectiveLaneWidth + headerWidth) - projEndTrackX)

                                    if outOfBoundsTracksWidth > 0 {
                                        // Fondo oscurecido para zona fuera de la duración del proyecto
                                        Rectangle()
                                            .fill(Color.black.opacity(0.38))
                                            .frame(width: outOfBoundsTracksWidth, height: tracksAreaHeight)
                                            .position(x: projEndTrackX + outOfBoundsTracksWidth / 2, y: tracksAreaHeight / 2)
                                            .allowsHitTesting(false)

                                        // Línea vertical que marca el fin de la duración a través de todas las pistas
                                        Rectangle()
                                            .fill(Color.white.opacity(0.40))
                                            .frame(width: 1.5, height: tracksAreaHeight)
                                            .position(x: projEndTrackX, y: tracksAreaHeight / 2)
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
        // Atajos de teclado del Timeline: I (Punto Entrada), O (Punto Salida), ⌥X (Restablecer Rango)
        .background(
            ZStack {
                Button("") { viewModel.setWorkAreaInAtPlayhead() }
                    .keyboardShortcut("i", modifiers: [])
                Button("") { viewModel.setWorkAreaOutAtPlayhead() }
                    .keyboardShortcut("o", modifiers: [])
                Button("") { viewModel.resetWorkArea() }
                    .keyboardShortcut("x", modifiers: [.option])
            }
            .opacity(0)
        )
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
