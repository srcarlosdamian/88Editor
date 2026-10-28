import SwiftUI

/// Modal Inicial de Proyecto:
/// Presenta lista de Proyectos Recientes a la izquierda (.88proj) y
/// configuración de nuevo proyecto a la derecha (nombre, resolución, framerate y lienzo).
public struct NewProjectSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var recentManager = RecentProjectsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = "Mi Edición Minimalista"
    @State private var selectedPreset: ResolutionPreset = .custom // Por defecto Personalizado
    @State private var customWidth: Double = 1920
    @State private var customHeight: Double = 1080
    @State private var selectedFramerate: FramerateOption = .fps30
    @State private var selectedColorOption: Int = 0 // 0 = Negro, 1 = Carbón, 2 = Blanco
    @State private var projectDuration: Double = 60.0 // Por defecto 1 minuto (60 segundos)
    @State private var hoveredRecentId: String? = nil

    public var body: some View {
        HStack(spacing: 0) {
            // COLUMNA IZQUIERDA: Proyectos Recientes (.88proj)
            VStack(alignment: .leading, spacing: 0) {
                // Cabecera de Recientes
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Proyectos Recientes")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .padding(16)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(DesignSystem.border),
                    alignment: .bottom
                )

                // Lista de proyectos recientes
                if recentManager.recentProjects.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("No hay proyectos recientes")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(recentManager.recentProjects) { item in
                                recentProjectRow(item: item)
                            }
                        }
                        .padding(8)
                    }
                }

                Divider()

                // Botón inferior para abrir archivo existente desde disco
                Button {
                    dismiss()
                    viewModel.promptOpenProjectPanel()
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("Abrir otro archivo...")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("⌘O")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(width: 250)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

            // Separador vertical
            Rectangle()
                .fill(DesignSystem.border)
                .frame(width: 1)

            // COLUMNA DERECHA: Creación de Nuevo Proyecto
            VStack(spacing: 0) {
                // Cabecera del formulario
                HStack(spacing: 12) {
                    AppLogoIconView(size: 34, cornerRadius: 7)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nuevo Proyecto")
                            .font(.system(size: 15, weight: .bold))
                        Text("Configuración de resolución, framerate y lienzo")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(DesignSystem.border),
                    alignment: .bottom
                )

                // Formulario principal
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
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

                        // Duración Inicial de la Línea de Tiempo (Por defecto: 1 minuto / 60s)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Duración Inicial de la Línea de Tiempo")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Text(String(format: "%.0fs (%.1f min)", projectDuration, projectDuration / 60.0))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 8) {
                                TextField("60", value: $projectDuration, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)

                                Text("segundos")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                Spacer()

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

                            // Botones de presets rápidos (Por defecto 60s / 1 min seleccionado)
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
                    .padding(.vertical, 18)
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
            .frame(width: 490)
        }
        .frame(width: 740, height: 580)
    }

    @ViewBuilder
    private func recentProjectRow(item: RecentProjectItem) -> some View {
        let isHovered = (hoveredRecentId == item.id)

        Button {
            dismiss()
            viewModel.loadProject(from: item.url)
        } label: {
            HStack(spacing: 10) {
                // Icono nítido pixel-perfect
                Image(systemName: "film")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(5)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text(item.relativeTime)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)

                        Text("·")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Text(item.displayPath)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                dismiss()
                viewModel.loadProject(from: item.url)
            } label: {
                Label("Abrir Proyecto", systemImage: "folder")
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label("Mostrar en Finder", systemImage: "arrow.up.forward.app")
            }

            Divider()

            Button(role: .destructive) {
                recentManager.remove(url: item.url)
            } label: {
                Label("Eliminar de la lista de recientes", systemImage: "trash")
            }
        }
        .onHover { inside in
            hoveredRecentId = inside ? item.id : nil
        }
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
                    .stroke(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func durationPresetButton(title: String, seconds: Double) -> some View {
        let isSelected = abs(projectDuration - seconds) < 0.1
        Button {
            projectDuration = seconds
        } label: {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? Color.white.opacity(0.85) : DesignSystem.border, lineWidth: isSelected ? 1.5 : 1)
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
            backgroundColor: baseColor,
            defaultDuration: max(5.0, projectDuration)
        )

        let cleanName = projectName.isEmpty ? "Proyecto sin título" : projectName
        viewModel.createNewProject(with: config, name: cleanName)
    }
}
