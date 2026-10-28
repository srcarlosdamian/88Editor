import SwiftUI
import AppKit

/// Sidebar Derecho: Inspector Contextual
/// Diseño uniforme y elegante con separadores limpios (sin cajas divisorias).
/// Expone parámetros de clip (transformación, opacidad, audio, texto) y parámetros editables de proyecto.
public struct InspectorView: View {
    @ObservedObject var viewModel: EditorViewModel

    public var body: some View {
        VStack(spacing: 0) {
            // Selector de Pestañas: [ Inspector | Historial (Ctrl+Z) ]
            HStack(spacing: 4) {
                Button {
                    viewModel.activeRightTab = .inspector
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text("Inspector")
                            .font(.system(size: 11, weight: viewModel.activeRightTab == .inspector ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(viewModel.activeRightTab == .inspector ? Color.accentColor.opacity(0.18) : Color.clear)
                    .foregroundColor(viewModel.activeRightTab == .inspector ? .accentColor : .secondary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.activeRightTab = .history
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                        Text("Historial")
                            .font(.system(size: 11, weight: viewModel.activeRightTab == .history ? .semibold : .regular))

                        Text("\(viewModel.currentHistoryIndex + 1)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(viewModel.activeRightTab == .history ? Color.accentColor : Color.secondary.opacity(0.25))
                            .foregroundColor(viewModel.activeRightTab == .history ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(viewModel.activeRightTab == .history ? Color.accentColor.opacity(0.18) : Color.clear)
                    .foregroundColor(viewModel.activeRightTab == .history ? .accentColor : .secondary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .padding(6)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Contenido dinámico según la pestaña activa
            if viewModel.activeRightTab == .history {
                HistoryPanelView(viewModel: viewModel)
            } else {
                inspectorBody
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // Cuerpo principal del Inspector
    @ViewBuilder
    private var inspectorBody: some View {
        VStack(spacing: 0) {
            // Sub-cabecera contextual
            HStack {
                Label(viewModel.selectedClip != nil ? "Propiedades de Capa" : "Propiedades de Proyecto",
                      systemImage: viewModel.selectedClip != nil ? "slider.horizontal.3" : "info.circle")
                    .font(DesignSystem.sectionTitle)
                    .foregroundColor(.primary)

                Spacer()

                if viewModel.selectedClip != nil {
                    Button("Deseleccionar") {
                        viewModel.selectedClipId = nil
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let clip = viewModel.selectedClip {
                        clipInspectorContent(clip: clip)
                    } else {
                        projectInspectorContent()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Inspector de Clip Seleccionado (100% Contextual)
    @ViewBuilder
    private func clipInspectorContent(clip: TimelineClip) -> some View {
        let isAudioOnly = viewModel.isClipAudioOnly(clip)
        let isVisual = viewModel.isClipVisual(clip)
        let hasAudio = viewModel.clipHasAudio(clip)
        let isCroppable = viewModel.isClipCroppable(clip)

        // Alerta de Archivo No Encontrado / Eliminado del Disco (Offline Media)
        if let asset = viewModel.asset(for: clip), asset.isMissing {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.primary)
                    Text("Archivo no encontrado")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                }

                Text("El archivo original no existe o fue eliminado de su ubicación en el disco.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Button {
                    viewModel.reconnectAsset(id: asset.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                        Text("Reconectar archivo...")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(10)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignSystem.border, lineWidth: 1)
            )

            Divider().foregroundColor(DesignSystem.border)
        }

        // 1. IDENTIFICADOR CONTEXTUAL
        VStack(alignment: .leading, spacing: 6) {
            Text("IDENTIFICADOR")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Image(systemName: isAudioOnly ? "waveform" : (clip.shapeType != nil ? "circle.fill" : (clip.textOverlay != nil ? "character.textbox" : "film")))
                    .foregroundColor(isAudioOnly ? .teal : .secondary)
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 1) {
                    Text(clip.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(isAudioOnly ? "Capa de Audio" : (clip.shapeType != nil ? "Forma Vectorial" : (clip.textOverlay != nil ? "Texto Vectorial" : "Capa Visual")))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }

        Divider().foregroundColor(DesignSystem.border)

        // 2. TEXTO Y TIPOGRAFÍA (Sólo si es objeto de texto)
        if clip.textOverlay != nil || viewModel.asset(for: clip)?.mediaType == .text {
            VStack(alignment: .leading, spacing: 8) {
                Label("Texto y Tipografía", systemImage: "character")
                    .font(.system(size: 11, weight: .bold))

                TextField("Texto...", text: Binding(
                    get: { viewModel.selectedClip?.textOverlay ?? "" },
                    set: { val in
                        viewModel.updateSelectedClip { $0.textOverlay = val }
                    }
                ))
                .textFieldStyle(.roundedBorder)

                ColorPicker("Color de Texto", selection: Binding(
                    get: { Color(hex: clip.textColorHex ?? "#FF3B30") },
                    set: { newCol in
                        viewModel.updateSelectedClip { $0.textColorHex = newCol.toHex() }
                    }
                ))

                TransformControlRow(
                    title: "Tamaño Fuente",
                    value: Binding(
                        get: { viewModel.selectedClip?.fontSize ?? 54.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.fontSize = val }
                        }
                    ),
                    range: 12...220,
                    step: 1.0,
                    unit: " pt",
                    defaultValue: 54.0
                )

                HStack {
                    Text(clip.fontName ?? "Fuente del sistema")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button("Elegir Fuente...") {
                        viewModel.isFontPickerPresented = true
                    }
                    .controlSize(.small)
                }
            }

            Divider().foregroundColor(DesignSystem.border)
        }

        // 3. FORMA VECTORIAL (Sólo si es una forma vectorial)
        if let shape = clip.shapeType {
            VStack(alignment: .leading, spacing: 10) {
                Label("Forma Vectorial", systemImage: "circle.fill")
                    .font(.system(size: 11, weight: .bold))

                Picker("Tipo", selection: Binding(
                    get: { shape },
                    set: { newShape in
                        viewModel.updateSelectedClip { $0.shapeType = newShape }
                    }
                )) {
                    Text("Círculo").tag("circle")
                    Text("Rectángulo").tag("rectangle")
                    Text("Rectángulo Redondeado").tag("roundedRectangle")
                    Text("Estrella").tag("star")
                    Text("Triángulo").tag("triangle")
                }

                ColorPicker("Color de Relleno", selection: Binding(
                    get: { Color(hex: clip.fillColorHex ?? "#FF3B30") },
                    set: { newCol in
                        viewModel.updateSelectedClip { $0.fillColorHex = newCol.toHex() }
                    }
                ))

                ColorPicker("Color de Borde", selection: Binding(
                    get: { Color(hex: clip.strokeColorHex ?? "#FFFFFF") },
                    set: { newCol in
                        viewModel.updateSelectedClip { $0.strokeColorHex = newCol.toHex() }
                    }
                ))

                TransformControlRow(
                    title: "Grosor de Borde",
                    value: Binding(
                        get: { clip.strokeWidth ?? 0.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.strokeWidth = val }
                        }
                    ),
                    range: 0...30,
                    step: 1.0,
                    unit: " px",
                    defaultValue: 0.0
                )
            }

            Divider().foregroundColor(DesignSystem.border)
        }

        // 4. TRANSFORMACIÓN BÁSICA (SÓLO para elementos VISUALES; NUNCA para audio)
        if isVisual {
            VStack(alignment: .leading, spacing: 10) {
                Label("Transformación Básica", systemImage: "crop.rotate")
                    .font(.system(size: 11, weight: .bold))

                TransformControlRow(
                    title: "Posición X",
                    value: Binding(
                        get: { viewModel.selectedClip?.positionX ?? 0.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.positionX = val }
                        }
                    ),
                    range: -800...800,
                    step: 1.0,
                    unit: " px",
                    defaultValue: 0.0
                )

                TransformControlRow(
                    title: "Posición Y",
                    value: Binding(
                        get: { viewModel.selectedClip?.positionY ?? 0.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.positionY = val }
                        }
                    ),
                    range: -800...800,
                    step: 1.0,
                    unit: " px",
                    defaultValue: 0.0
                )

                TransformControlRow(
                    title: "Escala",
                    value: Binding(
                        get: { (viewModel.selectedClip?.scale(at: viewModel.currentClipRelativeTime) ?? 1.0) * 100.0 },
                        set: { val in
                            viewModel.updateAnimatableProperty(.scale, value: val / 100.0)
                        }
                    ),
                    range: 10...400,
                    step: 1.0,
                    unit: "%",
                    defaultValue: 100.0,
                    isKeyframeActive: viewModel.isKeyframeActive(for: .scale),
                    hasAnyKeyframes: viewModel.hasAnyKeyframes(for: .scale),
                    onToggleKeyframe: {
                        viewModel.toggleKeyframe(for: .scale)
                    }
                )

                TransformControlRow(
                    title: "Rotación",
                    value: Binding(
                        get: { viewModel.selectedClip?.rotation(at: viewModel.currentClipRelativeTime) ?? 0.0 },
                        set: { val in
                            viewModel.updateAnimatableProperty(.rotation, value: val)
                        }
                    ),
                    range: -180...180,
                    step: 1.0,
                    unit: "°",
                    defaultValue: 0.0,
                    isKeyframeActive: viewModel.isKeyframeActive(for: .rotation),
                    hasAnyKeyframes: viewModel.hasAnyKeyframes(for: .rotation),
                    onToggleKeyframe: {
                        viewModel.toggleKeyframe(for: .rotation)
                    }
                )
            }

            Divider().foregroundColor(DesignSystem.border)

            // 5. COMPOSICIÓN (Opacidad) (SÓLO para elementos VISUALES; NUNCA para audio)
            VStack(alignment: .leading, spacing: 10) {
                Label("Composición", systemImage: "circle.lefthalf.filled")
                    .font(.system(size: 11, weight: .bold))

                TransformControlRow(
                    title: "Opacidad",
                    value: Binding(
                        get: { (viewModel.selectedClip?.opacity(at: viewModel.currentClipRelativeTime) ?? 1.0) * 100.0 },
                        set: { val in
                            viewModel.updateAnimatableProperty(.opacity, value: val / 100.0)
                        }
                    ),
                    range: 0...100,
                    step: 1.0,
                    unit: "%",
                    defaultValue: 100.0,
                    isKeyframeActive: viewModel.isKeyframeActive(for: .opacity),
                    hasAnyKeyframes: viewModel.hasAnyKeyframes(for: .opacity),
                    onToggleKeyframe: {
                        viewModel.toggleKeyframe(for: .opacity)
                    }
                )
            }

            Divider().foregroundColor(DesignSystem.border)
        }

        // 6. RECORTE ESPACIAL (Crop) (SÓLO para imágenes y videos; NUNCA para audio, texto o formas)
        if isCroppable {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Recorte Espacial (Crop)", systemImage: "crop")
                        .font(.system(size: 11, weight: .bold))

                    Spacer()

                    if clip.hasCrop {
                        Button("Restablecer") {
                            viewModel.updateSelectedClip {
                                $0.cropLeft = 0.0
                                $0.cropRight = 0.0
                                $0.cropTop = 0.0
                                $0.cropBottom = 0.0
                            }
                            viewModel.recordHistory(title: "Restablecer recorte", icon: "crop")
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }

                TransformControlRow(
                    title: "Izquierda",
                    value: Binding(
                        get: { (viewModel.selectedClip?.cropLeft ?? 0.0) * 100.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.cropLeft = val / 100.0 }
                        }
                    ),
                    range: 0...48,
                    step: 1.0,
                    unit: "%",
                    defaultValue: 0.0
                )

                TransformControlRow(
                    title: "Derecha",
                    value: Binding(
                        get: { (viewModel.selectedClip?.cropRight ?? 0.0) * 100.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.cropRight = val / 100.0 }
                        }
                    ),
                    range: 0...48,
                    step: 1.0,
                    unit: "%",
                    defaultValue: 0.0
                )

                TransformControlRow(
                    title: "Arriba",
                    value: Binding(
                        get: { (viewModel.selectedClip?.cropTop ?? 0.0) * 100.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.cropTop = val / 100.0 }
                        }
                    ),
                    range: 0...48,
                    step: 1.0,
                    unit: "%",
                    defaultValue: 0.0
                )

                TransformControlRow(
                    title: "Abajo",
                    value: Binding(
                        get: { (viewModel.selectedClip?.cropBottom ?? 0.0) * 100.0 },
                        set: { val in
                            viewModel.updateSelectedClip { $0.cropBottom = val / 100.0 }
                        }
                    ),
                    range: 0...48,
                    step: 1.0,
                    unit: "%",
                    defaultValue: 0.0
                )

                Button {
                    viewModel.openCropModal(for: clip)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "crop")
                            .font(.system(size: 10))
                        Text("Ventana de Recorte Interactivo...")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider().foregroundColor(DesignSystem.border)
        }

        // 7. AUDIO (Volumen con fotogramas clave y silenciamiento) (SÓLO para audios o videos con audio)
        if hasAudio {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Audio", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .bold))

                    Spacer()

                    Button {
                        viewModel.updateSelectedClip { $0.isMuted.toggle() }
                    } label: {
                        Image(systemName: (viewModel.selectedClip?.isMuted ?? false) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundColor((viewModel.selectedClip?.isMuted ?? false) ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help((viewModel.selectedClip?.isMuted ?? false) ? "Activar audio" : "Silenciar clip")
                }

                TransformControlRow(
                    title: "Volumen",
                    value: Binding(
                        get: { (viewModel.selectedClip?.volume(at: viewModel.currentClipRelativeTime) ?? 1.0) * 100.0 },
                        set: { val in
                            viewModel.updateAnimatableProperty(.volume, value: val / 100.0)
                        }
                    ),
                    range: 0...100,
                    step: 1.0,
                    unit: "%",
                    defaultValue: 100.0,
                    isKeyframeActive: viewModel.isKeyframeActive(for: .volume),
                    hasAnyKeyframes: viewModel.hasAnyKeyframes(for: .volume),
                    onToggleKeyframe: {
                        viewModel.toggleKeyframe(for: .volume)
                    }
                )
            }

            Divider().foregroundColor(DesignSystem.border)
        }

        // 8. TEMPORIZACIÓN Y RECORTE
        VStack(alignment: .leading, spacing: 8) {
            Label("Temporización y Recorte", systemImage: "clock.arrow.2.circlepath")
                .font(.system(size: 11, weight: .bold))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IN").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                    Text(String(format: "%.2f s", clip.sourceIn)).font(DesignSystem.monoFont)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("OUT").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                    Text(String(format: "%.2f s", clip.sourceOut)).font(DesignSystem.monoFont)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("DURACIÓN").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                    Text(String(format: "%.2f s", clip.duration)).font(DesignSystem.monoFont)
                }
            }
        }
    }

    // MARK: - Inspector de Proyecto
    @ViewBuilder
    private func projectInspectorContent() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // PROYECTO ACTUAL
            VStack(alignment: .leading, spacing: 6) {
                Text("PROYECTO ACTUAL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                    TextField("Nombre del proyecto", text: $viewModel.project.projectName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                }

                HStack {
                    Text("Formato .88proj")
                        .font(DesignSystem.monoFont)
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.hasUnsavedChanges {
                        Text("Modificado")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider().foregroundColor(DesignSystem.border)

            // PARÁMETROS DE VIDEO Y AJUSTES DE PROYECTO
            VStack(alignment: .leading, spacing: 12) {
                Text("PARÁMETROS DE VIDEO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Formato y Preset:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.project.configuration.preset.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }

                    HStack {
                        Text("Resolución:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.project.configuration.resolutionDisplayString)
                            .font(DesignSystem.monoFont)
                    }

                    HStack {
                        Text("Tasa de Cuadros:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.project.configuration.framerate.displayName)
                            .font(.system(size: 11))
                    }

                    HStack {
                        Text("Color del Lienzo:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Circle()
                            .fill(viewModel.project.configuration.backgroundColor.swiftUIColor)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)

                // Botón Editar Tamaño y Ajustes en Modal con confirmación
                Button {
                    viewModel.isProjectSettingsSheetPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text("Editar Tamaño y Ajustes...")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Modificar dimensiones, resolución y tasa de cuadros en modal")
            }

            Divider().foregroundColor(DesignSystem.border)

            // ESTADÍSTICAS
            VStack(alignment: .leading, spacing: 8) {
                Text("ESTADÍSTICAS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                HStack {
                    Text("Archivos vinculados:")
                    Spacer()
                    Text("\(viewModel.project.assets.count)")
                        .font(DesignSystem.monoFont)
                }

                HStack {
                    Text("Capas activas:")
                    Spacer()
                    Text("\(viewModel.project.tracks.count)")
                        .font(DesignSystem.monoFont)
                }

                HStack {
                    Text("Clips en línea de tiempo:")
                    Spacer()
                    let totalClips = viewModel.project.tracks.flatMap { $0.clips }.count
                    Text("\(totalClips)")
                        .font(DesignSystem.monoFont)
                }
            }
        }
    }
}
