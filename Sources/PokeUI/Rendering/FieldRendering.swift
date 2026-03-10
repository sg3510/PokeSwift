import Foundation
import SwiftUI
import CoreGraphics
import ImageIO
import PokeCore
import PokeDataModel

public enum FieldRenderStyle: Equatable, Hashable, Sendable {
    case rawGrayscale
    case dmgAuthentic
    case dmgTinted

    public static let defaultGameplayStyle: FieldRenderStyle = .dmgTinted

    public var sidebarSummaryLabel: String {
        switch self {
        case .rawGrayscale:
            return "RAW"
        case .dmgAuthentic:
            return "DMG"
        case .dmgTinted:
            return "TINTED"
        }
    }

    public var sidebarOptionTitle: String {
        switch self {
        case .rawGrayscale:
            return "Raw Gray"
        case .dmgAuthentic:
            return "Authentic DMG"
        case .dmgTinted:
            return "Tinted"
        }
    }
}

public struct FieldSpriteFrame: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let flippedHorizontally: Bool

    public init(x: Int, y: Int, width: Int, height: Int, flippedHorizontally: Bool = false) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.flippedHorizontally = flippedHorizontally
    }
}

public struct FieldSpriteDefinition: Equatable, Sendable {
    public let id: String
    public let imageURL: URL
    public let frameWidth: Int
    public let frameHeight: Int
    public let facingFrames: [FacingDirection: FieldSpriteFrame]

    public init(
        id: String,
        imageURL: URL,
        frameWidth: Int = 16,
        frameHeight: Int = 16,
        facingFrames: [FacingDirection: FieldSpriteFrame]
    ) {
        self.id = id
        self.imageURL = imageURL
        self.frameWidth = frameWidth
        self.frameHeight = frameHeight
        self.facingFrames = facingFrames
    }

    public func frame(for facing: FacingDirection) -> FieldSpriteFrame? {
        facingFrames[facing]
    }
}

public struct FieldTilesetDefinition: Equatable, Sendable {
    public let id: String
    public let imageURL: URL
    public let blocksetURL: URL
    public let sourceTileSize: Int
    public let blockTileWidth: Int
    public let blockTileHeight: Int

    public init(
        id: String,
        imageURL: URL,
        blocksetURL: URL,
        sourceTileSize: Int = 8,
        blockTileWidth: Int = 4,
        blockTileHeight: Int = 4
    ) {
        self.id = id
        self.imageURL = imageURL
        self.blocksetURL = blocksetURL
        self.sourceTileSize = sourceTileSize
        self.blockTileWidth = blockTileWidth
        self.blockTileHeight = blockTileHeight
    }
}

public struct FieldRenderAssets: Equatable, Sendable {
    public let tileset: FieldTilesetDefinition
    public let overworldSprites: [String: FieldSpriteDefinition]

    public init(tileset: FieldTilesetDefinition, overworldSprites: [String: FieldSpriteDefinition]) {
        self.tileset = tileset
        self.overworldSprites = overworldSprites
    }

    public func spriteDefinition(for spriteID: String) -> FieldSpriteDefinition? {
        overworldSprites[spriteID]
    }
}

enum FieldRendererError: Error, Equatable {
    case invalidTilesetImage(URL)
    case invalidSpriteImage(URL)
    case invalidBlocksetLength(Int)
    case invalidBlockIndex(Int)
    case invalidTileIndex(Int)
    case cropFailed
    case maskCreationFailed
    case bitmapContextCreationFailed
}

struct FieldBlockset: Equatable {
    let blocks: [[UInt8]]
    let blockTileWidth: Int
    let blockTileHeight: Int

    static func decode(
        data: Data,
        blockTileWidth: Int = 4,
        blockTileHeight: Int = 4
    ) throws -> FieldBlockset {
        let tilesPerBlock = blockTileWidth * blockTileHeight
        guard data.count.isMultiple(of: tilesPerBlock) else {
            throw FieldRendererError.invalidBlocksetLength(data.count)
        }

        let bytes = [UInt8](data)
        let blocks = stride(from: 0, to: bytes.count, by: tilesPerBlock).map { start in
            Array(bytes[start..<(start + tilesPerBlock)])
        }

        return FieldBlockset(blocks: blocks, blockTileWidth: blockTileWidth, blockTileHeight: blockTileHeight)
    }
}

struct FieldRenderSignature: Hashable, Sendable {
    struct ObjectSignature: Hashable, Sendable {
        let spriteID: String
        let position: TilePoint
        let facingRawValue: String

        init(object: FieldObjectRenderState) {
            spriteID = object.sprite
            position = object.position
            facingRawValue = object.facing.rawValue
        }
    }

    struct AssetSignature: Hashable, Sendable {
        struct SpriteSignature: Hashable, Sendable {
            struct FrameSignature: Hashable, Sendable {
                let directionRawValue: String
                let x: Int
                let y: Int
                let width: Int
                let height: Int
                let flippedHorizontally: Bool

                init(direction: FacingDirection, frame: FieldSpriteFrame) {
                    directionRawValue = direction.rawValue
                    x = frame.x
                    y = frame.y
                    width = frame.width
                    height = frame.height
                    flippedHorizontally = frame.flippedHorizontally
                }
            }

            let id: String
            let imagePath: String
            let frameWidth: Int
            let frameHeight: Int
            let frames: [FrameSignature]

            init(definition: FieldSpriteDefinition) {
                id = definition.id
                imagePath = definition.imageURL.standardizedFileURL.path
                frameWidth = definition.frameWidth
                frameHeight = definition.frameHeight
                frames = FacingDirection.allCases.compactMap { direction in
                    guard let frame = definition.frame(for: direction) else { return nil }
                    return FrameSignature(direction: direction, frame: frame)
                }
            }
        }

        let tilesetID: String
        let tilesetImagePath: String
        let blocksetPath: String
        let sourceTileSize: Int
        let blockTileWidth: Int
        let blockTileHeight: Int
        let spriteAssets: [SpriteSignature]

        init(assets: FieldRenderAssets) {
            tilesetID = assets.tileset.id
            tilesetImagePath = assets.tileset.imageURL.standardizedFileURL.path
            blocksetPath = assets.tileset.blocksetURL.standardizedFileURL.path
            sourceTileSize = assets.tileset.sourceTileSize
            blockTileWidth = assets.tileset.blockTileWidth
            blockTileHeight = assets.tileset.blockTileHeight
            spriteAssets = assets.overworldSprites.values
                .sorted { $0.id < $1.id }
                .map(SpriteSignature.init(definition:))
        }
    }

    let mapID: String
    let tilesetID: String
    let blockWidth: Int
    let blockHeight: Int
    let blockIDs: [Int]
    let playerPosition: TilePoint
    let playerFacingRawValue: String
    let playerSpriteID: String
    let objectStates: [ObjectSignature]
    let assetSignature: AssetSignature
    let style: FieldRenderStyle

    init(
        map: MapManifest,
        playerPosition: TilePoint,
        playerFacing: FacingDirection,
        playerSpriteID: String,
        objects: [FieldObjectRenderState],
        assets: FieldRenderAssets,
        style: FieldRenderStyle
    ) {
        mapID = map.id
        tilesetID = map.tileset
        blockWidth = map.blockWidth
        blockHeight = map.blockHeight
        blockIDs = map.blockIDs
        self.playerPosition = playerPosition
        playerFacingRawValue = playerFacing.rawValue
        self.playerSpriteID = playerSpriteID
        objectStates = objects.map(ObjectSignature.init(object:))
        assetSignature = AssetSignature(assets: assets)
        self.style = style
    }
}

private struct PreparedTileAtlas {
    let tiles: [CGImage]

    init(image: CGImage, tileSize: Int) throws {
        let atlas = FieldSceneRenderer.TileAtlas(image: image, tileSize: tileSize)
        tiles = try (0..<(atlas.columns * atlas.rows)).map { index in
            try atlas.tile(at: index)
        }
    }

    func tile(at index: Int) throws -> CGImage {
        guard tiles.indices.contains(index) else {
            throw FieldRendererError.invalidTileIndex(index)
        }
        return tiles[index]
    }
}

private final class FieldRendererCaches: @unchecked Sendable {
    private struct BlocksetCacheKey: Hashable {
        let path: String
        let blockTileWidth: Int
        let blockTileHeight: Int
    }

    private struct AtlasCacheKey: Hashable {
        let imagePath: String
        let tileSize: Int
    }

    private struct SpriteFrameCacheKey: Hashable {
        let imagePath: String
        let x: Int
        let y: Int
        let width: Int
        let height: Int
    }

    static let shared = FieldRendererCaches()

    private let lock = NSLock()
    private let maxRenderedImages = 24
    private var decodedImages: [String: CGImage] = [:]
    private var blocksets: [BlocksetCacheKey: FieldBlockset] = [:]
    private var preparedAtlases: [AtlasCacheKey: PreparedTileAtlas] = [:]
    private var preparedSprites: [SpriteFrameCacheKey: CGImage] = [:]
    private var renderedImages: [FieldRenderSignature: CGImage] = [:]
    private var renderedImageOrder: [FieldRenderSignature] = []

    private init() {}

    func renderedImage(for signature: FieldRenderSignature) -> CGImage? {
        withLock {
            renderedImages[signature]
        }
    }

    func storeRenderedImage(_ image: CGImage, for signature: FieldRenderSignature) {
        withLock {
            renderedImages[signature] = image
            renderedImageOrder.removeAll { $0 == signature }
            renderedImageOrder.append(signature)

            while renderedImageOrder.count > maxRenderedImages {
                let evictedSignature = renderedImageOrder.removeFirst()
                renderedImages.removeValue(forKey: evictedSignature)
            }
        }
    }

    func image(at url: URL, invalidError: FieldRendererError) throws -> CGImage {
        let imagePath = url.standardizedFileURL.path
        if let cached = withLock({ decodedImages[imagePath] }) {
            return cached
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw invalidError
        }

        withLock {
            decodedImages[imagePath] = image
        }
        return image
    }

    func blockset(for tileset: FieldTilesetDefinition) throws -> FieldBlockset {
        let key = BlocksetCacheKey(
            path: tileset.blocksetURL.standardizedFileURL.path,
            blockTileWidth: tileset.blockTileWidth,
            blockTileHeight: tileset.blockTileHeight
        )
        if let cached = withLock({ blocksets[key] }) {
            return cached
        }

        let blocksetData = try Data(contentsOf: tileset.blocksetURL)
        let blockset = try FieldBlockset.decode(
            data: blocksetData,
            blockTileWidth: tileset.blockTileWidth,
            blockTileHeight: tileset.blockTileHeight
        )
        withLock {
            blocksets[key] = blockset
        }
        return blockset
    }

    func preparedAtlas(for tileset: FieldTilesetDefinition) throws -> PreparedTileAtlas {
        let key = AtlasCacheKey(
            imagePath: tileset.imageURL.standardizedFileURL.path,
            tileSize: tileset.sourceTileSize
        )
        if let cached = withLock({ preparedAtlases[key] }) {
            return cached
        }

        let image = try self.image(at: tileset.imageURL, invalidError: .invalidTilesetImage(tileset.imageURL))
        let atlas = try PreparedTileAtlas(image: image, tileSize: tileset.sourceTileSize)
        withLock {
            preparedAtlases[key] = atlas
        }
        return atlas
    }

    func preparedSpriteImage(
        definition: FieldSpriteDefinition,
        facing: FacingDirection
    ) throws -> CGImage? {
        guard let frame = definition.frame(for: facing) else {
            return nil
        }

        let key = SpriteFrameCacheKey(
            imagePath: definition.imageURL.standardizedFileURL.path,
            x: frame.x,
            y: frame.y,
            width: frame.width,
            height: frame.height
        )
        if let cached = withLock({ preparedSprites[key] }) {
            return cached
        }

        let sourceImage = try image(at: definition.imageURL, invalidError: .invalidSpriteImage(definition.imageURL))
        let preparedImage = try FieldSceneRenderer.prepareSpriteImageForFieldContext(
            FieldSceneRenderer.crop(sourceImage, topLeftFrame: frame)
        )
        withLock {
            preparedSprites[key] = preparedImage
        }
        return preparedImage
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

struct FieldSceneRenderer {
    static let tilePixelSize = 8
    static let blockTileWidth = 4
    static let blockTileHeight = 4
    static let stepPixelSize = 16
    static let blockPixelSize = tilePixelSize * blockTileWidth

    static func render(
        map: MapManifest,
        playerPosition: TilePoint,
        playerFacing: FacingDirection,
        playerSpriteID: String,
        objects: [FieldObjectRenderState],
        assets: FieldRenderAssets,
        style: FieldRenderStyle = .rawGrayscale
    ) throws -> CGImage {
        let renderSignature = FieldRenderSignature(
            map: map,
            playerPosition: playerPosition,
            playerFacing: playerFacing,
            playerSpriteID: playerSpriteID,
            objects: objects,
            assets: assets,
            style: style
        )
        if let cachedImage = FieldRendererCaches.shared.renderedImage(for: renderSignature) {
            return cachedImage
        }

        let atlas = try FieldRendererCaches.shared.preparedAtlas(for: assets.tileset)
        let blockset = try FieldRendererCaches.shared.blockset(for: assets.tileset)

        let width = max(1, map.blockWidth) * blockPixelSize
        let height = max(1, map.blockHeight) * blockPixelSize
        guard let context = bitmapContext(width: width, height: height) else {
            throw FieldRendererError.bitmapContextCreationFailed
        }

        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        try drawBackground(map: map, atlas: atlas, blockset: blockset, into: context)
        try drawActors(
            objects: objects,
            playerPosition: playerPosition,
            playerFacing: playerFacing,
            playerSpriteID: playerSpriteID,
            assets: assets,
            into: context
        )

        guard let image = context.makeImage() else {
            throw FieldRendererError.bitmapContextCreationFailed
        }
        let styledImage = try applyRenderStyle(style, to: image)
        FieldRendererCaches.shared.storeRenderedImage(styledImage, for: renderSignature)
        return styledImage
    }

    fileprivate static func applyRenderStyle(_ style: FieldRenderStyle, to image: CGImage) throws -> CGImage {
        switch style {
        case .rawGrayscale:
            return image
        case .dmgAuthentic:
            let grayscaleValues = try grayscalePixels(for: image)
            let rgbBytes = grayscaleValues.flatMap { value in
                let color = dmgAuthenticColor(for: value)
                return [color.red, color.green, color.blue, 255]
            }
            return try makeRGBImage(
                width: image.width,
                height: image.height,
                bytesPerRow: image.width * 4,
                rgbaBytes: rgbBytes
            )
        case .dmgTinted:
            let grayscaleValues = try grayscalePixels(for: image)
            let rgbBytes = grayscaleValues.flatMap { value in
                let color = dmgTintedColor(for: value)
                return [color.red, color.green, color.blue, 255]
            }
            return try makeRGBImage(
                width: image.width,
                height: image.height,
                bytesPerRow: image.width * 4,
                rgbaBytes: rgbBytes
            )
        }
    }

    fileprivate static func loadImage(from url: URL, invalidError: FieldRendererError) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw invalidError
        }
        return image
    }

    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
    }

    private static func drawBackground(
        map: MapManifest,
        atlas: PreparedTileAtlas,
        blockset: FieldBlockset,
        into context: CGContext
    ) throws {
        for blockY in 0..<map.blockHeight {
            for blockX in 0..<map.blockWidth {
                let mapIndex = (blockY * map.blockWidth) + blockX
                guard map.blockIDs.indices.contains(mapIndex) else { continue }
                let blockID = map.blockIDs[mapIndex]
                guard blockset.blocks.indices.contains(blockID) else {
                    throw FieldRendererError.invalidBlockIndex(blockID)
                }

                let block = blockset.blocks[blockID]
                for tileRow in 0..<blockset.blockTileHeight {
                    for tileColumn in 0..<blockset.blockTileWidth {
                        let tileIndex = Int(block[(tileRow * blockset.blockTileWidth) + tileColumn])
                        let tileImage = try atlas.tile(at: tileIndex)
                        let x = (blockX * blockPixelSize) + (tileColumn * tilePixelSize)
                        let y = (blockY * blockPixelSize) + (tileRow * tilePixelSize)
                        context.draw(tileImage, in: CGRect(x: x, y: y, width: tilePixelSize, height: tilePixelSize))
                    }
                }
            }
        }
    }

    private static func drawActors(
        objects: [FieldObjectRenderState],
        playerPosition: TilePoint,
        playerFacing: FacingDirection,
        playerSpriteID: String,
        assets: FieldRenderAssets,
        into context: CGContext
    ) throws {
        for object in objects {
            try drawSprite(
                spriteID: object.sprite,
                facing: object.facing,
                position: object.position,
                assets: assets,
                into: context
            )
        }

        try drawSprite(
            spriteID: playerSpriteID,
            facing: playerFacing,
            position: playerPosition,
            assets: assets,
            into: context
        )
    }

    private static func drawSprite(
        spriteID: String,
        facing: FacingDirection,
        position: TilePoint,
        assets: FieldRenderAssets,
        into context: CGContext
    ) throws {
        guard let definition = assets.spriteDefinition(for: spriteID),
              let frame = definition.frame(for: facing),
              let spriteImage = try FieldRendererCaches.shared.preparedSpriteImage(definition: definition, facing: facing) else {
            return
        }

        let x = position.x * stepPixelSize
        let y = position.y * stepPixelSize
        context.saveGState()
        if frame.flippedHorizontally {
            context.translateBy(x: CGFloat(x + frame.width), y: 0)
            context.scaleBy(x: -1, y: 1)
            context.draw(spriteImage, in: CGRect(x: 0, y: y, width: frame.width, height: frame.height))
        } else {
            context.draw(spriteImage, in: CGRect(x: x, y: y, width: frame.width, height: frame.height))
        }
        context.restoreGState()
    }

    fileprivate static func crop(_ image: CGImage, topLeftFrame frame: FieldSpriteFrame) throws -> CGImage {
        let cropRect = CGRect(
            x: frame.x,
            y: frame.y,
            width: frame.width,
            height: frame.height
        )
        guard let cropped = image.cropping(to: cropRect.integral) else {
            throw FieldRendererError.cropFailed
        }
        return cropped
    }

    fileprivate static func prepareImageForFieldContext(_ image: CGImage) throws -> CGImage {
        guard let context = bitmapContext(width: image.width, height: image.height) else {
            throw FieldRendererError.bitmapContextCreationFailed
        }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let flipped = context.makeImage() else {
            throw FieldRendererError.bitmapContextCreationFailed
        }
        return flipped
    }

    fileprivate static func prepareSpriteImageForFieldContext(_ image: CGImage) throws -> CGImage {
        let maskedImage = try applySpriteTransparencyMask(to: image)
        guard let context = spriteBitmapContext(width: image.width, height: image.height) else {
            throw FieldRendererError.bitmapContextCreationFailed
        }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(maskedImage, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let preparedImage = context.makeImage() else {
            throw FieldRendererError.bitmapContextCreationFailed
        }
        return preparedImage
    }

    private static func applySpriteTransparencyMask(to image: CGImage) throws -> CGImage {
        let pixelValues = try grayscalePixels(for: image)
        let maskBytes = pixelValues.map { $0 == 255 ? UInt8(255) : UInt8(0) }
        let maskData = Data(maskBytes) as CFData
        guard let provider = CGDataProvider(data: maskData),
              let mask = CGImage(
                maskWidth: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: image.width,
                provider: provider,
                decode: nil,
                shouldInterpolate: false
              ),
              let maskedImage = image.masking(mask) else {
            throw FieldRendererError.maskCreationFailed
        }
        return maskedImage
    }

    private static func grayscalePixels(for image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        let bytesPerRow = width
        var bytes = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw FieldRendererError.bitmapContextCreationFailed
        }
        context.interpolationQuality = .none
        context.setShouldAntialias(false)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    private static func makeRGBImage(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        rgbaBytes: [UInt8]
    ) throws -> CGImage {
        let data = Data(rgbaBytes) as CFData
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.union(
                    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            throw FieldRendererError.bitmapContextCreationFailed
        }
        return image
    }

    private static func dmgAuthenticColor(for value: UInt8) -> DMGPaletteColor {
        switch value {
        case 0...63:
            return .darkest
        case 64...127:
            return .dark
        case 128...191:
            return .light
        default:
            return .lightest
        }
    }

    private static func dmgTintedColor(for value: UInt8) -> DMGPaletteColor {
        let t = Double(value) / 255
        return DMGPaletteColor.interpolate(from: .darkest, to: .lightest, fraction: t)
    }

    private static func spriteBitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    struct DMGPaletteColor: Equatable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8

        static let darkest = DMGPaletteColor(red: 15, green: 56, blue: 15)
        static let dark = DMGPaletteColor(red: 48, green: 98, blue: 48)
        static let light = DMGPaletteColor(red: 139, green: 172, blue: 15)
        static let lightest = DMGPaletteColor(red: 155, green: 188, blue: 15)

        static func interpolate(
            from start: DMGPaletteColor,
            to end: DMGPaletteColor,
            fraction: Double
        ) -> DMGPaletteColor {
            let clampedFraction = max(0, min(1, fraction))
            return DMGPaletteColor(
                red: interpolateChannel(start.red, end.red, fraction: clampedFraction),
                green: interpolateChannel(start.green, end.green, fraction: clampedFraction),
                blue: interpolateChannel(start.blue, end.blue, fraction: clampedFraction)
            )
        }

        private static func interpolateChannel(_ start: UInt8, _ end: UInt8, fraction: Double) -> UInt8 {
            UInt8((Double(start) + ((Double(end) - Double(start)) * fraction)).rounded())
        }
    }

    struct TileAtlas {
        let image: CGImage
        let tileSize: Int
        let columns: Int
        let rows: Int

        init(image: CGImage, tileSize: Int) {
            self.image = image
            self.tileSize = tileSize
            self.columns = max(1, image.width / tileSize)
            self.rows = max(1, image.height / tileSize)
        }

        func tile(at index: Int) throws -> CGImage {
            let totalTiles = columns * rows
            guard (0..<totalTiles).contains(index) else {
                throw FieldRendererError.invalidTileIndex(index)
            }

            let x = (index % columns) * tileSize
            let y = (index / columns) * tileSize
            let cropRect = CGRect(
                x: x,
                y: y,
                width: tileSize,
                height: tileSize
            )
            guard let tile = image.cropping(to: cropRect.integral) else {
                throw FieldRendererError.cropFailed
            }
            return try FieldSceneRenderer.prepareImageForFieldContext(tile)
        }
    }
}
