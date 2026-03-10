import Foundation
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

    @State private var renderedScene: FieldRenderedScene?
    @State private var presentedCameraOrigin: CGPoint = .zero
    @State private var presentedPlayerWorldPosition: CGPoint = .zero
    @State private var presentationIdentity: FieldPresentationIdentity?

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
            let scale = viewportScale(for: proxy.size)
            let viewportWidth = CGFloat(FieldSceneRenderer.viewportPixelSize.width) * scale
            let viewportHeight = CGFloat(FieldSceneRenderer.viewportPixelSize.height) * scale

            ZStack {
                if let renderedScene {
                    FixedViewportRenderedField(
                        scene: renderedScene,
                        renderStyle: renderStyle,
                        displayScale: scale,
                        cameraOrigin: presentedCameraOrigin,
                        playerWorldPosition: presentedPlayerWorldPosition
                    )
                } else {
                    FixedViewportPlaceholderField(
                        map: map,
                        playerPosition: playerPosition,
                        playerFacing: playerFacing,
                        objects: objects,
                        metrics: FieldSceneRenderer.sceneMetrics(for: map),
                        renderStyle: renderStyle,
                        displayScale: scale,
                        cameraOrigin: presentedCameraOrigin,
                        playerWorldPosition: presentedPlayerWorldPosition
                    )
                }
            }
            .frame(width: viewportWidth, height: viewportHeight)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .task(id: presentationSignature) {
            syncPresentedState(metrics: FieldSceneRenderer.sceneMetrics(for: map))
        }
        .task(id: sceneRenderSignature) {
            await updateRenderedScene()
        }
    }

    private var presentationSignature: FieldPresentationIdentity {
        FieldPresentationIdentity(mapID: map.id, playerPosition: playerPosition)
    }

    private var sceneRenderSignature: FieldSceneRenderIdentity? {
        guard let renderAssets else { return nil }
        return FieldSceneRenderIdentity(
            map: map,
            playerFacing: playerFacing,
            playerSpriteID: playerSpriteID,
            objects: objects,
            assets: renderAssets,
            style: renderStyle
        )
    }

    @MainActor
    private func updateRenderedScene() async {
        guard let renderAssets else {
            renderedScene = nil
            return
        }

        let scene = await renderFieldScene(assets: renderAssets)
        guard Task.isCancelled == false else { return }
        renderedScene = scene
    }

    private func renderFieldScene(assets: FieldRenderAssets) async -> FieldRenderedScene? {
        let map = map
        let playerPosition = playerPosition
        let playerFacing = playerFacing
        let playerSpriteID = playerSpriteID
        let objects = objects
        let renderStyle = renderStyle

        let renderResult = await Task.detached(priority: .userInitiated) {
            try? RenderedFieldSceneBox(
                scene: FieldSceneRenderer.renderScene(
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
        return renderResult?.scene
    }

    @MainActor
    private func syncPresentedState(metrics: FieldSceneMetrics) {
        let targetPlayerWorld = FieldSceneRenderer.playerWorldPosition(for: playerPosition, metrics: metrics)
        let targetCamera = FieldCameraState.target(
            playerWorldPosition: targetPlayerWorld,
            contentPixelSize: metrics.contentPixelSize
        )
        let nextIdentity = FieldPresentationIdentity(mapID: map.id, playerPosition: playerPosition)
        let shouldAnimate = shouldAnimateTransition(to: nextIdentity)

        let applyState = {
            presentedPlayerWorldPosition = CGPoint(
                x: CGFloat(targetPlayerWorld.x),
                y: CGFloat(targetPlayerWorld.y)
            )
            presentedCameraOrigin = CGPoint(
                x: CGFloat(targetCamera.origin.x),
                y: CGFloat(targetCamera.origin.y)
            )
            presentationIdentity = nextIdentity
        }

        if shouldAnimate {
            withAnimation(.linear(duration: 0.1)) {
                applyState()
            }
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                applyState()
            }
        }
    }

    private func shouldAnimateTransition(to nextIdentity: FieldPresentationIdentity) -> Bool {
        guard let previousIdentity = presentationIdentity,
              previousIdentity.mapID == nextIdentity.mapID else {
            return false
        }

        let deltaX = abs(previousIdentity.playerPosition.x - nextIdentity.playerPosition.x)
        let deltaY = abs(previousIdentity.playerPosition.y - nextIdentity.playerPosition.y)
        return (deltaX + deltaY) == 1
    }

    private func viewportScale(for size: CGSize) -> CGFloat {
        let rawScale = min(
            size.width / CGFloat(FieldSceneRenderer.viewportPixelSize.width),
            size.height / CGFloat(FieldSceneRenderer.viewportPixelSize.height)
        )
        guard rawScale.isFinite, rawScale > 0 else {
            return 1
        }
        if rawScale >= 1 {
            return max(1, floor(rawScale))
        }
        return rawScale
    }
}

private struct RenderedFieldSceneBox: @unchecked Sendable {
    let scene: FieldRenderedScene
}

private struct FieldSceneRenderIdentity: Equatable {
    let map: MapManifest
    let playerFacing: FacingDirection
    let playerSpriteID: String
    let objects: [FieldObjectRenderState]
    let assets: FieldRenderAssets
    let style: FieldRenderStyle
}

private struct FieldPresentationIdentity: Equatable {
    let mapID: String
    let playerPosition: TilePoint
}

private struct FixedViewportRenderedField: View {
    let scene: FieldRenderedScene
    let renderStyle: FieldRenderStyle
    let displayScale: CGFloat
    let cameraOrigin: CGPoint
    let playerWorldPosition: CGPoint

    var body: some View {
        ZStack(alignment: .topLeading) {
            lcdBackground

            Image(decorative: scene.backgroundImage, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(
                    width: CGFloat(scene.metrics.contentPixelSize.width) * displayScale,
                    height: CGFloat(scene.metrics.contentPixelSize.height) * displayScale
                )
                .offset(
                    x: -cameraOrigin.x * displayScale,
                    y: -cameraOrigin.y * displayScale
                )

            ForEach(sortedActors) { actor in
                let renderedWorldPosition = actor.role == .player
                    ? playerWorldPosition
                    : CGPoint(x: CGFloat(actor.worldPosition.x), y: CGFloat(actor.worldPosition.y))
                Image(decorative: actor.image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(
                        width: CGFloat(actor.size.width) * displayScale,
                        height: CGFloat(actor.size.height) * displayScale
                    )
                    .scaleEffect(x: actor.flippedHorizontally ? -1 : 1, y: -1, anchor: .center)
                    .position(
                        x: ((renderedWorldPosition.x - cameraOrigin.x) + CGFloat(actor.size.width) / 2) * displayScale,
                        y: ((renderedWorldPosition.y - cameraOrigin.y) + CGFloat(actor.size.height) / 2) * displayScale
                    )
                    .zIndex(renderedWorldPosition.y)
            }

            if renderStyle != .rawGrayscale {
                FieldPixelMatrixOverlay(pixelScale: displayScale, style: renderStyle)
            }
        }
        .frame(
            width: CGFloat(FieldSceneRenderer.viewportPixelSize.width) * displayScale,
            height: CGFloat(FieldSceneRenderer.viewportPixelSize.height) * displayScale,
            alignment: .topLeading
        )
        .clipShape(RoundedRectangle(cornerRadius: max(6, displayScale * 2.5), style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: max(6, displayScale * 2.5), style: .continuous)
                .stroke(Color.black.opacity(0.16), lineWidth: max(1, displayScale * 0.16))
        }
    }

    private var sortedActors: [FieldRenderedActor] {
        scene.actors.sorted { lhs, rhs in
            if lhs.worldPosition.y == rhs.worldPosition.y {
                return lhs.id < rhs.id
            }
            return lhs.worldPosition.y < rhs.worldPosition.y
        }
    }

    private var lcdBackground: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.49, green: 0.56, blue: 0.17))

            LinearGradient(
                colors: [
                    Color.white.opacity(0.07),
                    Color.clear,
                    Color.black.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct FixedViewportPlaceholderField: View {
    let map: MapManifest
    let playerPosition: TilePoint
    let playerFacing: FacingDirection
    let objects: [FieldObjectRenderState]
    let metrics: FieldSceneMetrics
    let renderStyle: FieldRenderStyle
    let displayScale: CGFloat
    let cameraOrigin: CGPoint
    let playerWorldPosition: CGPoint

    var body: some View {
        let viewportWidth = CGFloat(FieldSceneRenderer.viewportPixelSize.width) * displayScale
        let viewportHeight = CGFloat(FieldSceneRenderer.viewportPixelSize.height) * displayScale
        let stepSize = CGFloat(FieldSceneRenderer.stepPixelSize) * displayScale
        let contentOrigin = CGPoint(x: -cameraOrigin.x * displayScale, y: -cameraOrigin.y * displayScale)
        let stepCountX = Int(ceil(Double(FieldSceneRenderer.viewportPixelSize.width) / Double(FieldSceneRenderer.stepPixelSize))) + 3
        let stepCountY = Int(ceil(Double(FieldSceneRenderer.viewportPixelSize.height) / Double(FieldSceneRenderer.stepPixelSize))) + 3
        let startStepX = Int(floor(cameraOrigin.x / CGFloat(FieldSceneRenderer.stepPixelSize))) - 1
        let startStepY = Int(floor(cameraOrigin.y / CGFloat(FieldSceneRenderer.stepPixelSize))) - 1

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0.49, green: 0.56, blue: 0.17))

            ForEach(0..<stepCountY, id: \.self) { row in
                ForEach(0..<stepCountX, id: \.self) { column in
                    let paddedStepX = startStepX + column
                    let paddedStepY = startStepY + row
                    Rectangle()
                        .fill(tileColor(forPaddedStepX: paddedStepX, paddedStepY: paddedStepY))
                        .frame(width: stepSize, height: stepSize)
                        .position(
                            x: contentOrigin.x + (CGFloat(paddedStepX * FieldSceneRenderer.stepPixelSize) * displayScale) + (stepSize / 2),
                            y: contentOrigin.y + (CGFloat(paddedStepY * FieldSceneRenderer.stepPixelSize) * displayScale) + (stepSize / 2)
                        )
                }
            }

            ForEach(objects, id: \.id) { object in
                let worldX = CGFloat((object.position.x * FieldSceneRenderer.stepPixelSize) + metrics.paddingPixels.width)
                let worldY = CGFloat((object.position.y * FieldSceneRenderer.stepPixelSize) + metrics.paddingPixels.height)
                Rectangle()
                    .fill(objectColor(for: object.sprite))
                    .frame(width: stepSize * 0.88, height: stepSize * 0.88)
                    .overlay {
                        Text(object.displayName.prefix(1))
                            .font(.system(size: max(8, stepSize * 0.34), weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .position(
                        x: ((worldX - cameraOrigin.x) * displayScale) + (stepSize / 2),
                        y: ((worldY - cameraOrigin.y) * displayScale) + (stepSize / 2)
                    )
            }

            Capsule()
                .fill(Color.black)
                .frame(width: stepSize * 0.8, height: stepSize * 0.9)
                .overlay(alignment: overlayAlignment(for: playerFacing)) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: max(3, stepSize * 0.16), height: max(3, stepSize * 0.16))
                        .offset(directionOffset(for: playerFacing, tileSize: stepSize))
                }
                .position(
                    x: ((playerWorldPosition.x - cameraOrigin.x) * displayScale) + (stepSize / 2),
                    y: ((playerWorldPosition.y - cameraOrigin.y) * displayScale) + (stepSize / 2)
                )

            if renderStyle != .rawGrayscale {
                FieldPixelMatrixOverlay(pixelScale: displayScale, style: renderStyle)
            }
        }
        .frame(width: viewportWidth, height: viewportHeight, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: max(6, displayScale * 2.5), style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: max(6, displayScale * 2.5), style: .continuous)
                .stroke(Color.black.opacity(0.16), lineWidth: max(1, displayScale * 0.16))
        }
    }

    private func tileColor(forPaddedStepX paddedStepX: Int, paddedStepY: Int) -> Color {
        let paddingStepsX = metrics.paddingPixels.width / FieldSceneRenderer.stepPixelSize
        let paddingStepsY = metrics.paddingPixels.height / FieldSceneRenderer.stepPixelSize
        let mapStepX = paddedStepX - paddingStepsX
        let mapStepY = paddedStepY - paddingStepsY

        let blockX = mapStepX / 2
        let blockY = mapStepY / 2
        let blockID: Int
        if (0..<map.blockWidth).contains(blockX), (0..<map.blockHeight).contains(blockY) {
            let index = (blockY * map.blockWidth) + blockX
            blockID = map.blockIDs.indices.contains(index) ? map.blockIDs[index] : map.borderBlockID
        } else {
            blockID = map.borderBlockID
        }

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

private struct FieldPixelMatrixOverlay: View {
    let pixelScale: CGFloat
    let style: FieldRenderStyle
    @State private var textureImage: CGImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let textureImage {
                    Image(decorative: textureImage, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .task(id: textureKey(for: proxy.size)) {
                await updateTexture(for: proxy.size)
            }
        }
        .allowsHitTesting(false)
    }

    @MainActor
    private func updateTexture(for size: CGSize) async {
        guard let key = textureKey(for: size), style != .rawGrayscale else {
            textureImage = nil
            return
        }

        let imageBox = await Task.detached(priority: .utility) {
            let image = FieldPixelMatrixTextureCache.shared.image(for: key) {
                renderTexture(for: key)
            }
            return FieldPixelMatrixTextureBox(image: image)
        }.value
        guard Task.isCancelled == false else { return }
        textureImage = imageBox.image
    }

    private func textureKey(for size: CGSize) -> FieldPixelMatrixTextureKey? {
        let width = Int(size.width.rounded(.toNearestOrAwayFromZero))
        let height = Int(size.height.rounded(.toNearestOrAwayFromZero))
        guard width > 0, height > 0 else { return nil }
        return FieldPixelMatrixTextureKey(
            width: width,
            height: height,
            pixelScale: max(1, Int(pixelScale.rounded())),
            style: style
        )
    }

    private func renderTexture(for key: FieldPixelMatrixTextureKey) -> CGImage? {
        let width = key.width
        let height = key.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let size = CGSize(width: width, height: height)
        let spacing = CGFloat(max(2, key.pixelScale))
        let lineWidth = max(0.5, CGFloat(key.pixelScale) * 0.04)
        let dotSize = max(1.2, spacing * dotScale(for: key.style))
        let bevelOffset = max(0.35, lineWidth * 0.8)
        let cellAccentSize = max(0.6, dotSize * 0.54)
        let cellAccentOffset = max(0.28, spacing * 0.12)

        let columns = CGMutablePath()
        let rows = CGMutablePath()
        let highlightGrid = CGMutablePath()
        let shadowGrid = CGMutablePath()
        let cellHighlightPath = CGMutablePath()
        let cellShadowPath = CGMutablePath()
        let dotPath = CGMutablePath()

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

        var highlightTransform = CGAffineTransform(translationX: -bevelOffset, y: 0)
        if let translatedColumns = columns.copy(using: &highlightTransform) {
            highlightGrid.addPath(translatedColumns)
        }
        highlightTransform = CGAffineTransform(translationX: 0, y: -bevelOffset)
        if let translatedRows = rows.copy(using: &highlightTransform) {
            highlightGrid.addPath(translatedRows)
        }

        var shadowTransform = CGAffineTransform(translationX: bevelOffset, y: 0)
        if let translatedColumns = columns.copy(using: &shadowTransform) {
            shadowGrid.addPath(translatedColumns)
        }
        shadowTransform = CGAffineTransform(translationX: 0, y: bevelOffset)
        if let translatedRows = rows.copy(using: &shadowTransform) {
            shadowGrid.addPath(translatedRows)
        }

        stroke(columns, color: gridLineColor(for: key.style), width: lineWidth, in: context)
        stroke(rows, color: gridLineColor(for: key.style), width: lineWidth, in: context)
        stroke(highlightGrid, color: gridHighlightColor(for: key.style), width: lineWidth, in: context)
        stroke(shadowGrid, color: gridShadowColor(for: key.style), width: lineWidth, in: context)

        var y: CGFloat = spacing / 2
        while y < size.height {
            var x: CGFloat = spacing / 2
            while x < size.width {
                cellHighlightPath.addEllipse(in: CGRect(
                    x: x - (cellAccentSize / 2) - cellAccentOffset,
                    y: y - (cellAccentSize / 2) - cellAccentOffset,
                    width: cellAccentSize,
                    height: cellAccentSize * 0.78
                ))
                cellShadowPath.addEllipse(in: CGRect(
                    x: x - (cellAccentSize / 2) + cellAccentOffset,
                    y: y - (cellAccentSize / 2) + cellAccentOffset,
                    width: cellAccentSize,
                    height: cellAccentSize * 0.78
                ))
                dotPath.addEllipse(in: CGRect(
                    x: x - (dotSize / 2),
                    y: y - (dotSize / 2),
                    width: dotSize,
                    height: dotSize
                ))
                x += spacing
            }
            y += spacing
        }

        fill(cellHighlightPath, color: cellHighlightColor(for: key.style), in: context)
        fill(cellShadowPath, color: cellShadowColor(for: key.style), in: context)
        fill(dotPath, color: matrixDotColor(for: key.style), in: context)

        return context.makeImage()
    }

    private func stroke(_ path: CGPath, color: FieldPixelMatrixColor, width: CGFloat, in context: CGContext) {
        guard color.alpha > 0 else { return }
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.strokePath()
    }

    private func fill(_ path: CGPath, color: FieldPixelMatrixColor, in context: CGContext) {
        guard color.alpha > 0 else { return }
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    private func matrixDotColor(for style: FieldRenderStyle) -> FieldPixelMatrixColor {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return .init(red: 0.08, green: 0.18, blue: 0.06, alpha: 0.14)
        case .dmgTinted:
            return .init(red: 0.11, green: 0.22, blue: 0.08, alpha: 0.12)
        }
    }

    private func gridHighlightColor(for style: FieldRenderStyle) -> FieldPixelMatrixColor {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return .init(red: 0.78, green: 0.88, blue: 0.68, alpha: 0.045)
        case .dmgTinted:
            return .init(red: 0.83, green: 0.91, blue: 0.74, alpha: 0.055)
        }
    }

    private func gridShadowColor(for style: FieldRenderStyle) -> FieldPixelMatrixColor {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return .init(red: 0.05, green: 0.12, blue: 0.04, alpha: 0.085)
        case .dmgTinted:
            return .init(red: 0.07, green: 0.14, blue: 0.05, alpha: 0.09)
        }
    }

    private func gridLineColor(for style: FieldRenderStyle) -> FieldPixelMatrixColor {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return .init(red: 0.09, green: 0.17, blue: 0.06, alpha: 0.08)
        case .dmgTinted:
            return .init(red: 0.12, green: 0.21, blue: 0.09, alpha: 0.075)
        }
    }

    private func cellHighlightColor(for style: FieldRenderStyle) -> FieldPixelMatrixColor {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return .init(red: 0.88, green: 0.95, blue: 0.74, alpha: 0.03)
        case .dmgTinted:
            return .init(red: 0.9, green: 0.97, blue: 0.8, alpha: 0.038)
        }
    }

    private func cellShadowColor(for style: FieldRenderStyle) -> FieldPixelMatrixColor {
        switch style {
        case .rawGrayscale:
            return .clear
        case .dmgAuthentic:
            return .init(red: 0.04, green: 0.1, blue: 0.03, alpha: 0.055)
        case .dmgTinted:
            return .init(red: 0.05, green: 0.11, blue: 0.04, alpha: 0.065)
        }
    }

    private func dotScale(for style: FieldRenderStyle) -> CGFloat {
        switch style {
        case .rawGrayscale:
            return 0
        case .dmgAuthentic:
            return 0.26
        case .dmgTinted:
            return 0.24
        }
    }
}

private struct FieldPixelMatrixTextureKey: Hashable {
    let width: Int
    let height: Int
    let pixelScale: Int
    let style: FieldRenderStyle
}

private struct FieldPixelMatrixTextureBox: @unchecked Sendable {
    let image: CGImage?
}

private struct FieldPixelMatrixColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    static let clear = FieldPixelMatrixColor(red: 0, green: 0, blue: 0, alpha: 0)

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

private final class FieldPixelMatrixTextureCache: @unchecked Sendable {
    static let shared = FieldPixelMatrixTextureCache()

    private let lock = NSLock()
    private var cachedImages: [FieldPixelMatrixTextureKey: CGImage] = [:]

    func image(for key: FieldPixelMatrixTextureKey, builder: () -> CGImage?) -> CGImage? {
        lock.lock()
        if let image = cachedImages[key] {
            lock.unlock()
            return image
        }
        lock.unlock()

        guard let image = builder() else { return nil }

        lock.lock()
        cachedImages[key] = image
        lock.unlock()
        return image
    }
}
