import SwiftUI

/// Control compacto y numérico con slider, navegación de fotogramas clave [◀] [◇] [▶] y botón de restablecimiento
public struct TransformControlRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let defaultValue: Double

    // Soporte de Fotogramas Clave (Keyframes)
    var isKeyframeActive: Bool = false
    var hasAnyKeyframes: Bool = false
    var onToggleKeyframe: (() -> Void)? = nil
    var onPreviousKeyframe: (() -> Void)? = nil
    var onNextKeyframe: (() -> Void)? = nil

    public init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1.0,
        unit: String = "",
        defaultValue: Double = 0.0,
        isKeyframeActive: Bool = false,
        hasAnyKeyframes: Bool = false,
        onToggleKeyframe: (() -> Void)? = nil,
        onPreviousKeyframe: (() -> Void)? = nil,
        onNextKeyframe: (() -> Void)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.defaultValue = defaultValue
        self.isKeyframeActive = isKeyframeActive
        self.hasAnyKeyframes = hasAnyKeyframes
        self.onToggleKeyframe = onToggleKeyframe
        self.onPreviousKeyframe = onPreviousKeyframe
        self.onNextKeyframe = onNextKeyframe
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                // Navegación [◀] [◇] [▶] de fotogramas clave
                if let toggleAction = onToggleKeyframe {
                    HStack(spacing: 2) {
                        // Anterior fotograma clave
                        Button {
                            onPreviousKeyframe?()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(hasAnyKeyframes ? .secondary : .secondary.opacity(0.25))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasAnyKeyframes)
                        .help("Saltar al fotograma clave anterior")

                        // Rombo Keyframe activo / inactivo
                        Button(action: toggleAction) {
                            Image(systemName: isKeyframeActive ? "diamond.fill" : "diamond")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isKeyframeActive ? DesignSystem.selectedClipBorder : (hasAnyKeyframes ? .primary : .secondary.opacity(0.4)))
                        }
                        .buttonStyle(.plain)
                        .help(isKeyframeActive ? "Eliminar fotograma clave en el cabezal" : "Agregar fotograma clave en el cabezal")

                        // Siguiente fotograma clave
                        Button {
                            onNextKeyframe?()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(hasAnyKeyframes ? .secondary : .secondary.opacity(0.25))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasAnyKeyframes)
                        .help("Saltar al siguiente fotograma clave")
                    }
                    .padding(.trailing, 2)
                }

                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)

                Spacer()

                // Valor numérico formateado
                Text("\(Int(value))\(unit)")
                    .font(DesignSystem.monoFont)
                    .foregroundColor(.primary)

                // Botón de restablecimiento
                if abs(value - defaultValue) > 0.001 {
                    Button {
                        value = defaultValue
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Restablecer valor predeterminado")
                }
            }

            Slider(value: $value, in: range, step: step)
                .controlSize(.mini)
                .tint(.secondary)
        }
    }
}
