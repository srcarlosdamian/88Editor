import SwiftUI
import AVFoundation

/// Modal Profesional de Exportación y Renderizado con Previsualización en Vivo, Reproductor Integrado y Resolución Fija del Proyecto
public struct ExportSettingsSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    // Configuración de formato
    @State private var mediaType: ExportMediaType = .videoAndAudio
    @State private var container: ExportContainer = .mp4
    @State private var quality: ExportQuality = .high
    @State private var exportRange: ExportRangeOption = .workAreaIfActive

    // Estado del reproductor de previsualización
    @State private var previewTime: Double = 0.0
    @State private var isPlayingPreview: Bool = false
    @State private var previewTimer: Timer? = nil

    public enum ExportRangeOption: String, CaseIterable, Identifiable {
        case workAreaIfActive = "Área de Trabajo (Puntos In / Out)"
        case entireProject = "Línea de Tiempo Completa"

        public var id: String { rawValue }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera superior
            HStack(spacing: 12) {
                AppLogoIconView(size: 30, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Exportar y Renderizar")
                        .font(.system(size: 14, weight: .bold))
                    let config = viewModel.project.configuration
                    Text("\(viewModel.project.projectName) • \(Int(config.width))×\(Int(config.height)) • \(config.framerate.shortName)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    stopPreview()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(DesignSystem.border), alignment: .bottom)

            // Contenedor principal: Previsualización a la izquierda + Ajustes a la derecha
            HStack(spacing: 0) {
                // COLUMNA IZQUIERDA: Visor y Reproductor de Previsualización
                VStack(spacing: 10) {
                    // Visor de video/imagen del proyecto
                    ZStack {
                        Color.black

                        // Capas activas en el tiempo actual de previsualización
                        GeometryReader { previewGeo in
                            let targetAspect = viewModel.project.configuration.aspectRatio
                            let (fitW, fitH) = calculateFitDimensions(
                                containerW: previewGeo.size.width,
                                containerH: previewGeo.size.height,
                                aspect: targetAspect
                            )

                            ZStack {
                                viewModel.project.configuration.backgroundColor.swiftUIColor

                                ForEach(viewModel.activeVisualLayersAtPlayhead) { layer in
                                    renderPreviewLayer(layer: layer, fitW: fitW, fitH: fitH)
                                }
                            }
                            .frame(width: fitW, height: fitH)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .position(x: previewGeo.size.width / 2, y: previewGeo.size.height / 2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DesignSystem.border, lineWidth: 1)
                    )

                    // Barra del Reproductor de Previsualización
                    VStack(spacing: 6) {
                        // Barra de progreso interactiva (Scrubber)
                        let activeDuration = max(viewModel.project.totalDuration, 1.0)
                        Slider(value: $previewTime, in: 0...activeDuration) { _ in
                            viewModel.playbackEngine.seek(to: previewTime)
                        }
                        .controlSize(.small)
                        .tint(Color.white.opacity(0.85))

                        // Controles de transporte y código de tiempo
                        HStack(spacing: 12) {
                            // Rebobinar al punto In
                            Button {
                                let inT = (exportRange == .workAreaIfActive) ? viewModel.project.effectiveRenderIn : 0.0
                                previewTime = inT
                                viewModel.playbackEngine.seek(to: inT)
                            } label: {
                                Image(systemName: "backward.end.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Ir al punto de inicio (In)")

                            // Play / Pausa
                            Button {
                                togglePreviewPlayback()
                            } label: {
                                Image(systemName: isPlayingPreview ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                            .help("Reproducir / Pausa previsualización (Espacio)")

                            Spacer()

                            // Códigos de tiempo
                            HStack(spacing: 4) {
                                Text(formatTime(previewTime))
                                    .font(DesignSystem.monoFont)
                                    .foregroundColor(.primary)

                                Text("/")
                                    .font(DesignSystem.monoFont)
                                    .foregroundColor(.secondary)

                                Text(formatTime(activeDuration))
                                    .font(DesignSystem.monoFont)
                                    .foregroundColor(.secondary)
                            }

                            // Rango efectivo a renderizar
                            let (_, _, dur) = calculateActiveRange()
                            Text("Render: \(String(format: "%.1fs", dur))")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.10))
                                .cornerRadius(4)
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(DesignSystem.border, lineWidth: 1))
                }
                .padding(18)
                .frame(width: 380)

                // Separador vertical
                Rectangle()
                    .fill(DesignSystem.border)
                    .frame(width: 1)

                // COLUMNA DERECHA: Ajustes de Exportación
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            formatSettingsView()
                        }
                        .padding(20)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider().foregroundColor(DesignSystem.border)

            // Barra inferior de botones de acción
            HStack {
                Button("Cancelar") {
                    stopPreview()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Exportar y Guardar...") {
                    stopPreview()
                    executeExport()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 780, height: 530)
        .background(Color(NSColor.underPageBackgroundColor))
        .onAppear {
            previewTime = viewModel.playbackEngine.currentTime
            if viewModel.project.hasCustomWorkArea {
                exportRange = .workAreaIfActive
            }
        }
        .onDisappear {
            stopPreview()
        }
    }

    // MARK: - Panel de Configuración de Formato y Resolución
    @ViewBuilder
    private func formatSettingsView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Tipo de salida
            VStack(alignment: .leading, spacing: 6) {
                Text("TIPO DE SALIDA")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("", selection: $mediaType) {
                    ForEach(ExportMediaType.allCases) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: mediaType) { newType in
                    if newType == .audioOnly {
                        if container != .m4a && container != .wav { container = .m4a }
                    } else {
                        if container != .mp4 && container != .mov { container = .mp4 }
                    }
                }
            }

            // 2. Contenedor de archivo
            VStack(alignment: .leading, spacing: 6) {
                Text("CONTENEDOR / FORMATO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("", selection: $container) {
                    if mediaType == .videoAndAudio {
                        Text("MP4 (.mp4) - Compatible Universal").tag(ExportContainer.mp4)
                        Text("QuickTime (.mov) - Alta Fidelidad Apple").tag(ExportContainer.mov)
                    } else {
                        Text("Audio AAC (.m4a) - Estándar Comprimido").tag(ExportContainer.m4a)
                        Text("Audio PCM (.wav) - Sin Compresión / Estudio").tag(ExportContainer.wav)
                    }
                }
                .labelsHidden()
            }

            // 3. Calidad de compresión (Alta por defecto)
            VStack(alignment: .leading, spacing: 6) {
                Text("CALIDAD DE EXPORTACIÓN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("", selection: $quality) {
                    Text("Alta (Recomendada)").tag(ExportQuality.high)
                    Text("Media (Archivo Ligero)").tag(ExportQuality.balanced)
                    Text("Máxima (Apple ProRes Master)").tag(ExportQuality.maximum)
                }
                .labelsHidden()

                Text(quality.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            // 4. Rango de renderizado
            VStack(alignment: .leading, spacing: 6) {
                Text("RANGO A RENDERIZAR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("", selection: $exportRange) {
                    ForEach(ExportRangeOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if exportRange == .workAreaIfActive && viewModel.project.hasCustomWorkArea {
                    Text("Renderizará desde In (\(formatTime(viewModel.project.effectiveRenderIn))) hasta Out (\(formatTime(viewModel.project.effectiveRenderOut)))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // 5. Resolución y FPS Nativos del Proyecto (Fijo y por defecto)
            VStack(alignment: .leading, spacing: 6) {
                Text("RESOLUCIÓN Y TASA DE CUADROS (ORIGINAL DEL PROYECTO)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                let config = viewModel.project.configuration
                HStack(spacing: 12) {
                    Image(systemName: "aspectratio")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(config.width)) × \(Int(config.height)) (\(config.preset.rawValue))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(config.framerate.displayName) • Para modificar tamaño edita Ajustes del Proyecto")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DesignSystem.border, lineWidth: 1))
            }

            // 6. Estimación de peso del archivo resultante
            HStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PESO ESTIMADO DEL ARCHIVO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    let estimatedBytes = calculateEstimatedSize()
                    Text("~ \(FileSizeEstimator.formatBytes(estimatedBytes))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Spacer()
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DesignSystem.border, lineWidth: 1))
        }
    }

    // MARK: - Previsualización de Capas
    @ViewBuilder
    private func renderPreviewLayer(layer: EditorViewModel.VisualLayerItem, fitW: CGFloat, fitH: CGFloat) -> some View {
        let clip = layer.clip
        let dynamicOpacity = clip.opacity(at: previewTime)
        let dynamicScale = clip.scale(at: previewTime)
        let dynamicRotation = clip.rotation(at: previewTime)

        Group {
            if let shape = clip.shapeType {
                renderPreviewVectorShape(shape: shape, fillHex: clip.fillColorHex ?? "#FF3B30")
                    .frame(width: 140, height: 140)
            } else if let asset = layer.asset, asset.mediaType == .image, let img = NSImage(contentsOf: asset.fileURL) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(CropRectShape(left: clip.cropLeft, right: clip.cropRight, top: clip.cropTop, bottom: clip.cropBottom))
            } else if let asset = layer.asset, asset.mediaType == .video {
                ClipVideoPlayerView(clip: clip, asset: asset, viewModel: viewModel)
                    .clipShape(CropRectShape(left: clip.cropLeft, right: clip.cropRight, top: clip.cropTop, bottom: clip.cropBottom))
            } else if let text = clip.textOverlay, !text.isEmpty {
                Text(text)
                    .font(.system(size: CGFloat(clip.fontSize ?? 48) * 0.45, weight: .bold))
                    .foregroundColor(Color(hex: clip.textColorHex ?? "#FFFFFF"))
                    .multilineTextAlignment(.center)
            }
        }
        .offset(x: CGFloat(clip.positionX) * (fitW / 1920.0), y: CGFloat(clip.positionY) * (fitH / 1080.0))
        .scaleEffect(dynamicScale)
        .rotationEffect(.degrees(dynamicRotation))
        .opacity(dynamicOpacity)
    }

    @ViewBuilder
    private func renderPreviewVectorShape(shape: String, fillHex: String) -> some View {
        let fill = Color(hex: fillHex)
        switch shape {
        case "circle": Circle().fill(fill)
        case "star": StarShape().fill(fill)
        case "triangle": TriangleShape().fill(fill)
        default: Rectangle().fill(fill)
        }
    }

    // MARK: - Helpers
    private func calculateFitDimensions(containerW: CGFloat, containerH: CGFloat, aspect: Double) -> (CGFloat, CGFloat) {
        guard aspect > 0, containerH > 0 else { return (320, 180) }
        let cAspect = containerW / containerH
        if cAspect > aspect {
            let h = containerH - 12
            let w = h * CGFloat(aspect)
            return (w, h)
        } else {
            let w = containerW - 12
            let h = w / CGFloat(aspect)
            return (w, h)
        }
    }

    private func calculateActiveRange() -> (Double, Double, Double) {
        if exportRange == .workAreaIfActive && viewModel.project.hasCustomWorkArea {
            let inT = viewModel.project.effectiveRenderIn
            let outT = viewModel.project.effectiveRenderOut
            let dur = viewModel.project.effectiveRenderDuration
            return (inT, outT, dur)
        } else {
            let dur = viewModel.project.totalDuration
            return (0.0, dur, dur)
        }
    }

    private func calculateEstimatedSize() -> Int64 {
        let (_, _, duration) = calculateActiveRange()
        let bitrateMbps: Double
        switch quality {
        case .high: bitrateMbps = 18.0
        case .balanced: bitrateMbps = 8.0
        case .maximum: bitrateMbps = 120.0
        case .webFast: bitrateMbps = 5.0
        }
        return FileSizeEstimator.estimateSizeBytes(durationSeconds: duration, bitrateMbps: bitrateMbps)
    }

    private func togglePreviewPlayback() {
        if isPlayingPreview {
            stopPreview()
        } else {
            isPlayingPreview = true
            let total = viewModel.project.totalDuration
            let range = exportRange
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak viewModel] _ in
                guard let vm = viewModel else { return }
                DispatchQueue.main.async {
                    previewTime += 0.033
                    if previewTime > total {
                        let inT = (range == .workAreaIfActive) ? vm.project.effectiveRenderIn : 0.0
                        previewTime = inT
                    }
                    vm.playbackEngine.seek(to: previewTime)
                }
            }
        }
    }

    private func stopPreview() {
        isPlayingPreview = false
        previewTimer?.invalidate()
        previewTimer = nil
    }

    private func formatTime(_ sec: Double) -> String {
        let s = max(0, sec)
        let mins = Int(s) / 60
        let secs = Int(s) % 60
        let frames = Int((s.truncatingRemainder(dividingBy: 1)) * 30)
        return String(format: "%02d:%02d:%02d", mins, secs, frames)
    }

    private func executeExport() {
        let panel = NSSavePanel()
        panel.title = "Guardar Video Renderizado"
        panel.prompt = "Renderizar"
        panel.nameFieldStringValue = "\(viewModel.project.projectName).\(container.fileExtension)"
        panel.allowedContentTypes = container == .mov ? [.quickTimeMovie] : (container == .m4a ? [.audio] : [.mpeg4Movie])

        if panel.runModal() == .OK, let outputURL = panel.url {
            let useWorkArea = (exportRange == .workAreaIfActive)
            viewModel.startConfiguredExport(
                to: outputURL,
                container: container,
                quality: quality,
                mediaType: mediaType,
                useWorkArea: useWorkArea,
                customConfiguration: viewModel.project.configuration
            )
        }
    }
}
