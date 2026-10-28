import SwiftUI
import AVFoundation

/// Modal Versátil de Configuración y Exportación de Video y Audio
public struct ExportSettingsSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSocialPreset: SocialPreset = .youtube
    @State private var mediaType: ExportMediaType = .videoAndAudio
    @State private var container: ExportContainer = .mp4
    @State private var quality: ExportQuality = .high
    @State private var exportRange: ExportRangeOption = .workAreaIfActive

    public enum ExportRangeOption: String, CaseIterable, Identifiable {
        case workAreaIfActive = "Área de Trabajo (Puntos In / Out)"
        case entireProject = "Línea de Tiempo Completa"

        public var id: String { rawValue }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera
            HStack(spacing: 12) {
                AppLogoIconView(size: 32, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Exportar y Renderizar")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.project.projectName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(DesignSystem.border), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. PRESETS INTELIGENTES DE REDES SOCIALES
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREAJUSTES PARA REDES SOCIALES Y FORMATOS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("Preajuste", selection: $selectedSocialPreset) {
                            ForEach(SocialPreset.allCases) { preset in
                                Label(preset.rawValue, systemImage: preset.icon).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedSocialPreset) { newPreset in
                            applySocialPreset(newPreset)
                        }

                        // Tarjeta explicativa de compatibilidad del preset
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 12))
                                .padding(.top, 1)

                            Text(selectedSocialPreset.recommendationNote)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                    }

                    Divider().foregroundColor(DesignSystem.border)

                    // 2. TIPO DE MEDIO Y CONTENEDOR
                    HStack(spacing: 16) {
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

                        VStack(alignment: .leading, spacing: 6) {
                            Text("FORMATO DE CONTENEDOR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            Picker("", selection: $container) {
                                if mediaType == .videoAndAudio {
                                    Text("MP4 (.mp4)").tag(ExportContainer.mp4)
                                    Text("QuickTime (.mov)").tag(ExportContainer.mov)
                                } else {
                                    Text("Audio AAC (.m4a)").tag(ExportContainer.m4a)
                                    Text("Audio PCM (.wav)").tag(ExportContainer.wav)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    // 3. CALIDAD DE RENDERIZADO
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CALIDAD DEL ARCHIVO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $quality) {
                            ForEach(ExportQuality.allCases) { q in
                                Text(q.rawValue).tag(q)
                            }
                        }
                        .labelsHidden()

                        Text(quality.description)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Divider().foregroundColor(DesignSystem.border)

                    // 4. RANGO DE RENDERIZADO (Área de Trabajo vs Completo)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RANGO DE EXPORTACIÓN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)

                        Picker("", selection: $exportRange) {
                            ForEach(ExportRangeOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        HStack {
                            let (inTime, outTime, dur) = calculateActiveRange()
                            Label(
                                String(format: "Punto Entrada: %.2fs  |  Punto Salida: %.2fs  |  Duración a renderizar: %.2fs", inTime, outTime, dur),
                                systemImage: "clock"
                            )
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                    }

                    Divider().foregroundColor(DesignSystem.border)

                    // 5. ESTIMACIÓN DE PESO EN TIEMPO REAL
                    let estimatedBytes = calculateEstimatedSize()
                    HStack(spacing: 12) {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peso Estimado de Archivo:")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Basado en la tasa de bits y duración seleccionada")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("~ \(FileSizeEstimator.formatBytes(estimatedBytes))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignSystem.border, lineWidth: 1))
                }
                .padding(22)
            }

            Divider().foregroundColor(DesignSystem.border)

            // Barra inferior con botón de exportar
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Exportar y Guardar...") {
                    executeExport()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 620, height: 600)
        .background(Color(NSColor.underPageBackgroundColor))
        .onAppear {
            if viewModel.project.hasCustomWorkArea {
                exportRange = .workAreaIfActive
            }
        }
    }

    private func applySocialPreset(_ preset: SocialPreset) {
        mediaType = preset.defaultMediaType
        container = preset.defaultContainer
        quality = preset.defaultQuality
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
        let bitrateMbps = selectedSocialPreset == .custom ? 16.0 : selectedSocialPreset.estimatedBitrateMbps
        return FileSizeEstimator.estimateSizeBytes(durationSeconds: duration, bitrateMbps: bitrateMbps)
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
                useWorkArea: useWorkArea
            )
        }
    }
}
