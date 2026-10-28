import SwiftUI

/// Control compacto y numérico con slider y botón de fotograma clave (Keyframe Diamond)
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

    public init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1.0,
        unit: String = "",
        defaultValue: Double = 0.0,
        isKeyframeActive: Bool = false,
        hasAnyKeyframes: Bool = false,
        onToggleKeyframe: (() -> Void)? = nil
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
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                // Botón de Rombo (Keyframe)
                if let toggleAction = onToggleKeyframe {
                    Button(action: toggleAction) {
                        Image(systemName: isKeyframeActive ? "diamond.fill" : "diamond")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isKeyframeActive ? DesignSystem.selectedClipBorder : (hasAnyKeyframes ? .accentColor : .secondary.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                    .help(isKeyframeActive ? "Eliminar fotograma clave en el cabezal" : "Agregar fotograma clave en el cabezal")
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
        }
    }
}
