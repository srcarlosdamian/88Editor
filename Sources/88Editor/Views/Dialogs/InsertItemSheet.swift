import SwiftUI
import AppKit

/// Tipo de inserción en el modal
public enum InsertItemCategory: String, CaseIterable, Identifiable {
    case text = "Texto Vectorial"
    case shape = "Forma Vectorial"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .text: return "character.textbox"
        case .shape: return "circle.fill"
        }
    }
}

/// Formas geométricas vectoriales soportadas
public enum VectorShapeType: String, CaseIterable, Identifiable {
    case circle = "Círculo"
    case rectangle = "Rectángulo"
    case roundedRectangle = "Rectángulo Redondeado"
    case star = "Estrella"
    case triangle = "Triángulo"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .circle: return "circle.fill"
        case .rectangle: return "square.fill"
        case .roundedRectangle: return "app.fill"
        case .star: return "star.fill"
        case .triangle: return "triangle.fill"
        }
    }

    public var codeName: String {
        switch self {
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .roundedRectangle: return "roundedRectangle"
        case .star: return "star"
        case .triangle: return "triangle"
        }
    }
}

/// Forma vectorial de Estrella con 5 puntas
public struct StarShape: Shape {
    public let points: Int = 5
    public let innerRatio: CGFloat = 0.45

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        let angleStep = .pi / CGFloat(points)
        var currentAngle: CGFloat = -.pi / 2

        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let x = center.x + radius * cos(currentAngle)
            let y = center.y + radius * sin(currentAngle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            currentAngle += angleStep
        }
        path.closeSubpath()
        return path
    }
}

/// Forma vectorial de Triángulo equilátero
public struct TriangleShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Modal interactivo para insertar Texto o Formas Vectoriales con previsualización en vivo
public struct InsertItemSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var category: InsertItemCategory = .text

    // Parámetros de Texto
    @State private var textContent: String = "Título Vectorial"
    @State private var selectedFont: String = "Helvetica Neue"
    @State private var fontSize: Double = 56.0
    @State private var textColor: Color = Color(hex: "#FF3B30") // Rojo por defecto como solicitó el usuario

    // Parámetros de Forma
    @State private var selectedShape: VectorShapeType = .circle
    @State private var fillColor: Color = Color(hex: "#FF3B30") // Rojo por defecto
    @State private var strokeColor: Color = .white
    @State private var strokeWidth: Double = 0.0

    public init(viewModel: EditorViewModel, initialCategory: InsertItemCategory = .text) {
        self.viewModel = viewModel
        self._category = State(initialValue: initialCategory)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera del modal
            HStack {
                Label("Insertar Objeto Vectorial", systemImage: "plus.viewfinder")
                    .font(.system(size: 14, weight: .bold))

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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Selector de Categoría (Texto vs Formas)
            Picker("Categoría", selection: $category) {
                ForEach(InsertItemCategory.allCases) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Contenedor principal de configuración + Previsualización en Vivo
            HStack(spacing: 20) {
                // Columna izquierda: Controles
                VStack(alignment: .leading, spacing: 14) {
                    if category == .text {
                        textControlsSection
                    } else {
                        shapeControlsSection
                    }
                    Spacer()
                }
                .frame(width: 280)

                Divider().foregroundColor(DesignSystem.border)

                // Columna derecha: Previsualización en Tiempo Real
                VStack(alignment: .leading, spacing: 8) {
                    Text("VISTA PREVIA EN VIVO (CALIDAD VECTORIAL)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)

                    ZStack {
                        // Fondo de visor oscuro con cuadrícula sutil
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.08, green: 0.08, blue: 0.10))

                        // Elemento renderizado vectorialmente
                        if category == .text {
                            Text(textContent.isEmpty ? "Escribe texto..." : textContent)
                                .font(.custom(selectedFont, size: fontSize))
                                .foregroundColor(textColor)
                                .multilineTextAlignment(.center)
                                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                                .padding(16)
                        } else {
                            renderPreviewShape()
                                .frame(width: 160, height: 160)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignSystem.border, lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider().foregroundColor(DesignSystem.border)

            // Barra inferior con botones
            HStack {
                Text("Todo es 100% vectorial: la calidad nunca se pixelará")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Insertar en Proyecto") {
                    insertItem()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 680, height: 490)
        .background(Color(NSColor.underPageBackgroundColor))
        .onAppear {
            if let first = viewModel.availableSystemFonts.first, selectedFont.isEmpty {
                selectedFont = first
            }
        }
    }

    // MARK: - Controles de Texto
    @ViewBuilder
    private var textControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Contenido de Texto")
                    .font(.system(size: 11, weight: .semibold))
                TextField("Escribe el texto...", text: $textContent)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Fuente Tipográfica")
                    .font(.system(size: 11, weight: .semibold))
                Picker("", selection: $selectedFont) {
                    ForEach(viewModel.availableSystemFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tamaño")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(Int(fontSize)) pt")
                        .font(DesignSystem.monoFont)
                        .foregroundColor(.secondary)
                }
                Slider(value: $fontSize, in: 16...140, step: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Color de Texto (Rojo por Defecto)")
                    .font(.system(size: 11, weight: .semibold))
                ColorPicker("Seleccionar Color", selection: $textColor)
            }
        }
    }

    // MARK: - Controles de Forma
    @ViewBuilder
    private var shapeControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tipo de Forma")
                    .font(.system(size: 11, weight: .semibold))
                Picker("", selection: $selectedShape) {
                    ForEach(VectorShapeType.allCases) { shape in
                        Label(shape.rawValue, systemImage: shape.icon).tag(shape)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Color de Relleno (Rojo por Defecto)")
                    .font(.system(size: 11, weight: .semibold))
                ColorPicker("Color de Relleno", selection: $fillColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Color de Borde / Trazo")
                    .font(.system(size: 11, weight: .semibold))
                ColorPicker("Color de Borde", selection: $strokeColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Grosor de Borde")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(Int(strokeWidth)) px")
                        .font(DesignSystem.monoFont)
                        .foregroundColor(.secondary)
                }
                Slider(value: $strokeWidth, in: 0...24, step: 1)
            }
        }
    }

    // MARK: - Render de Forma en Vista Previa
    @ViewBuilder
    private func renderPreviewShape() -> some View {
        switch selectedShape {
        case .circle:
            Circle()
                .fill(fillColor)
                .overlay(Circle().stroke(strokeColor, lineWidth: strokeWidth))
        case .rectangle:
            Rectangle()
                .fill(fillColor)
                .overlay(Rectangle().stroke(strokeColor, lineWidth: strokeWidth))
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: 24)
                .fill(fillColor)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(strokeColor, lineWidth: strokeWidth))
        case .star:
            StarShape()
                .fill(fillColor)
                .overlay(StarShape().stroke(strokeColor, lineWidth: strokeWidth))
        case .triangle:
            TriangleShape()
                .fill(fillColor)
                .overlay(TriangleShape().stroke(strokeColor, lineWidth: strokeWidth))
        }
    }

    // MARK: - Inserción en el Proyecto
    private func insertItem() {
        if category == .text {
            viewModel.insertVectorText(
                text: textContent.isEmpty ? "Texto" : textContent,
                fontName: selectedFont,
                fontSize: fontSize,
                colorHex: textColor.toHex()
            )
        } else {
            viewModel.insertVectorShape(
                shapeType: selectedShape.codeName,
                shapeDisplayName: selectedShape.rawValue,
                fillColorHex: fillColor.toHex(),
                strokeColorHex: strokeWidth > 0 ? strokeColor.toHex() : nil,
                strokeWidth: strokeWidth
            )
        }
    }
}
