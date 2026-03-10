import SwiftUI

public struct GameplayFieldShell<MapStage: View>: View {
    private let profile: TrainerProfileProps
    private let party: PartySidebarProps
    private let inventory: InventorySidebarProps
    private let save: SaveSidebarProps
    private let options: OptionsSidebarProps
    @Binding private var fieldRenderStyle: FieldRenderStyle
    private let mapStage: MapStage

    public init(
        profile: TrainerProfileProps,
        party: PartySidebarProps,
        inventory: InventorySidebarProps,
        save: SaveSidebarProps,
        options: OptionsSidebarProps,
        fieldRenderStyle: Binding<FieldRenderStyle>,
        @ViewBuilder mapStage: () -> MapStage
    ) {
        self.profile = profile
        self.party = party
        self.inventory = inventory
        self.save = save
        self.options = options
        _fieldRenderStyle = fieldRenderStyle
        self.mapStage = mapStage()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: GameplayFieldMetrics.interColumnSpacing) {
            mapStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            GameplaySidebar(
                profile: profile,
                party: party,
                inventory: inventory,
                save: save,
                options: options,
                fieldRenderStyle: $fieldRenderStyle
            )
            .frame(width: GameplayFieldMetrics.sidebarWidth)
        }
        .padding(GameplayFieldMetrics.outerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

public struct FieldMapStage<MapContent: View, Footer: View, OverlayContent: View>: View {
    private let mapContent: MapContent
    private let footer: Footer
    private let overlayContent: OverlayContent

    public init(
        @ViewBuilder mapContent: () -> MapContent,
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder overlayContent: () -> OverlayContent
    ) {
        self.mapContent = mapContent()
        self.footer = footer()
        self.overlayContent = overlayContent()
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(FieldRetroPalette.stageOuter)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(FieldRetroPalette.stageMiddle)
                .padding(10)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(FieldRetroPalette.stageInner)
                .padding(22)

            ZStack(alignment: .bottom) {
                mapContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                    .padding(.bottom, 36)

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
            }
            .padding(22)

            overlayContent
                .padding(36)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(FieldRetroPalette.outline.opacity(0.5), lineWidth: 3)
                .overlay {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                        .padding(12)
                }
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
