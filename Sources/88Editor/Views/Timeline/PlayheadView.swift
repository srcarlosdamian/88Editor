import SwiftUI

/// Cabezal de reproducción (Playhead) sincronizado en tiempo real con el canvas
public struct PlayheadView: View {
    let positionX: CGFloat
    let height: CGFloat

    public var body: some View {
        ZStack(alignment: .top) {
            // Línea vertical
            Rectangle()
                .fill(DesignSystem.playhead)
                .frame(width: 2, height: height)

            // Cabezal triangular superior
            PlayheadNeedleShape()
                .fill(DesignSystem.playhead)
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .position(x: positionX, y: height / 2)
        .allowsHitTesting(false)
    }
}

/// Forma de aguja indicadora del playhead
public struct PlayheadNeedleShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
