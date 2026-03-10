import SwiftUI

enum GameplayFieldMetrics {
    static let sidebarWidth: CGFloat = 320
    static let outerPadding: CGFloat = 24
    static let interColumnSpacing: CGFloat = 20
    static let sidebarSectionSpacing: CGFloat = 12
    static let hoverCardSpacing: CGFloat = 12
    static let inventoryExpandedMaxHeight: CGFloat = 210
}

struct RetroSidebarCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(FieldRetroPalette.ink.opacity(0.6))

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldRetroPalette.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FieldRetroPalette.outline.opacity(0.18), lineWidth: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.34), lineWidth: 1)
                        .padding(6)
                }
        }
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}

enum FieldRetroPalette {
    static let ink = Color(red: 0.16, green: 0.18, blue: 0.12)
    static let outline = Color.black
    static let cardFill = Color(red: 0.88, green: 0.9, blue: 0.78)
    static let slotFill = Color(red: 0.8, green: 0.84, blue: 0.69)
    static let leadSlotFill = Color(red: 0.74, green: 0.8, blue: 0.63)
    static let track = Color(red: 0.55, green: 0.62, blue: 0.49)
    static let portraitFill = Color(red: 0.76, green: 0.82, blue: 0.68)
    static let stageOuter = Color(red: 0.68, green: 0.74, blue: 0.58)
    static let stageMiddle = Color(red: 0.79, green: 0.84, blue: 0.68)
    static let stageInner = Color(red: 0.92, green: 0.92, blue: 0.84)
}
