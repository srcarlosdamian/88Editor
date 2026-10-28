import SwiftUI

/// Modal Inicial de Proyecto:
/// Selector de resolución con menú desplegable (Dropdown) por defecto "Personalizado",
/// campos editables de Ancho/Alto, framerate (24, 30, 60 fps) y color de fondo base.
public struct NewProjectSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = "Mi Edición Minimalista"
    @State private var selectedPreset: ResolutionPreset = .custom // Por defecto Personalizado
    @State private var customWidth: Double = 1920
    @State private var customHeight: Double = 1080
    @State private var selectedFramerate: FramerateOption = .fps30
    @State private var selectedColorOption: Int = 0 // 0 = Negro, 1 = Carbón, 2 = Blanco

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera del modal
            HStack(spacing: 12) {
                AppLogoIconView(size: 38, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nuevo Proyecto")
                        .font(.system(size: 15, weight: .bold))
                    Text("Configuración de resolución y formato")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Abrir .88proj Existente...") {
                    dismiss()
                    viewModel.promptOpenProjectPanel()
                }
                .controlSize(.small)
            }
            .padding(18)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Formulario principal
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Nombre del Proyecto
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nombre del Proyecto")
                            .font(.system(size: 12, weight: .semibold))

                        TextField("Ej: Video Promocional", text: $projectName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Selector de Resolución y Formato mediante Menú Desplegable (Dropdown)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resolución y Formato")
                            .font(.system(size: 12, weight: .semibold))

                        // Dropdown (Picker con estilo menú nativo)
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

                    // Color de Fondo Base (por defecto negro)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color Base del Lienzo")
                            .font(.system(size: 12, weight: .semibold))

                        HStack(spacing: 14) {
                            colorOptionButton(title: "Negro", color: .black, index: 0)
                            colorOptionButton(title: "Gris Carbón", color: Color(red: 0.12, green: 0.12, blue: 0.12), index: 1)
                            colorOptionButton(title: "Blanco", color: .white, index: 2)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }

            // Barra inferior de botones de acción
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Crear Proyecto") {
                    createProject()
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
        .frame(width: 520, height: 530)
    }

    @ViewBuilder
    private func colorOptionButton(title: String, color: Color, index: Int) -> some View {
        let isSelected = selectedColorOption == index
        Button {
            selectedColorOption = index
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.secondary, lineWidth: 1))

                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .minimalCard(cornerRadius: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func createProject() {
        let baseColor: CanvasColor
        switch selectedColorOption {
        case 1: baseColor = .darkGray
        case 2: baseColor = .pureWhite
        default: baseColor = .black
        }

        let config = ProjectConfiguration(
            preset: selectedPreset,
            customWidth: customWidth,
            customHeight: customHeight,
            framerate: selectedFramerate,
            backgroundColor: baseColor
        )

        viewModel.createNewProject(with: config)
        viewModel.project.projectName = projectName.isEmpty ? "Proyecto sin título" : projectName
    }
}
