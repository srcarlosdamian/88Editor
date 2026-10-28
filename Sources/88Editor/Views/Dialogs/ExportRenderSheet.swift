import SwiftUI

/// Modal de Exportación y Renderizado de Video:
/// Muestra la barra de progreso, porcentaje en tiempo real y opciones de cancelación.
public struct ExportRenderSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                AppLogoIconView(size: 32, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Renderizando Video")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.project.projectName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                ProgressView(value: viewModel.exportProgress, total: 1.0)
                    .progressViewStyle(.linear)

                HStack {
                    Text(viewModel.exportStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(viewModel.exportProgress * 100))%")
                        .font(DesignSystem.monoFont)
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 8)

            HStack {
                Button("Cancelar") {
                    viewModel.cancelExport()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
