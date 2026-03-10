import SwiftUI
import PokeCore
import PokeDataModel

public struct FieldMapView: View {
    let map: MapManifest
    let playerPosition: TilePoint
    let playerFacing: FacingDirection
    let objects: [FieldObjectRenderState]
    let playerSpriteID: String
    let renderAssets: FieldRenderAssets?
    let renderStyle: FieldRenderStyle
    @State private var renderedField: CGImage?

    public init(
        map: MapManifest,
        playerPosition: TilePoint,
        playerFacing: FacingDirection,
        objects: [FieldObjectRenderState],
        playerSpriteID: String = "SPRITE_RED",
        renderAssets: FieldRenderAssets? = nil,
        renderStyle: FieldRenderStyle = .defaultGameplayStyle
    ) {
        self.map = map
        self.playerPosition = playerPosition
        self.playerFacing = playerFacing
        self.objects = objects
        self.playerSpriteID = playerSpriteID
        self.renderAssets = renderAssets
        self.renderStyle = renderStyle
    }

    public var body: some View {
        GeometryReader { proxy in
            let pixelWidth = CGFloat(max(1, map.blockWidth * FieldSceneRenderer.blockPixelSize))
            let pixelHeight = CGFloat(max(1, map.blockHeight * FieldSceneRenderer.blockPixelSize))
            let scale = min(proxy.size.width / pixelWidth, proxy.size.height / pixelHeight)
            let renderWidth = pixelWidth * scale
            let renderHeight = pixelHeight * scale

            ZStack {
                if let renderedField {
                    Image(decorative: renderedField, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .overlay {
                            if renderStyle != .rawGrayscale {
                                FieldPixelMatrixOverlay(pixelScale: scale, style: renderStyle)
                            }
                        }
                } else {
                    placeholderField
                }
            }
            .frame(width: renderWidth, height: renderHeight)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .task(id: renderSignature) {
            await updateRenderedField()
        }
    }

    private var renderSignature: FieldRenderSignature? {
        guard let renderAssets else { return nil }
        return FieldRenderSignature(
            map: map,
            playerPosition: playerPosition,
            playerFacing: playerFacing,
            playerSpriteID: playerSpriteID,
            objects: objects,
            assets: renderAssets,
            style: renderStyle
        )
    }

    @MainActor
    private func updateRenderedField() async {
        guard let renderAssets else {
            renderedField = nil
            return
        }

        let image = await renderFieldImage(assets: renderAssets)
        guard Task.isCancelled == false else { return }
        renderedField = image
    }

    private func renderFieldImage(assets: FieldRenderAssets) async -> CGImage? {
        let map = map
        let playerPosition = playerPosition
        let playerFacing = playerFacing
        let playerSpriteID = playerSpriteID
        let objects = objects
        let renderStyle = renderStyle

        let renderResult = await Task.detached(priority: .userInitiated) {
            try? RenderedFieldImage(
                image: FieldSceneRenderer.render(
                    map: map,
                    playerPosition: playerPosition,
                    playerFacing: playerFacing,
                    playerSpriteID: playerSpriteID,
                    objects: objects,
                    assets: assets,
                    style: renderStyle
                )
            )
        }.value
        return renderResult?.image
    }

    @ViewBuilder
    private var placeholderField: some View {
        let stepWidth = max(1, map.stepWidth)
        let stepHeight = max(1, map.stepHeight)
        let tileSize = min(
            CGFloat(map.blockWidth * FieldSceneRenderer.blockPixelSize) / CGFloat(stepWidth),
            CGFloat(map.blockHeight * FieldSceneRenderer.blockPixelSize) / CGFloat(stepHeight)
        )

        ZStack(alignment: .topLeading) {
            ForEach(0..<stepHeight, id: \.self) { y in
                ForEach(0..<stepWidth, id: \.self) { x in
                    Rectangle()
                        .fill(tileColor(x: x, y: y))
                        .frame(width: tileSize, height: tileSize)
                        .position(x: (CGFloat(x) * tileSize) + (tileSize / 2), y: (CGFloat(y) * tileSize) + (tileSize / 2))
                }
            }

            ForEach(objects, id: \.id) { object in
                Rectangle()
                    .fill(objectColor(for: object.sprite))
                    .frame(width: tileSize * 0.88, height: tileSize * 0.88)
                    .overlay {
                        Text(object.displayName.prefix(1))
                            .font(.system(size: tileSize * 0.45, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .position(x: (CGFloat(object.position.x) * tileSize) + (tileSize / 2), y: (CGFloat(object.position.y) * tileSize) + (tileSize / 2))
            }

            Capsule()
                .fill(Color.black)
                .frame(width: tileSize * 0.8, height: tileSize * 0.9)
                .overlay(alignment: overlayAlignment(for: playerFacing)) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: tileSize * 0.18, height: tileSize * 0.18)
                        .offset(directionOffset(for: playerFacing, tileSize: tileSize))
                }
                .position(x: (CGFloat(playerPosition.x) * tileSize) + (tileSize / 2), y: (CGFloat(playerPosition.y) * tileSize) + (tileSize / 2))
        }
    }

    private func tileColor(x: Int, y: Int) -> Color {
        let blockX = max(0, min(map.blockWidth - 1, x / 2))
        let blockY = max(0, min(map.blockHeight - 1, y / 2))
        let index = min(map.blockIDs.count - 1, (blockY * map.blockWidth) + blockX)
        let blockID = map.blockIDs.isEmpty ? 0 : map.blockIDs[index]
        switch map.tileset {
        case "OVERWORLD":
            return (blockID % 5 == 0) ? Color(red: 0.86, green: 0.93, blue: 0.79) : Color(red: 0.79, green: 0.87, blue: 0.73)
        case "DOJO":
            return (blockID % 4 == 0) ? Color(red: 0.96, green: 0.92, blue: 0.83) : Color(red: 0.88, green: 0.84, blue: 0.74)
        default:
            return (blockID % 3 == 0) ? Color(red: 0.93, green: 0.93, blue: 0.9) : Color(red: 0.84, green: 0.84, blue: 0.8)
        }
    }

    private func objectColor(for sprite: String) -> Color {
        switch sprite {
        case _ where sprite.contains("OAK"):
            return Color(red: 0.28, green: 0.43, blue: 0.31)
        case _ where sprite.contains("BLUE"):
            return Color(red: 0.2, green: 0.33, blue: 0.62)
        case _ where sprite.contains("POKE_BALL"):
            return Color(red: 0.75, green: 0.2, blue: 0.18)
        case _ where sprite.contains("MOM"):
            return Color(red: 0.67, green: 0.42, blue: 0.58)
        default:
            return Color(red: 0.45, green: 0.45, blue: 0.45)
        }
    }

    private func overlayAlignment(for facing: FacingDirection) -> Alignment {
        switch facing {
        case .up:
            return .top
        case .down:
            return .bottom
        case .left:
            return .leading
        case .right:
            return .trailing
        }
    }

    private func directionOffset(for facing: FacingDirection, tileSize: CGFloat) -> CGSize {
        let amount = tileSize * 0.1
        switch facing {
        case .up:
            return CGSize(width: 0, height: amount)
        case .down:
            return CGSize(width: 0, height: -amount)
        case .left:
            return CGSize(width: amount, height: 0)
        case .right:
            return CGSize(width: -amount, height: 0)
        }
    }
}

private struct RenderedFieldImage: @unchecked Sendable {
    let image: CGImage
}

private struct FieldPixelMatrixOverlay: View {
    let pixelScale: CGFloat
    let style: FieldRenderStyle

    var body: some View {
        GeometryReader { proxy in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
                let spacing = CGFloat(max(2, Int(pixelScale.rounded())))
                let dotSize = max(1.2, spacing * dotScale)
                let bevelOffset = max(0.35, gridLineWidth * 0.8)
                let cellAccentSize = max(0.6, dotSize * 0.54)
                let cellAccentOffset = max(0.28, spacing * 0.12)

                var columns = Path()
                var rows = Path()
                var highlightGrid = Path()
                var shadowGrid = Path()
                var cellHighlightPath = Path()
                var cellShadowPath = Path()
                var dotPath = Path()

                var gridX: CGFloat = 0
                while gridX <= size.width {
                    columns.move(to: CGPoint(x: gridX, y: 0))
                    columns.addLine(to: CGPoint(x: gridX, y: size.height))
                    gridX += spacing
                }

                var gridY: CGFloat = 0
                while gridY <= size.height {
                    rows.move(to: CGPoint(x: 0, y: gridY))
                    rows.addLine(to: CGPoint(x: size.width, y: gridY))
                    gridY += spacing
                }

                highlightGrid.addPath(translated(columns, dx: -bevelOffset, dy: 0))
                highlightGrid.addPath(translated(rows, dx: 0, dy: -bevelOffset))
                shadowGrid.addPath(translated(columns, dx: bevelOffset, dy: 0))
                shadowGrid.addPath(translated(rows, dx: 0, dy: bevelOffset))

                context.stroke(columns, with: .color(gridLineColor), lineWidth: gridLineWidth)
                context.stroke(rows, with: .color(gridLineColor), lineWidth: gridLineWidth)
                context.stroke(highlightGrid, with: .color(gridHighlightColor), lineWidth: gridLineWidth)
                context.stroke(shadowGrid, with: .color(gridShadowColor), lineWidth: gridLineWidth)

                var y: CGFloat = spacing / 2
                while y < size.height {
                    var x: CGFloat = spacing / 2
                    while x < size.width {
                        let highlightRect = CGRect(
                            x: x - (cellAccentSize / 2) - cellAccentOffset,
                            y: y - (cellAccentSize / 2) - cellAccentOffset,
                            width: cellAccentSize,
                            height: cellAccentSize * 0.78
                        )
                        let shadowRect = CGRect(
                            x: x - (cellAccentSize / 2) + cellAccentOffset,
                            y: y - (cellAccentSize / 2) + cellAccentOffset,
                            width: cellAccentSize,
                            height: cellAccentSize * 0.78
                        )
                        let rect = CGRect(
                            x: x - (dotSize / 2),
                            y: y - (dotSize / 2),
                            width: dotSize,
                            height: dotSize
                        )
                        cellHighlightPath.addEllipse(in: highlightRect)
                        cellShadowPath.addEllipse(in: shadowRect)
                        dotPath.addEllipse(in: rect)
                        x += spacing
                    }
                    y += spacing
                }

                context.fill(cellHighlightPath, with: .color(cellHighlightColor))
                context.fill(cellShadowPath, with: .color(cellShadowColor))
                context.fill(dotPath, with: .color(matrixDotColor))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }

    private func translated(_ path: Path, dx: CGFloat, dy: CGFloat) -> Path {
        path.applying(CGAffineTransform(translationX: dx, y: dy))
    }

    private var matrixDotColor: Color {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return Color(red: 0.08, green: 0.18, blue: 0.06).opacity(0.14)
        case .dmgTinted:
            return Color(red: 0.11, green: 0.22, blue: 0.08).opacity(0.12)
        }
    }

    private var gridHighlightColor: Color {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return Color(red: 0.78, green: 0.88, blue: 0.68).opacity(0.045)
        case .dmgTinted:
            return Color(red: 0.83, green: 0.91, blue: 0.74).opacity(0.055)
        }
    }

    private var gridShadowColor: Color {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return Color(red: 0.05, green: 0.12, blue: 0.04).opacity(0.085)
        case .dmgTinted:
            return Color(red: 0.07, green: 0.14, blue: 0.05).opacity(0.09)
        }
    }

    private var gridLineColor: Color {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return Color(red: 0.09, green: 0.17, blue: 0.06).opacity(0.08)
        case .dmgTinted:
            return Color(red: 0.12, green: 0.21, blue: 0.09).opacity(0.075)
        }
    }

    private var cellHighlightColor: Color {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return Color(red: 0.88, green: 0.95, blue: 0.74).opacity(0.03)
        case .dmgTinted:
            return Color(red: 0.9, green: 0.97, blue: 0.8).opacity(0.038)
        }
    }

    private var cellShadowColor: Color {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return Color(red: 0.04, green: 0.1, blue: 0.03).opacity(0.055)
        case .dmgTinted:
            return Color(red: 0.05, green: 0.11, blue: 0.04).opacity(0.065)
        }
    }

    private var dotScale: CGFloat {
        switch style {
        case .rawGrayscale:
            return 0
        case .dmgAuthentic:
            return 0.26
        case .dmgTinted:
            return 0.24
        }
    }

    private var gridLineWidth: CGFloat {
        max(0.5, pixelScale * 0.04)
    }
}
