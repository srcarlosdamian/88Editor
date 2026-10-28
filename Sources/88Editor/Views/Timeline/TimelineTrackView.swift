import SwiftUI
import UniformTypeIdentifiers

/// Pista individual de la línea de tiempo multicapa no magnética y responsiva.
/// Soporta zoom vertical dinámico (altura de pista) y zoom horizontal en video y audio.
public struct TimelineTrackView: View {
    let track: TimelineTrack
    @ObservedObject var viewModel: EditorViewModel
    let timelineWidth: CGFloat

    @State private var isDropTargeted: Bool = false
    @State private var isHeaderDropTargeted: Bool = false
    @State private var isEditingName: Bool = false
    @State private var tempName: String = ""
    @State private var isDraggingHeader: Bool = false
    @State private var headerDragDeltaY: CGFloat = 0

    public var body: some View {
        let currentHeight = viewModel.trackHeight

        HStack(spacing: 0) {
            // Cabecera lateral de la capa (160px con nombre de capa y controles nativos)
            HStack(spacing: 6) {
                // Nombre legible de la capa (sin cajas grises ni iconos innecesarios)
                if isEditingName {
                    TextField("Capa...", text: $tempName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(3)
                        .frame(maxWidth: .infinity)
                        .onSubmit {
                            viewModel.renameTrack(id: track.id, newName: tempName)
                            isEditingName = false
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                } else {
                    Text(cleanTrackName(track.name))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            tempName = track.name
                            isEditingName = true
                        }
                        .help("Doble clic para renombrar capa")
                }

                // Controles de pista alineados a la derecha
                HStack(spacing: 5) {
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

                    // Tirador de arrastre / reordenar capa
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isDraggingHeader ? .primary : .secondary.opacity(0.55))
                        .frame(width: 12, height: currentHeight)
                        .contentShape(Rectangle())
                        .help("Arrastrar capa para reordenar arriba o abajo")
                        .gesture(
                            DragGesture()
                                .onChanged { val in
                                    isDraggingHeader = true
                                    headerDragDeltaY = val.translation.height
                                    if headerDragDeltaY <= -currentHeight * 0.65 {
                                        viewModel.moveTrackUp(id: track.id)
                                        headerDragDeltaY = 0
                                    } else if headerDragDeltaY >= currentHeight * 0.65 {
                                        viewModel.moveTrackDown(id: track.id)
                                        headerDragDeltaY = 0
                                    }
                                }
                                .onEnded { _ in
                                    isDraggingHeader = false
                                    headerDragDeltaY = 0
                                }
                        )
                }
            }
            .padding(.horizontal, 8)
            .frame(width: 160, height: currentHeight)
            .background(
                isHeaderDropTargeted
                    ? Color.white.opacity(0.18)
                    : (isDraggingHeader ? Color(NSColor.selectedContentBackgroundColor).opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .offset(y: headerDragDeltaY)
            .zIndex(isDraggingHeader ? 99 : 1)
            .shadow(color: Color.black.opacity(isDraggingHeader ? 0.4 : 0), radius: 6, x: 0, y: 3)
            .onDrag {
                NSItemProvider(object: "track:\(track.id.uuidString)" as NSString)
            }
            .onDrop(of: [UTType.plainText.identifier], isTargeted: $isHeaderDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let rawStr = item as? String ?? (item as? Data).flatMap({ String(data: $0, encoding: .utf8) }),
                       rawStr.hasPrefix("track:"),
                       let draggedUUID = UUID(uuidString: String(rawStr.dropFirst(6))) {
                        DispatchQueue.main.async {
                            viewModel.reorderTrack(fromId: draggedUUID, toTargetId: track.id)
                        }
                    }
                }
                return true
            }
            .contextMenu {
                Button {
                    viewModel.bringTrackToFront(id: track.id)
                } label: {
                    Label("Traer al Frente (Capa Superior)", systemImage: "arrow.up.to.line")
                }

                Button {
                    viewModel.moveTrackUp(id: track.id)
                } label: {
                    Label("Subir Capa (Traer hacia adelante)", systemImage: "arrow.up")
                }

                Button {
                    viewModel.moveTrackDown(id: track.id)
                } label: {
                    Label("Bajar Capa (Enviar hacia atrás)", systemImage: "arrow.down")
                }

                Button {
                    viewModel.sendTrackToBack(id: track.id)
                } label: {
                    Label("Enviar al Fondo (Capa Inferior)", systemImage: "arrow.down.to.line")
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
                // Fondo del carril con clic/arrastre inmediato para mover el cabezal (Seek)
                Rectangle()
                    .fill(isDropTargeted ? Color.white.opacity(0.12) : Color(NSColor.underPageBackgroundColor).opacity(0.5))
                    .frame(width: timelineWidth, height: currentHeight)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let clickedTime = max(0.0, Double(value.location.x) / viewModel.timelineZoom)
                                viewModel.playbackEngine.seek(to: clickedTime)
                                viewModel.selectedClipId = nil
                                viewModel.selectedTrackId = track.id
                            }
                    )
                    .contextMenu {
                        if viewModel.clipboardClip != nil {
                            Button {
                                viewModel.pasteClipAtPlayhead(targetTrackId: track.id)
                            } label: {
                                Label("Pegar en Cabezal (⌘V)", systemImage: "doc.on.clipboard")
                            }
                        }

                        Button {
                            viewModel.splitSelectedClipAtPlayhead()
                        } label: {
                            Label("Dividir en Cabezal (⌘B)", systemImage: "scissors")
                        }

                        Divider()

                        Button {
                            viewModel.insertSheetCategory = .text
                            viewModel.isInsertSheetPresented = true
                        } label: {
                            Label("Añadir Capa de Texto...", systemImage: "textformat")
                        }

                        Button {
                            viewModel.insertSheetCategory = .shape
                            viewModel.isInsertSheetPresented = true
                        } label: {
                            Label("Añadir Capa de Forma...", systemImage: "square.on.circle")
                        }

                        Divider()

                        Menu("Orden de Capas") {
                            Button {
                                viewModel.bringTrackToFront(id: track.id)
                            } label: {
                                Label("Traer al Frente (Capa Superior)", systemImage: "arrow.up.to.line")
                            }

                            Button {
                                viewModel.moveTrackUp(id: track.id)
                            } label: {
                                Label("Subir Capa (Traer adelante)", systemImage: "arrow.up")
                            }

                            Button {
                                viewModel.moveTrackDown(id: track.id)
                            } label: {
                                Label("Bajar Capa (Enviar atrás)", systemImage: "arrow.down")
                            }

                            Button {
                                viewModel.sendTrackToBack(id: track.id)
                            } label: {
                                Label("Enviar al Fondo (Capa Inferior)", systemImage: "arrow.down.to.line")
                            }
                        }

                        Button {
                            viewModel.duplicateTrack(id: track.id)
                        } label: {
                            Label("Duplicar Capa Completa", systemImage: "plus.square.on.square")
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.deleteTrack(id: track.id)
                        } label: {
                            Label("Eliminar Capa", systemImage: "trash")
                        }
                    }

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
                        onCut: {
                            viewModel.cutClip(id: clip.id)
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
                        },
                        onCrop: {
                            viewModel.selectedClipId = clip.id
                            viewModel.selectedTrackId = track.id
                            viewModel.openCropModal(for: clip)
                        },
                        onResetCrop: {
                            viewModel.selectedClipId = clip.id
                            viewModel.selectedTrackId = track.id
                            viewModel.updateSelectedClip {
                                $0.cropLeft = 0.0
                                $0.cropRight = 0.0
                                $0.cropTop = 0.0
                                $0.cropBottom = 0.0
                            }
                            viewModel.recordHistory(title: "Restablecer recorte", icon: "crop")
                        },
                        onResetTransform: {
                            viewModel.resetTransform(for: clip.id)
                        },
                        onCenterInCanvas: {
                            viewModel.centerClipInCanvas(clipId: clip.id)
                        },
                        onMoveTrackUp: {
                            viewModel.moveTrackUp(id: track.id)
                        },
                        onMoveTrackDown: {
                            viewModel.moveTrackDown(id: track.id)
                        },
                        onBringToFront: {
                            viewModel.bringTrackToFront(id: track.id)
                        },
                        onSendToBack: {
                            viewModel.sendTrackToBack(id: track.id)
                        },
                        playheadTime: viewModel.playbackEngine.currentTime,
                        onSeekToKeyframe: { kfTime in
                            viewModel.playbackEngine.seek(to: kfTime)
                        },
                        onUpdateKeyframeValue: { prop, kfId, newVal in
                            viewModel.updateKeyframeDirectly(clipId: clip.id, property: prop, keyframeId: kfId, newValue: newVal)
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
                            // Cada elemento arrastrado recibe su propia pista/capa independiente
                            viewModel.addClipToTimeline(assetId: assetUuid, targetTrackId: nil)
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
                                // Cada elemento arrastrado recibe su propia pista/capa independiente
                                viewModel.addClipToTimeline(assetId: newAsset.id, targetTrackId: nil)
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func cleanTrackName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dashIdx = trimmed.range(of: " - ") {
            return String(trimmed[..<dashIdx.lowerBound])
        }
        return trimmed
    }
}
