import Foundation
import ImageIO
import PokeContent
import PokeDataModel
import SwiftUI

public struct GameBoyPixelText: View {
    private let text: String
    private let scale: CGFloat
    private let color: Color
    private let spacing: CGFloat
    private let spaceWidth: CGFloat
    private let fallbackFont: Font

    public init(
        _ text: String,
        scale: CGFloat = 2,
        color: Color = .primary,
        spacing: CGFloat = 0,
        spaceWidth: CGFloat = 6,
        fallbackFont: Font = .system(size: 12, weight: .bold, design: .monospaced)
    ) {
        self.text = text
        self.scale = scale
        self.color = color
        self.spacing = spacing
        self.spaceWidth = spaceWidth
        self.fallbackFont = fallbackFont
    }

    public var body: some View {
        if let atlas = GameBoyPixelFontAtlasStore.defaultAtlas,
           atlas.supports(text) {
            HStack(spacing: spacing) {
                ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                    if character == " " {
                        Color.clear
                            .frame(width: spaceWidth * scale, height: atlas.tileSize * scale)
                    } else if let glyph = atlas.glyph(for: character) {
                        GameBoyPixelGlyph(
                            image: glyph,
                            scale: scale,
                            color: color,
                            tileSize: atlas.tileSize
                        )
                    }
                }
            }
            .frame(height: atlas.tileSize * scale)
            .fixedSize()
            .accessibilityLabel(text)
        } else {
            Text(text)
                .font(fallbackFont)
                .foregroundStyle(color)
        }
    }
}

private struct GameBoyPixelGlyph: View {
    let image: CGImage
    let scale: CGFloat
    let color: Color
    let tileSize: CGFloat

    var body: some View {
        color
            .mask {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .colorInvert()
                    .luminanceToAlpha()
                    .frame(width: tileSize * scale, height: tileSize * scale)
            }
            .frame(width: tileSize * scale, height: tileSize * scale)
    }
}

private enum GameBoyPixelFontAtlasStore {
    static let defaultAtlas = GameBoyPixelFontAtlas.loadDefault()
}

private struct GameBoyPixelFontAtlas {
    let tileSize: CGFloat
    private let glyphsByCharacter: [Character: CGImage]

    func glyph(for character: Character) -> CGImage? {
        glyphsByCharacter[character]
    }

    func supports(_ text: String) -> Bool {
        text.allSatisfy { $0 == " " || glyphsByCharacter[$0] != nil }
    }

    static func loadDefault() -> GameBoyPixelFontAtlas? {
        guard let rootURL = resolvedContentRoot(),
              let atlasImage = loadImage(at: rootURL.appendingPathComponent("Assets/font/font.png")),
              let charmap = loadCharmap(at: rootURL.appendingPathComponent("charmap.json")) else {
            return nil
        }

        let glyphPairs: [(Character, CGImage)] = charmap.entries.compactMap { entry in
                guard entry.sourceSection.contains("gfx/font/font.png"),
                      entry.value >= 128,
                      entry.value < 256,
                      entry.token.count == 1,
                      let character = entry.token.first else {
                    return nil
                }

                let tileIndex = entry.value - 128
                guard let glyph = glyph(from: atlasImage, tileIndex: tileIndex) else {
                    return nil
                }

                return (character, glyph)
        }
        let glyphs = Dictionary(uniqueKeysWithValues: glyphPairs)

        return GameBoyPixelFontAtlas(tileSize: 8, glyphsByCharacter: glyphs)
    }

    private static func resolvedContentRoot() -> URL? {
        let rootURL = ContentLocator.defaultContentRoot(bundle: .main)
        let directRoot = rootURL
        let nestedRoot = rootURL.appendingPathComponent("Red", isDirectory: true)

        let candidates = [directRoot, nestedRoot]
        return candidates.first { candidate in
            let atlasPath = candidate.appendingPathComponent("Assets/font/font.png").path
            let charmapPath = candidate.appendingPathComponent("charmap.json").path
            return FileManager.default.fileExists(atPath: atlasPath) &&
                FileManager.default.fileExists(atPath: charmapPath)
        }
    }

    private static func loadCharmap(at url: URL) -> CharmapManifest? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(CharmapManifest.self, from: data)
    }

    private static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func glyph(from atlasImage: CGImage, tileIndex: Int) -> CGImage? {
        let tileSize = 8
        let columns = max(1, atlasImage.width / tileSize)
        let tileX = (tileIndex % columns) * tileSize
        let tileY = (tileIndex / columns) * tileSize
        let cropRect = CGRect(x: tileX, y: tileY, width: tileSize, height: tileSize).integral

        return atlasImage.cropping(to: cropRect)
    }
}
