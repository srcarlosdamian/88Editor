import SwiftUI

/// Modal para editar la configuración del proyecto actual:
/// Nombre, preset, dimensiones ancho x alto, framerate y color de fondo.
/// Los cambios se confirman explícitamente desde este modal.
public struct ProjectSettingsSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var selectedPreset: ResolutionPreset = .custom
    @State private var customWidth: Double = 1920
    @State private var customHeight: Double = 1080
    @State private var selectedFramerate: FramerateOption = .fps30
    @State private var selectedColorOption: Int = 0
    @State private var projectDuration: Double = 10.0

    public init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera del modal
            HStack(spacing: 12) {
                AppLogoIconView(size: 38, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ajustes del Proyecto")
                        .font(.system(size: 15, weight: .bold))
                    Text("Editar resolución, tamaño y formato de video")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(18)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Formulario de edición
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Nombre del Proyecto
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre del Proyecto")
                            .font(.system(size: 12, weight: .semibold))

                        TextField("Nombre del proyecto", text: $projectName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Selector de Resolución y Preset
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resolución y Formato")
                            .font(.system(size: 12, weight: .semibold))

                        Picker("", selection: $selectedPreset) {
                            ForEach(ResolutionPreset.allCases) { preset in
                                HStack {
                                    Image(systemName: preset.iconName)
                                    Text(preset.rawValue)
                                }
                                .tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: selectedPreset) { newPreset in
                            if newPreset != .custom {
                                customWidth = Double(newPreset.defaultDimensions.width)
                                customHeight = Double(newPreset.defaultDimensions.height)
                            }
                        }

                        // Campos numéricos de Ancho y Alto
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ancho (px)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                TextField("1920", value: $customWidth, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: customWidth) { _ in
                                        if selectedPreset != .custom && customWidth != Double(selectedPreset.defaultDimensions.width) {
                                            selectedPreset = .custom
                                        }
                                    }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Alto (px)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                TextField("1080", value: $customHeight, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: customHeight) { _ in
                                        if selectedPreset != .custom && customHeight != Double(selectedPreset.defaultDimensions.height) {
                                            selectedPreset = .custom
                                        }
                                    }
                            }
                        }
                        .padding(.top, 2)
                    }

                    // Framerate (24, 25, 30, 50, 60 fps)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tasa de Cuadros (Framerate)")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(selectedFramerate.displayName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Picker("", selection: $selectedFramerate) {
                            ForEach(FramerateOption.allCases) { option in
                                Text(option.shortName).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Color de Fondo del Lienzo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color Base del Lienzo")
                            .font(.system(size: 12, weight: .semibold))

                        HStack(spacing: 14) {
                            colorOptionButton(title: "Negro", color: .black, index: 0)
                            colorOptionButton(title: "Gris Carbón", color: Color(red: 0.12, green: 0.12, blue: 0.12), index: 1)
                            colorOptionButton(title: "Blanco", color: .white, index: 2)
                        }
                    }

                    // Duración del Proyecto y Línea de Tiempo
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duración de la Línea de Tiempo")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(String(format: "%.0fs (%.1f min)", projectDuration, projectDuration / 60.0))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            TextField("10", value: $projectDuration, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)

                            Text("segundos")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Spacer()

                            // Botones de incremento rápido
                            Button("+5s") { projectDuration += 5 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("+10s") { projectDuration += 10 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("+30s") { projectDuration += 30 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button("+1m") { projectDuration += 60 }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }

                        // Presets comunes de duración
                        HStack(spacing: 6) {
                            durationPresetButton(title: "15s (Reels)", seconds: 15)
                            durationPresetButton(title: "30s (Story)", seconds: 30)
                            durationPresetButton(title: "60s (1 min)", seconds: 60)
                            durationPresetButton(title: "120s (2 min)", seconds: 120)
                            durationPresetButton(title: "300s (5 min)", seconds: 300)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }

            // Barra inferior de confirmación
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Confirmar Cambios") {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .top
            )
        }
        .frame(width: 520, height: 600)
        .onAppear {
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        let config = viewModel.project.configuration
        projectName = viewModel.project.projectName
        selectedPreset = config.preset
        customWidth = config.width
        customHeight = config.height
        selectedFramerate = config.framerate
        selectedColorOption = config.backgroundColor == .black ? 0 : (config.backgroundColor == .pureWhite ? 2 : 1)
        projectDuration = config.defaultDuration
    }

    private func saveChanges() {
        let bg: CanvasColor = (selectedColorOption == 0) ? .black : ((selectedColorOption == 2) ? .pureWhite : .darkGray)
        let finalW = max(100.0, customWidth)
        let finalH = max(100.0, customHeight)

        let newConfig = ProjectConfiguration(
            preset: selectedPreset,
            customWidth: finalW,
            customHeight: finalH,
            framerate: selectedFramerate,
            backgroundColor: bg,
            defaultDuration: max(5.0, projectDuration)
        )

        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            viewModel.project.projectName = trimmedName
        }

        viewModel.updateProjectConfiguration(newConfig)
        viewModel.playbackEngine.updateTotalDuration(viewModel.project.totalDuration)
        viewModel.recordHistory(title: "Editar ajustes del proyecto", icon: "slider.horizontal.3")
    }

    @ViewBuilder
    private func durationPresetButton(title: String, seconds: Double) -> some View {
        Button {
            projectDuration = seconds
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(abs(projectDuration - seconds) < 0.1 ? Color.primary : DesignSystem.border, lineWidth: abs(projectDuration - seconds) < 0.1 ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func colorOptionButton(title: String, color: Color, index: Int) -> some View {
        Button {
            selectedColorOption = index
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))

                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedColorOption == index ? Color.primary : DesignSystem.border, lineWidth: selectedColorOption == index ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
