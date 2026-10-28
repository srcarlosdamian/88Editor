import SwiftUI
import UniformTypeIdentifiers

/// Pista individual de la línea de tiempo multicapa no magnética y responsiva.
/// Soporta zoom vertical dinámico (altura de pista) y zoom horizontal en video y audio.
public struct TimelineTrackView: View {
    let track: TimelineTrack
    @ObservedObject var viewModel: EditorViewModel
    let timelineWidth: CGFloat

    @State private var isDropTargeted: Bool = false
    @State private var isEditingName: Bool = false
    @State private var tempName: String = ""

    public var body: some View {
        let currentHeight = viewModel.trackHeight

        HStack(spacing: 0) {
            // Cabecera lateral de la capa (160px con nombre editable)
            HStack(spacing: 6) {
                // Etiqueta con nombre de la capa (Doble clic o clic derecho para renombrar)
                if isEditingName {
                    TextField("Capa...", text: $tempName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(4)
                        .frame(maxWidth: 80)
                        .onSubmit {
                            viewModel.renameTrack(id: track.id, newName: tempName)
                            isEditingName = false
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                } else {
                    Text(track.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.12))
                        .cornerRadius(4)
                        .frame(maxWidth: 82, alignment: .leading)
                        .onTapGesture(count: 2) {
                            tempName = track.name
                            isEditingName = true
                        }
                        .help("Doble clic para renombrar esta capa")
                }

                Image(systemName: track.kind.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                // Botón Ocultar
                Button {
                    viewModel.toggleHideTrack(id: track.id)
                } label: {
                    Image(systemName: track.isHidden ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 10))
                        .foregroundColor(track.isHidden ? .primary.opacity(0.35) : .secondary)
                }
                .buttonStyle(.plain)
                .help(track.isHidden ? "Mostrar capa" : "Ocultar capa")

                // Botón Silenciar
                Button {
                    viewModel.toggleMuteTrack(id: track.id)
                } label: {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(track.isMuted ? .primary.opacity(0.35) : .secondary)
                }
                .buttonStyle(.plain)
                .help(track.isMuted ? "Reactivar sonido" : "Silenciar capa")

                // Botón Bloquear
                Button {
                    viewModel.toggleLockTrack(id: track.id)
                } label: {
                    Image(systemName: track.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 10))
                        .foregroundColor(track.isLocked ? .primary : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help(track.isLocked ? "Desbloquear capa" : "Bloquear capa")
            }
            .padding(.horizontal, 8)
            .frame(width: 160, height: currentHeight)
            .background(Color(NSColor.controlBackgroundColor))
            .contextMenu {
                Button("Subir capa en jerarquía (adelante)") {
                    viewModel.moveTrackUp(id: track.id)
                }
                Button("Bajar capa en jerarquía (atrás)") {
                    viewModel.moveTrackDown(id: track.id)
                }
                Divider()
                Button("Renombrar capa...") {
                    tempName = track.name
                    isEditingName = true
                }
                Button("Duplicar capa completa") {
                    viewModel.duplicateTrack(id: track.id)
                }
                Divider()
                Button("Eliminar capa", role: .destructive) {
                    viewModel.deleteTrack(id: track.id)
                }
            }
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(DesignSystem.border),
                alignment: .trailing
            )

            // Carril de clips expansivo que ocupa el 100% del ancho disponible
            ZStack(alignment: .leading) {
                // Fondo del carril
                Rectangle()
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color(NSColor.underPageBackgroundColor).opacity(0.5))
                    .frame(width: timelineWidth, height: currentHeight)

                // Línea inferior divisoria
                Rectangle()
                    .fill(DesignSystem.border)
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // Clips posicionados libremente en este carril
                ForEach(track.clips) { clip in
                    TimelineClipView(
                        clip: clip,
                        isSelected: viewModel.selectedClipId == clip.id,
                        zoom: viewModel.timelineZoom,
                        isTrackLocked: track.isLocked,
                        height: currentHeight,
                        isAudioTrack: track.kind == .audio,
                        availableTracks: viewModel.project.tracks,
                        currentTrack: track,
                        onSelect: {
                            viewModel.selectedClipId = clip.id
                        },
                        onMove: { newStart, verticalDelta in
                            let allTracks = viewModel.project.tracks
                            let currentIdx = allTracks.firstIndex(where: { $0.id == track.id }) ?? 0
                            let rowDelta = Int(round(verticalDelta / currentHeight))
                            let targetIdx = max(0, min(allTracks.count - 1, currentIdx + rowDelta))
                            let targetTrack = allTracks[targetIdx]
                            let finalTrackId = (targetTrack.kind == track.kind) ? targetTrack.id : track.id
                            viewModel.moveClip(clipId: clip.id, newStartTime: newStart, targetTrackId: finalTrackId)
                        },
                        onMoveToSpecificTrack: { targetId in
                            viewModel.moveClip(clipId: clip.id, newStartTime: clip.startTime, targetTrackId: targetId)
                        },
                        onDragging: { proposedTime in
                            viewModel.updateLiveSnapPreview(candidateStartTime: proposedTime, clipDuration: clip.duration, clipId: clip.id)
                        },
                        onDragEnded: {
                            viewModel.clearSnapGuide()
                        },
                        onTrimIn: { delta in
                            viewModel.trimClipIn(clipId: clip.id, deltaSeconds: delta)
                        },
                        onTrimOut: { delta in
                            viewModel.trimClipOut(clipId: clip.id, deltaSeconds: delta)
                        },
                        onDuplicate: {
                            viewModel.duplicateClip(id: clip.id)
                        },
                        onCopy: {
                            viewModel.selectedClipId = clip.id
                            viewModel.copySelectedClip()
                        },
                        onPaste: {
                            viewModel.pasteClipAtPlayhead(targetTrackId: track.id)
                        },
                        onSplit: {
                            viewModel.selectedClipId = clip.id
                            viewModel.splitSelectedClipAtPlayhead()
                        },
                        onToggleMute: {
                            viewModel.selectedClipId = clip.id
                            viewModel.toggleMuteSelectedClip()
                        },
                        onDelete: {
                            viewModel.selectedClipId = clip.id
                            viewModel.deleteSelectedClip()
                        },
                        isMissing: viewModel.asset(for: clip)?.isMissing ?? false,
                        onReconnect: {
                            viewModel.reconnectAsset(id: clip.assetId)
                        }
                    )
                }
            }
            .frame(width: timelineWidth, height: currentHeight)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.fileURL.identifier, UTType.plainText.identifier], isTargeted: $isDropTargeted) { providers in
                handleDropToTrack(providers: providers)
            }
        }
    }

    private func handleDropToTrack(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // A) Arrastre desde el Media Pool interno
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let rawStr = item as? String ?? (item as? Data).flatMap({ String(data: $0, encoding: .utf8) }),
                       let assetUuid = UUID(uuidString: rawStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        DispatchQueue.main.async {
                            viewModel.addClipToTimeline(assetId: assetUuid, targetTrackId: track.id)
                        }
                    }
                }
                return true
            }

            // B) Arrastre directo de archivos desde Finder
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = item as? URL ?? (item as? Data).flatMap({ URL(dataRepresentation: $0, relativeTo: nil) }) {
                        DispatchQueue.main.async {
                            viewModel.importFiles(urls: [url])
                            if let newAsset = viewModel.project.assets.last {
                                viewModel.addClipToTimeline(assetId: newAsset.id, targetTrackId: track.id)
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
