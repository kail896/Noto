import SwiftUI

// MARK: - 背景纹理渲染
struct BackgroundTextureView: View {
    let texture: TextureType
    let intensity: Double

    var body: some View {
        textureView
            .opacity(min(intensity * 0.08, 0.12))
    }

    @ViewBuilder
    private var textureView: some View {
        switch texture {
        case .none:
            EmptyView()
        case .dots:
            Canvas { ctx, size in
                let spacing: CGFloat = 20
                for x in stride(from: 0, to: size.width, by: spacing) {
                    for y in stride(from: 0, to: size.height, by: spacing) {
                        let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.primary.opacity(0.6)))
                    }
                }
            }
        case .lines:
            Canvas { ctx, size in
                let spacing: CGFloat = 24
                for y in stride(from: 0, to: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y + 8))
                    path.addLine(to: CGPoint(x: size.width, y: y + 8))
                    ctx.stroke(path, with: .color(.primary.opacity(0.5)), lineWidth: 0.5)
                }
            }
        case .grid:
            Canvas { ctx, size in
                let spacing: CGFloat = 28
                for x in stride(from: 0, to: size.width, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 0.3)
                }
                for y in stride(from: 0, to: size.height, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 0.3)
                }
            }
        case .paper:
            Color.primary.opacity(0.03)
        case .linen:
            Canvas { ctx, size in
                for y in stride(from: 0, to: size.height, by: 3) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(path, with: .color(.primary.opacity(0.08)), lineWidth: 0.5)
                }
            }
        case .noise:
            LinearGradient(
                colors: [.primary.opacity(0.03), .clear, .primary.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .waves:
            Canvas { ctx, size in
                let path = Path { p in
                    let w = size.width
                    let h = size.height
                    p.move(to: CGPoint(x: 0, y: h * 0.5))
                    for x in stride(from: 0, to: w, by: 2) {
                        let y = h * 0.5 + sin(x * 0.025) * 8 + sin(x * 0.05) * 4
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                ctx.stroke(path, with: .color(.primary.opacity(0.4)), lineWidth: 1)
                // Second wave
                let path2 = Path { p in
                    let w = size.width
                    let h = size.height
                    p.move(to: CGPoint(x: 0, y: h * 0.6))
                    for x in stride(from: 0, to: w, by: 2) {
                        let y = h * 0.6 + cos(x * 0.03) * 6 + cos(x * 0.07) * 3
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                ctx.stroke(path2, with: .color(.primary.opacity(0.25)), lineWidth: 0.8)
            }
        case .carbon:
            Canvas { ctx, size in
                let spacing: CGFloat = 16
                let radius: CGFloat = 2
                for row in 0..<Int(size.height / spacing + 1) {
                    for col in 0..<Int(size.width / spacing + 1) {
                        let offsetX = row.isMultiple(of: 2) ? spacing / 2 : 0
                        let x = CGFloat(col) * spacing + offsetX
                        let y = CGFloat(row) * spacing
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.primary.opacity(0.35)))
                    }
                }
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var toHex: String {
        guard let components = cgColor?.components, components.count >= 3 else { return "#000000" }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
