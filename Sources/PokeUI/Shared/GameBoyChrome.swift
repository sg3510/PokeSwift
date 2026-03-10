import SwiftUI

public enum GameBoyScreenStyle: Sendable {
    case classic
    case fieldShell
}

public struct GameBoyScreen<Content: View>: View {
    private let style: GameBoyScreenStyle
    private let content: Content

    public init(style: GameBoyScreenStyle = .classic, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    public var body: some View {
        ZStack {
            GameBoyScreenBackground(style: style)
            content
        }
        .overlay {
            GameBoyGridOverlay(style: style)
        }
    }
}

public struct GameBoyPanel<Content: View>: View {
    private let content: Content
    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(18)
            .background(Color.white.opacity(0.18), in: shape)
            .overlay {
                shape
                    .stroke(.black.opacity(0.08), lineWidth: 1)
            }
            .glassEffect(
                .regular.tint(Color(red: 0.82, green: 0.91, blue: 0.78).opacity(0.38)),
                in: shape
            )
            .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
}

public struct PlainWhitePanel<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(18)
            .background(.white)
    }
}

private struct GameBoyGridOverlay: View {
    let style: GameBoyScreenStyle

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let spacing: CGFloat = 8
                var columns = Path()
                var rows = Path()
                let dotSize: CGFloat = 1.2

                var x: CGFloat = 0
                while x <= size.width {
                    columns.move(to: CGPoint(x: x, y: 0))
                    columns.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }

                var y: CGFloat = 0
                while y <= size.height {
                    rows.move(to: CGPoint(x: 0, y: y))
                    rows.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }

                context.stroke(columns, with: .color(.black.opacity(0.05)), lineWidth: 0.5)
                context.stroke(rows, with: .color(.black.opacity(0.035)), lineWidth: 0.5)

                var dotY: CGFloat = 0
                while dotY <= size.height {
                    var dotX: CGFloat = 0
                    while dotX <= size.width {
                        let rect = CGRect(
                            x: dotX - (dotSize / 2),
                            y: dotY - (dotSize / 2),
                            width: dotSize,
                            height: dotSize
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(gridDotColor)
                        )
                        dotX += spacing
                    }
                    dotY += spacing
                }
            }
            .overlay {
                Rectangle()
                    .fill(gridTint)
            }
            .allowsHitTesting(false)
        }
    }

    private var gridDotColor: Color {
        switch style {
        case .classic:
            return Color(red: 0.45, green: 0.5, blue: 0.35).opacity(0.12)
        case .fieldShell:
            return Color(red: 0.37, green: 0.42, blue: 0.29).opacity(0.09)
        }
    }

    private var gridTint: Color {
        switch style {
        case .classic:
            return Color(red: 0.88, green: 0.94, blue: 0.84).opacity(0.08)
        case .fieldShell:
            return Color(red: 0.94, green: 0.94, blue: 0.85).opacity(0.05)
        }
    }
}

private struct GameBoyScreenBackground: View {
    let style: GameBoyScreenStyle

    var body: some View {
        switch style {
        case .classic:
            Color.white
        case .fieldShell:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.83, green: 0.86, blue: 0.72),
                        Color(red: 0.73, green: 0.79, blue: 0.64),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.2),
                        Color.clear,
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 380
                )

                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.91, blue: 0.81).opacity(0.12),
                        Color(red: 0.39, green: 0.45, blue: 0.31).opacity(0.05),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}
