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
        if let iconImage = AppLogoIconView.getAppIconImage() {
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
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                    .frame(width: size, height: size)

                Text("88")
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    public static func getAppIconImage() -> NSImage? {
        if let icon = NSImage(named: NSImage.applicationIconName), icon.isValid {
            return icon
        }
        if let url = Bundle.main.url(forResource: "AppIcon_Rounded", withExtension: "png") ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // Generación programática de alta fidelidad si no se encuentra el asset
        let dim: CGFloat = 512
        let image = NSImage(size: NSSize(width: dim, height: dim))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: dim, height: dim)
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: 110, yRadius: 110)
        NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0).setFill()
        bgPath.fill()

        let text = "88"
        let font = NSFont.systemFont(ofSize: 220, weight: .black)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attrs)
        let textRect = NSRect(
            x: (dim - textSize.width) / 2,
            y: (dim - textSize.height) / 2 - 10,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attrs)

        image.unlockFocus()
        return image
    }
}
