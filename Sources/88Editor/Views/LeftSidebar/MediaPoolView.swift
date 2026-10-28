import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Sidebar Izquierdo: Media Pool / Galería de medios vinculados
/// Soporta drag & drop nativo desde Finder, eliminación visual y por teclado (Delete).
public struct MediaPoolView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State private var isDropTargeted: Bool = false
    @FocusState private var isSearchFocused: Bool

    var filteredAssets: [MediaAsset] {
        if viewModel.mediaSearchText.isEmpty {
            return viewModel.project.assets
        }
        return viewModel.project.assets.filter {
            $0.fileName.localizedCaseInsensitiveContains(viewModel.mediaSearchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Cabecera del Media Pool
            HStack(spacing: 8) {
                Label("Galería de Medios", systemImage: "photo.stack")
                    .font(DesignSystem.sectionTitle)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(viewModel.project.assets.count)")
                    .font(DesignSystem.monoFont)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)

                Menu {
                    Button("Importar Archivos Multimedia...") {
                        viewModel.promptImportMediaPanel()
                    }
                    Divider()
                    Button {
                        viewModel.insertSheetCategory = .text
                        viewModel.isInsertSheetPresented = true
                    } label: {
                        Label("Insertar Texto Vectorial...", systemImage: "character.textbox")
                    }
                    Button {
                        viewModel.insertSheetCategory = .shape
                        viewModel.isInsertSheetPresented = true
                    } label: {
                        Label("Insertar Forma Vectorial...", systemImage: "circle.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .help("Importar archivos o insertar objetos vectoriales")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .bottom
            )

            // Barra de búsqueda y alternador de vista
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Buscar archivos vinculados...", text: $viewModel.mediaSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isSearchFocused)
                        .onSubmit {
                            isSearchFocused = false
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }

                    if !viewModel.mediaSearchText.isEmpty {
                        Button {
                            viewModel.mediaSearchText = ""
                            isSearchFocused = false
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                // Botón alternador de grilla o lista
                Button {
                    viewModel.isMediaGridView.toggle()
                } label: {
                    Image(systemName: viewModel.isMediaGridView ? "list.bullet" : "square.grid.2x2")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(viewModel.isMediaGridView ? "Vista en lista" : "Vista en cuadrícula")
            }
            .padding(10)

            Divider()
                .foregroundColor(DesignSystem.border)

            // Contenedor principal con Drop Zone
            ScrollView {
                if viewModel.project.assets.isEmpty {
                    // Zona vacía invitando al Drag & Drop
                    VStack(spacing: 14) {
                        Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                            .font(.system(size: 32))
                            .foregroundColor(isDropTargeted ? .primary : .secondary)

                        VStack(spacing: 4) {
                            Text("Arrastra archivos aquí")
                                .font(.system(size: 13, weight: .medium))
                            Text("Videos (.mov, .mp4), Audio (.mp3, .wav) o Imágenes")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button("Examinar en Finder...") {
                            viewModel.promptImportMediaPanel()
                        }
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isDropTargeted ? Color.white.opacity(0.4) : Color.secondary.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                    )
                    .padding(14)
                } else {
                    if viewModel.isMediaGridView {
                        // Vista en Cuadrícula
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(filteredAssets) { asset in
                                mediaGridCard(asset: asset)
                            }
                        }
                        .padding(10)
                    } else {
                        // Vista en Lista
                        LazyVStack(spacing: 4) {
                            ForEach(filteredAssets) { asset in
                                MediaAssetRow(
                                    asset: asset,
                                    isSelected: viewModel.selectedAssetId == asset.id,
                                    onAddToTimeline: {
                                        viewModel.addClipToTimeline(assetId: asset.id)
                                    },
                                    onDelete: {
                                        viewModel.promptRemoveAsset(id: asset.id)
                                    },
                                    onReconnect: {
                                        viewModel.reconnectAsset(id: asset.id)
                                    }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectedAssetId = asset.id
                                    viewModel.selectedClipId = nil
                                    NSApp.keyWindow?.makeFirstResponder(nil)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                }
            }
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Pie informativo: Memoria y Referencias
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
                Text("Archivos vinculados por referencia directa")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .top
            )
        }
        .background(Color(NSColor.underPageBackgroundColor))
    }

    // Tarjeta en formato cuadrícula
    @ViewBuilder
    private func mediaGridCard(asset: MediaAsset) -> some View {
        let isSelected = viewModel.selectedAssetId == asset.id

        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                MediaThumbnailView(asset: asset, size: CGSize(width: 140, height: 80))
                    .frame(maxWidth: .infinity)

                if asset.isMissing {
                    Color.black.opacity(0.65)
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Text("No encontrado")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Botón rápido de eliminar en la esquina
                Button {
                    viewModel.promptRemoveAsset(id: asset.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .padding(4)
                        .background(Color.black.opacity(0.65))
                        .foregroundColor(.white.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .help("Eliminar de la galería (Delete)")

                // Badge de duración en la esquina inferior derecha
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(asset.formattedDuration)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .padding(4)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(asset.formattedFileSize)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Button {
                viewModel.addClipToTimeline(assetId: asset.id)
            } label: {
                HStack {
                    Image(systemName: "arrow.down.to.line")
                    Text("Añadir a pista")
                }
                .font(.system(size: 10, weight: .medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .minimalCard(cornerRadius: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedAssetId = asset.id
            viewModel.selectedClipId = nil
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .contextMenu {
            if asset.isMissing {
                Button("Reconectar o reemplazar archivo...") {
                    viewModel.reconnectAsset(id: asset.id)
                }
                Divider()
            }
            Button("Añadir a la línea de tiempo") {
                viewModel.addClipToTimeline(assetId: asset.id)
            }
            if !asset.isMissing {
                Button("Mostrar en Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([asset.fileURL])
                }
            }
            Button("Reemplazar objeto / archivo...") {
                viewModel.reconnectAsset(id: asset.id)
            }
            Button("Buscar / Localizar en Finder...") {
                viewModel.reconnectAsset(id: asset.id)
            }
            Divider()
            Button("Eliminar de la galería...", role: .destructive) {
                viewModel.promptRemoveAsset(id: asset.id)
            }
        }
        .onDrag {
            NSItemProvider(object: asset.id.uuidString as NSString)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var importedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        importedURLs.append(url)
                    } else if let url = item as? URL {
                        importedURLs.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !importedURLs.isEmpty {
                viewModel.importFiles(urls: importedURLs)
            }
        }
        return true
    }
}
