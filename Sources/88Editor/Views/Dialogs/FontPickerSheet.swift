import SwiftUI
import AppKit

/// Selector de tipografía nativa de macOS utilizando NSFontManager
public struct FontPickerSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var sampleText: String = "88 Editor — Video Minimalista"
    @State private var selectedFont: String = "Helvetica Neue"

    private var filteredFonts: [String] {
        if searchText.isEmpty {
            return viewModel.availableSystemFonts
        }
        return viewModel.availableSystemFonts.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera
            HStack {
                Label("Tipografías del Sistema (NSFontManager)", systemImage: "textformat")
                    .font(DesignSystem.sectionTitle)

                Spacer()

                Button("Cerrar") {
                    dismiss()
                }
                .controlSize(.small)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Buscador de fuentes
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Buscar fuentes instaladas...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding(12)

            // Muestra interactiva de previsualización
            VStack(alignment: .leading, spacing: 6) {
                Text("VISTA PREVIA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)

                TextField("Texto de muestra...", text: $sampleText)
                    .font(.custom(selectedFont, size: 20))
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(DesignSystem.border, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider().foregroundColor(DesignSystem.border)

            // Lista de familias de fuentes
            List(filteredFonts, id: \.self, selection: $selectedFont) { fontName in
                HStack {
                    Text(fontName)
                        .font(.custom(fontName, size: 14))
                    Spacer()
                    if selectedFont == fontName {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFont = fontName
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            // Barra inferior con botón de aplicación
            HStack {
                Text("\(filteredFonts.count) fuentes disponibles")
                    .font(DesignSystem.monoFont)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancelar") {
                    dismiss()
                }

                Button("Aplicar al Clip") {
                    if viewModel.selectedClip != nil {
                        viewModel.selectedClip?.fontName = selectedFont
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .top
            )
        }
        .frame(width: 440, height: 500)
        .onAppear {
            if let currentFont = viewModel.selectedClip?.fontName {
                selectedFont = currentFont
            }
        }
    }
}
