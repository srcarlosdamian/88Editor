import SwiftUI

/// Modal interactivo para recortar los cuatro bordes (Izquierda, Derecha, Arriba, Abajo) de una imagen o video
public struct CropSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let clip: TimelineClip

    @State private var cropLeft: Double = 0.0
    @State private var cropRight: Double = 0.0
    @State private var cropTop: Double = 0.0
    @State private var cropBottom: Double = 0.0

    public init(viewModel: EditorViewModel, clip: TimelineClip) {
        self.viewModel = viewModel
        self.clip = clip
        self._cropLeft = State(initialValue: clip.cropLeft)
        self._cropRight = State(initialValue: clip.cropRight)
        self._cropTop = State(initialValue: clip.cropTop)
        self._cropBottom = State(initialValue: clip.cropBottom)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera
            HStack {
                Label("Recortar Medio (Crop): \(clip.name)", systemImage: "crop")
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Rectangle().frame(height: 1).foregroundColor(DesignSystem.border), alignment: .bottom)

            // Contenido: Previsualización + Controles de Bordes
            HStack(spacing: 20) {
                // Previsualización interactiva con recorte en vivo
                VStack(alignment: .leading, spacing: 8) {
                    Text("VISTA PREVIA DEL RECORTE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    ZStack {
                        Color.black

                        if let asset = viewModel.asset(for: clip) {
                            if asset.mediaType == .image, let img = NSImage(contentsOf: asset.fileURL) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(CropRectShape(left: cropLeft, right: cropRight, top: cropTop, bottom: cropBottom))
                            } else {
                                // Video thumbnail preview
                                Image(systemName: "film")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                    .clipShape(CropRectShape(left: cropLeft, right: cropRight, top: cropTop, bottom: cropBottom))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DesignSystem.border, lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Controles numéricos y sliders
                VStack(alignment: .leading, spacing: 14) {
                    Text("BORDES DE RECORTE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    cropSliderRow(title: "Izquierda", value: $cropLeft)
                    cropSliderRow(title: "Derecha", value: $cropRight)
                    cropSliderRow(title: "Arriba", value: $cropTop)
                    cropSliderRow(title: "Abajo", value: $cropBottom)

                    Divider().foregroundColor(DesignSystem.border)

                    // Presets rápidos de relación de aspecto
                    Text("PREAJUSTES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Button("1:1 Cuadrado") {
                            cropLeft = 0.125
                            cropRight = 0.125
                            cropTop = 0.0
                            cropBottom = 0.0
                        }
                        .controlSize(.small)

                        Button("9:16 Vertical") {
                            cropLeft = 0.22
                            cropRight = 0.22
                            cropTop = 0.0
                            cropBottom = 0.0
                        }
                        .controlSize(.small)

                        Button("Restablecer") {
                            cropLeft = 0.0
                            cropRight = 0.0
                            cropTop = 0.0
                            cropBottom = 0.0
                        }
                        .controlSize(.small)
                    }

                    Spacer()
                }
                .frame(width: 250)
            }
            .padding(18)

            Divider().foregroundColor(DesignSystem.border)

            // Botones de acción
            HStack {
                Button("Restablecer Todo") {
                    cropLeft = 0.0
                    cropRight = 0.0
                    cropTop = 0.0
                    cropBottom = 0.0
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Spacer()

                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Aplicar Recorte") {
                    viewModel.applyCrop(
                        clipId: clip.id,
                        left: cropLeft,
                        right: cropRight,
                        top: cropTop,
                        bottom: cropBottom
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 420)
        .background(Color(NSColor.underPageBackgroundColor))
    }

    @ViewBuilder
    private func cropSliderRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(DesignSystem.monoFont)
                    .foregroundColor(.secondary)
            }

            Slider(value: value, in: 0.0...0.48, step: 0.01)
                .controlSize(.small)
        }
    }
}
