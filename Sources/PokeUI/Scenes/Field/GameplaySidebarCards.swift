import CoreGraphics
import ImageIO
import SwiftUI
import PokeDataModel

struct GameplaySidebar: View {
    let profile: TrainerProfileProps
    let party: PartySidebarProps
    let inventory: InventorySidebarProps
    let save: SaveSidebarProps
    let options: OptionsSidebarProps
    @Binding var fieldRenderStyle: FieldRenderStyle

    @State private var expansionState = GameplaySidebarExpansionState()

    var body: some View {
        VStack(spacing: GameplayFieldMetrics.sidebarSectionSpacing) {
            AccordionSidebarCard(
                title: "Trainer",
                summary: profile.locationName,
                isExpanded: expansionState.expandedSection == .trainer
            ) {
                expansionState.activate(.trainer)
            } content: {
                TrainerProfileContent(props: profile)
            }

            AccordionSidebarCard(
                title: "Party",
                summary: "\(party.pokemon.count)/\(party.totalSlots)",
                isExpanded: expansionState.expandedSection == .party
            ) {
                expansionState.activate(.party)
            } content: {
                PartySidebarContent(props: party)
            }

            AccordionSidebarCard(
                title: inventory.title,
                summary: inventory.items.isEmpty ? "Empty" : "\(inventory.items.count)",
                isExpanded: expansionState.expandedSection == .bag
            ) {
                expansionState.activate(.bag)
            } content: {
                InventorySidebarContent(props: inventory)
            }

            AccordionSidebarCard(
                title: save.title,
                summary: "Locked",
                isExpanded: expansionState.expandedSection == .save
            ) {
                expansionState.activate(.save)
            } content: {
                SaveSidebarContent(props: save)
            }

            AccordionSidebarCard(
                title: options.title,
                summary: fieldRenderStyle.sidebarSummaryLabel,
                isExpanded: expansionState.expandedSection == .options
            ) {
                expansionState.activate(.options)
            } content: {
                OptionsSidebarContent(
                    props: options,
                    fieldRenderStyle: $fieldRenderStyle
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.24, extraBounce: 0), value: expansionState.expandedSection)
    }
}

private struct TrainerProfileContent: View {
    let props: TrainerProfileProps

    private var badgeCount: Int {
        props.badges.filter(\.isEarned).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                TrainerPortraitTile(props: props.portrait, fallbackName: props.trainerName)

                VStack(alignment: .leading, spacing: 6) {
                    Text(props.trainerName.uppercased())
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(FieldRetroPalette.ink)
                    Text(props.locationName)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(FieldRetroPalette.ink.opacity(0.7))
                }
            }

            TrainerInfoRow(label: "Money", value: props.moneyText)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    GameBoyPixelText(
                        "BADGES",
                        scale: 1.5,
                        color: FieldRetroPalette.ink.opacity(0.52),
                        fallbackFont: .system(size: 11, weight: .bold, design: .rounded)
                    )
                    Spacer(minLength: 8)
                    Text(props.badgeSummaryText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(FieldRetroPalette.ink.opacity(0.72))
                }

                TrainerBadgeStrip(badges: props.badges)

                Text("\(badgeCount) earned")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(FieldRetroPalette.ink.opacity(0.66))
            }

            StatusStrip(items: props.statusItems)
        }
    }
}

private struct AccordionSidebarCard<Content: View>: View {
    let title: String
    let summary: String?
    let isExpanded: Bool
    let action: () -> Void
    let content: Content

    init(
        title: String,
        summary: String? = nil,
        isExpanded: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.summary = summary
        self.isExpanded = isExpanded
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            Button(action: action) {
                HStack(spacing: 10) {
                    GameBoyPixelText(
                        title.uppercased(),
                        scale: 1.5,
                        color: FieldRetroPalette.ink.opacity(0.6),
                        fallbackFont: .system(size: 12, weight: .bold, design: .rounded)
                    )

                    Spacer(minLength: 8)

                    if let summary {
                        Text(summary.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(FieldRetroPalette.ink.opacity(0.46))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FieldRetroPalette.ink.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            }
        }
        .padding(isExpanded ? 18 : 16)
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

private struct PartySidebarContent: View {
    let props: PartySidebarProps

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<props.totalSlots, id: \.self) { index in
                if props.pokemon.indices.contains(index) {
                    PartySidebarRow(
                        props: props.pokemon[index],
                        slotNumber: index + 1
                    )
                } else {
                    EmptyPartySidebarRow(slotNumber: index + 1)
                }
            }
        }
    }
}

private struct InventorySidebarContent: View {
    let props: InventorySidebarProps

    var body: some View {
        if props.items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                GameBoyPixelText(
                    props.emptyStateTitle.uppercased(),
                    scale: 1.5,
                    color: FieldRetroPalette.ink,
                    fallbackFont: .system(size: 18, weight: .bold, design: .monospaced)
                )
                Text(props.emptyStateDetail)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(FieldRetroPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(props.items) { item in
                        HStack(spacing: 12) {
                            Text(item.name.uppercased())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(FieldRetroPalette.ink)
                            Spacer(minLength: 8)
                            Text(item.quantityText)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(FieldRetroPalette.ink.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(FieldRetroPalette.slotFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: GameplayFieldMetrics.inventoryExpandedMaxHeight)
            .scrollIndicators(.hidden)
        }
    }
}

private struct SaveSidebarContent: View {
    let props: SaveSidebarProps

    var body: some View {
        VStack(spacing: 8) {
            ForEach(props.actions) { action in
                SidebarActionRow(props: action, rendersAsButton: true)
            }
        }
    }
}

private struct OptionsSidebarContent: View {
    let props: OptionsSidebarProps
    @Binding var fieldRenderStyle: FieldRenderStyle

    var body: some View {
        VStack(spacing: 8) {
            FieldRenderStyleOptionsRow(selectedStyle: $fieldRenderStyle)

            ForEach(props.rows) { row in
                SidebarActionRow(props: row, rendersAsButton: false)
            }
        }
    }
}

private struct FieldRenderStyleOptionsRow: View {
    @Binding var selectedStyle: FieldRenderStyle

    private let styles: [FieldRenderStyle] = [.dmgTinted, .dmgAuthentic, .rawGrayscale]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameBoyPixelText(
                "FIELD FILTER",
                scale: 1.5,
                color: FieldRetroPalette.ink,
                fallbackFont: .system(size: 13, weight: .bold, design: .monospaced)
            )

            HStack(spacing: 8) {
                ForEach(styles, id: \.self) { style in
                    Button {
                        selectedStyle = style
                    } label: {
                        GameBoyPixelText(
                            style.sidebarOptionTitle.uppercased(),
                            scale: 1,
                            color: buttonTextColor(for: style),
                            fallbackFont: .system(size: 11, weight: .bold, design: .monospaced)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 8)
                        .background(buttonFill(for: style), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(buttonStroke(for: style), lineWidth: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldRetroPalette.slotFill.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func buttonFill(for style: FieldRenderStyle) -> Color {
        selectedStyle == style ? FieldRetroPalette.leadSlotFill : FieldRetroPalette.cardFill.opacity(0.76)
    }

    private func buttonStroke(for style: FieldRenderStyle) -> Color {
        selectedStyle == style ? FieldRetroPalette.ink.opacity(0.5) : FieldRetroPalette.ink.opacity(0.14)
    }

    private func buttonTextColor(for style: FieldRenderStyle) -> Color {
        selectedStyle == style ? FieldRetroPalette.ink : FieldRetroPalette.ink.opacity(0.72)
    }
}

private struct SidebarActionRow: View {
    let props: SidebarActionRowProps
    let rendersAsButton: Bool

    var body: some View {
        Group {
            if rendersAsButton {
                Button(action: {}) {
                    rowBody
                }
                .buttonStyle(.plain)
                .disabled(true)
            } else {
                rowBody
            }
        }
        .opacity(props.isEnabled ? 1 : 0.58)
    }

    private var rowBody: some View {
        HStack(spacing: 12) {
            GameBoyPixelText(
                props.title.uppercased(),
                scale: 1.5,
                color: FieldRetroPalette.ink,
                fallbackFont: .system(size: 13, weight: .bold, design: .monospaced)
            )
            Spacer(minLength: 8)
            if let detail = props.detail {
                Text(detail.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(FieldRetroPalette.ink.opacity(0.66))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldRetroPalette.slotFill.opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TrainerInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            GameBoyPixelText(
                label.uppercased(),
                scale: 1.5,
                color: FieldRetroPalette.ink.opacity(0.52),
                fallbackFont: .system(size: 11, weight: .bold, design: .rounded)
            )
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldRetroPalette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FieldRetroPalette.slotFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TrainerBadgeStrip: View {
    let badges: [TrainerBadgeProps]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(badges) { badge in
                Text(badge.shortLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(badge.isEarned ? FieldRetroPalette.ink : FieldRetroPalette.ink.opacity(0.32))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        badge.isEarned ? FieldRetroPalette.leadSlotFill : FieldRetroPalette.slotFill.opacity(0.54),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(FieldRetroPalette.outline.opacity(badge.isEarned ? 0.2 : 0.08), lineWidth: 1)
                    }
            }
        }
    }
}

private struct PartySidebarRow: View {
    let props: PartySidebarPokemonProps
    let slotNumber: Int

    @State private var isHovered = false

    var body: some View {
        HoverCardPresenter(
            isPresented: isHovered,
            cardSide: .leading,
            cardWidth: PartyPokemonHoverCard.layoutWidth,
            spacing: GameplayFieldMetrics.hoverCardSpacing
        ) {
            HStack(alignment: .top, spacing: 12) {
                PartyPokemonSpriteTile(props: props)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(slotNumber)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(FieldRetroPalette.ink.opacity(0.58))
                            .frame(width: 16, alignment: .leading)

                        Text(props.displayName.uppercased())
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(FieldRetroPalette.ink)

                        Spacer(minLength: 8)

                        Text("Lv\(props.level)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(FieldRetroPalette.ink.opacity(0.7))
                    }

                    HStack(spacing: 10) {
                        PartyHPBar(currentHP: props.currentHP, maxHP: props.maxHP)
                            .frame(maxWidth: .infinity)

                        Text("HP \(props.currentHP)/\(props.maxHP)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(FieldRetroPalette.ink.opacity(0.72))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(props.isLead ? FieldRetroPalette.leadSlotFill : FieldRetroPalette.slotFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(props.isLead ? FieldRetroPalette.outline.opacity(0.28) : FieldRetroPalette.outline.opacity(0.14), lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: 14))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHovered = hovering
                }
            }
        } hoverCard: {
            PartyPokemonHoverCard(props: props)
        }
        .zIndex(isHovered ? 1 : 0)
    }
}

private struct EmptyPartySidebarRow: View {
    let slotNumber: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(slotNumber)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(FieldRetroPalette.ink.opacity(0.42))
                .frame(width: 16, alignment: .leading)

            Text("---")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(FieldRetroPalette.ink.opacity(0.36))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(FieldRetroPalette.slotFill.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PartyHPBar: View {
    let currentHP: Int
    let maxHP: Int

    private var hpFraction: CGFloat {
        CGFloat(currentHP) / CGFloat(max(1, maxHP))
    }

    private var barColor: Color {
        switch hpFraction {
        case ..<0.25:
            return Color(red: 0.63, green: 0.27, blue: 0.24)
        case ..<0.5:
            return Color(red: 0.72, green: 0.55, blue: 0.21)
        default:
            return Color(red: 0.37, green: 0.52, blue: 0.26)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width * hpFraction)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(FieldRetroPalette.track)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(barColor)
                    .frame(width: width)
            }
        }
        .frame(height: 10)
    }
}

private struct PartyPokemonSpriteTile: View {
    let props: PartySidebarPokemonProps

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FieldRetroPalette.portraitFill.opacity(0.9))

            if let spriteURL = props.spriteURL {
                PixelAssetView(url: spriteURL, label: props.displayName)
                    .padding(4)
            } else {
                Text(String(props.displayName.prefix(2)).uppercased())
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(FieldRetroPalette.ink)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FieldRetroPalette.outline.opacity(0.18), lineWidth: 1)
        }
        .frame(width: 46, height: 46)
    }
}

private struct PartyPokemonHoverCard: View {
    static let layoutWidth: CGFloat = 248

    let props: PartySidebarPokemonProps

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PartyPokemonLargeSpriteTile(props: props)

                VStack(alignment: .leading, spacing: 6) {
                    Text(props.displayName.uppercased())
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(FieldRetroPalette.ink)

                    HStack(spacing: 6) {
                        ForEach(props.typeLabels, id: \.self) { typeLabel in
                            Text(typeLabel)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(FieldRetroPalette.ink.opacity(0.82))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(FieldRetroPalette.slotFill, in: Capsule())
                        }
                    }

                    Text("Lv\(props.level)  HP \(props.currentHP)/\(props.maxHP)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(FieldRetroPalette.ink.opacity(0.72))
                }
            }

            if let baseHP = props.baseHP,
               let baseAttack = props.baseAttack,
               let baseDefense = props.baseDefense,
               let baseSpeed = props.baseSpeed,
               let baseSpecial = props.baseSpecial {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                    PartyPokemonStatPill(label: "HP", value: baseHP)
                    PartyPokemonStatPill(label: "ATK", value: baseAttack)
                    PartyPokemonStatPill(label: "DEF", value: baseDefense)
                    PartyPokemonStatPill(label: "SPD", value: baseSpeed)
                    PartyPokemonStatPill(label: "SPC", value: baseSpecial)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("MOVES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(FieldRetroPalette.ink.opacity(0.56))

                if props.moveNames.isEmpty {
                    Text("No moves known")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(FieldRetroPalette.ink.opacity(0.62))
                } else {
                    ForEach(Array(props.moveNames.enumerated()), id: \.offset) { _, moveName in
                        Text(moveName.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(FieldRetroPalette.ink)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: Self.layoutWidth, alignment: .leading)
        .background(FieldRetroPalette.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(FieldRetroPalette.outline.opacity(0.18), lineWidth: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.34), lineWidth: 1)
                        .padding(5)
                }
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
    }
}

private struct PartyPokemonLargeSpriteTile: View {
    let props: PartySidebarPokemonProps

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FieldRetroPalette.portraitFill)

            if let spriteURL = props.spriteURL {
                PixelAssetView(url: spriteURL, label: props.displayName)
                    .padding(6)
            } else {
                Text(String(props.displayName.prefix(2)).uppercased())
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(FieldRetroPalette.ink)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FieldRetroPalette.outline.opacity(0.18), lineWidth: 1)
        }
        .frame(width: 76, height: 76)
    }
}

private struct PartyPokemonStatPill: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: 8)
            Text("\(value)")
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(FieldRetroPalette.ink.opacity(0.82))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(FieldRetroPalette.slotFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StatusStrip: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                GameBoyPixelText(
                    item.uppercased(),
                    scale: 1,
                    color: FieldRetroPalette.ink.opacity(0.74),
                    fallbackFont: .system(size: 10, weight: .bold, design: .monospaced)
                )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(FieldRetroPalette.slotFill, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrainerPortraitTile: View {
    let props: TrainerPortraitProps
    let fallbackName: String

    private var monogram: String {
        let trimmed = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "TR"
        }

        let pieces = trimmed.split(separator: " ")
        if pieces.count >= 2 {
            return pieces
                .prefix(2)
                .compactMap { $0.first.map(String.init) }
                .joined()
                .uppercased()
        }

        return String(trimmed.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(FieldRetroPalette.portraitFill)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FieldRetroPalette.outline.opacity(0.24), lineWidth: 2)
                .padding(6)

            VStack(spacing: 5) {
                if let spriteURL = props.spriteURL,
                   let spriteFrame = props.spriteFrame {
                    PixelSpriteFrameView(url: spriteURL, frame: spriteFrame, label: props.label)
                        .frame(width: 42, height: 42)
                } else {
                    Text(monogram)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(FieldRetroPalette.ink)
                }

                GameBoyPixelText(
                    "TRAINER",
                    scale: 1,
                    color: FieldRetroPalette.ink.opacity(0.6),
                    fallbackFont: .system(size: 9, weight: .bold, design: .rounded)
                )
            }
        }
        .frame(width: 84, height: 84)
    }
}

private struct PixelSpriteFrameView: View {
    let url: URL
    let frame: PixelRect
    let label: String

    var body: some View {
        Group {
            if let image = croppedFrameImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: frame.flippedHorizontally ? -1 : 1, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.black.opacity(0.12))
                    .overlay {
                        Text("??")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(FieldRetroPalette.ink.opacity(0.6))
                    }
            }
        }
        .accessibilityLabel(label)
    }

    private var croppedFrameImage: CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let croppedImage = image.cropping(to: CGRect(x: frame.x, y: frame.y, width: frame.width, height: frame.height).integral),
              let maskedImage = applyTransparencyMask(to: croppedImage) else {
            return nil
        }
        return maskedImage
    }

    private func applyTransparencyMask(to image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width
        var grayscaleBytes = [UInt8](repeating: 0, count: width * height)

        guard let grayscaleContext = CGContext(
            data: &grayscaleBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        grayscaleContext.interpolationQuality = .none
        grayscaleContext.setShouldAntialias(false)
        grayscaleContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let maskBytes = grayscaleBytes.map { $0 == 255 ? UInt8(255) : UInt8(0) }
        let maskData = Data(maskBytes) as CFData

        guard let provider = CGDataProvider(data: maskData),
              let mask = CGImage(
                maskWidth: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                provider: provider,
                decode: nil,
                shouldInterpolate: false
              ) else {
            return nil
        }

        return image.masking(mask)
    }
}

private struct HoverCardPresenter<Content: View, HoverCard: View>: View {
    enum CardSide {
        case leading
        case trailing
    }

    let isPresented: Bool
    let cardSide: CardSide
    let cardWidth: CGFloat
    let spacing: CGFloat
    let content: Content
    let hoverCard: HoverCard

    init(
        isPresented: Bool,
        cardSide: CardSide,
        cardWidth: CGFloat,
        spacing: CGFloat,
        @ViewBuilder content: () -> Content,
        @ViewBuilder hoverCard: () -> HoverCard
    ) {
        self.isPresented = isPresented
        self.cardSide = cardSide
        self.cardWidth = cardWidth
        self.spacing = spacing
        self.content = content()
        self.hoverCard = hoverCard()
    }

    var body: some View {
        content
            .overlay(alignment: overlayAlignment) {
                if isPresented {
                    hoverCard
                        .frame(width: cardWidth, alignment: .leading)
                        .offset(x: horizontalOffset)
                        .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.14), value: isPresented)
    }

    private var overlayAlignment: Alignment {
        switch cardSide {
        case .leading:
            return .topLeading
        case .trailing:
            return .topTrailing
        }
    }

    private var horizontalOffset: CGFloat {
        switch cardSide {
        case .leading:
            return -(cardWidth + spacing)
        case .trailing:
            return spacing
        }
    }
}
