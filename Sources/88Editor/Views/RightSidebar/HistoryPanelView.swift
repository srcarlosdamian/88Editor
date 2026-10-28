import SwiftUI
import AppKit

/// Panel de Historial de Acciones (Estilo Adobe Photoshop / Premiere Pro).
/// Permite viajar en el tiempo a cualquier estado anterior o posterior con un solo clic (Ctrl+Z / Cmd+Z).
public struct HistoryPanelView: View {
    @ObservedObject var viewModel: EditorViewModel

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    public init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Barra de Herramientas de Deshacer / Rehacer / Limpiar
            HStack(spacing: 8) {
                Button {
                    viewModel.undo()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Deshacer")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(viewModel.canUndo ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1.0 : 0.4)
                .help("Deshacer última acción (⌘Z / Ctrl+Z)")

                Button {
                    viewModel.redo()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Rehacer")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(viewModel.canRedo ? Color(NSColor.controlBackgroundColor) : Color.clear)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canRedo)
                .opacity(viewModel.canRedo ? 1.0 : 0.4)
                .help("Rehacer acción deshecha (⇧⌘Z / Ctrl+Y)")

                Spacer()

                Button {
                    viewModel.clearHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(5)
                }
                .buttonStyle(.plain)
                .help("Limpiar historial previo y mantener estado actual")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Lista interactiva de Pasos / Instantáneas de Historial
            if viewModel.historyStates.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Historial vacío")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(Array(viewModel.historyStates.enumerated()), id: \.element.id) { index, state in
                                let isCurrent = (index == viewModel.currentHistoryIndex)
                                let isPast = (index < viewModel.currentHistoryIndex)
                                let isFuture = (index > viewModel.currentHistoryIndex)

                                Button {
                                    viewModel.jumpToHistoryState(at: index)
                                } label: {
                                    HStack(spacing: 8) {
                                        // Indicador visual de estado activo
                                        if isCurrent {
                                            Image(systemName: "arrowtriangle.right.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(.primary)
                                                .frame(width: 10)
                                        } else {
                                            Circle()
                                                .fill(isPast ? Color.secondary.opacity(0.3) : Color.clear)
                                                .frame(width: 5, height: 5)
                                                .frame(width: 10)
                                        }

                                        // Icono de la acción
                                        Image(systemName: state.icon)
                                            .font(.system(size: 11))
                                            .foregroundColor(isCurrent ? .primary : (isFuture ? .secondary.opacity(0.5) : .primary))
                                            .frame(width: 16)

                                        // Nombre de la acción
                                        Text(state.title)
                                            .font(.system(size: 11, weight: isCurrent ? .bold : .regular))
                                            .italic(isFuture)
                                            .foregroundColor(isCurrent ? .primary : (isFuture ? .secondary.opacity(0.45) : .primary))
                                            .lineLimit(1)
                                            .truncationMode(.middle)

                                        Spacer()

                                        // Hora del registro
                                        Text(timeFormatter.string(from: state.timestamp))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(isFuture ? .secondary.opacity(0.3) : .secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(isCurrent ? Color.white.opacity(0.12) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isCurrent ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .id(state.id)
                            }
                        }
                        .padding(10)
                    }
                    .onChange(of: viewModel.currentHistoryIndex) { newIndex in
                        if let active = viewModel.historyStates[safe: newIndex] {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(active.id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider().foregroundColor(DesignSystem.border)

            // Pie informativo con contador y leyenda de atajos
            HStack {
                Text("Paso \(viewModel.currentHistoryIndex + 1) de \(max(1, viewModel.historyStates.count))")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text("⌘Z Deshacer  •  ⇧⌘Z Rehacer")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .background(Color(NSColor.underPageBackgroundColor))
    }
}

// Extensión segura para índices de arreglo
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
