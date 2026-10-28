import SwiftUI
import AppKit

/// Vista del logotipo oficial de 88 Editor en un cuadrado con bordes redondeados (estilo macOS App Icon).
public struct AppLogoIconView: View {
    public var size: CGFloat
    public var cornerRadius: CGFloat

    public init(size: CGFloat = 24, cornerRadius: CGFloat = 5) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        if let iconImage = loadAppIcon() {
            Image(nsImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(red: 0.9, green: 0.1, blue: 0.1))
                    .frame(width: size, height: size)

                Text("88")
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    private func loadAppIcon() -> NSImage? {
        if let url = Bundle.module.url(forResource: "AppIcon_Rounded", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let fallback = NSImage(contentsOfFile: "Sources/88Editor/Resources/AppIcon_Rounded.png") {
            return fallback
        }
        if let raw = NSImage(contentsOfFile: "Sources/88Editor/Resources/AppIcon.png") {
            return raw
        }
        return nil
    }
}
