import SpriteKit

/// Loads the original TexturePacker atlas (`game.plist` format 2 + `game.png`)
/// and serves sub-textures by the same frame names the Cocos code used
/// (e.g. "turtle-1.png", "board/play-1.png", "number/7.png").
final class TextureAtlas {
    struct Frame: Equatable {
        /// Pixel rect inside the sheet, top-left origin (as stored in the plist).
        let rect: CGRect
        let rotated: Bool
    }

    static let shared = try! TextureAtlas(plistName: "game.plist")

    let frames: [String: Frame]
    private let sheet: SKTexture
    private let sheetSize: CGSize
    private var cache: [String: SKTexture] = [:]

    init(plistName: String, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: plistName, withExtension: nil) else {
            throw AtlasError.missingFile(plistName)
        }
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        guard let root = plist as? [String: Any],
              let rawFrames = root["frames"] as? [String: [String: Any]],
              let metadata = root["metadata"] as? [String: Any],
              let textureName = metadata["textureFileName"] as? String,
              let sizeString = metadata["size"] as? String else {
            throw AtlasError.malformed(plistName)
        }
        var parsed: [String: Frame] = [:]
        for (name, info) in rawFrames {
            guard let frameString = info["frame"] as? String else { throw AtlasError.malformed(name) }
            parsed[name] = Frame(rect: NSCoder.cgRect(for: frameString),
                                 rotated: info["rotated"] as? Bool ?? false)
        }
        frames = parsed
        sheetSize = NSCoder.cgSize(for: sizeString)
        guard let image = UIImage(named: textureName, in: bundle, compatibleWith: nil) else {
            throw AtlasError.missingFile(textureName)
        }
        sheet = SKTexture(image: image)
    }

    func texture(_ name: String) -> SKTexture {
        if let cached = cache[name] { return cached }
        guard let frame = frames[name] else { fatalError("Unknown atlas frame \(name)") }
        precondition(!frame.rotated, "Rotated atlas frames are not used by this game")
        // SKTexture rects are normalised with a bottom-left origin.
        let unit = CGRect(x: frame.rect.minX / sheetSize.width,
                          y: 1 - frame.rect.maxY / sheetSize.height,
                          width: frame.rect.width / sheetSize.width,
                          height: frame.rect.height / sheetSize.height)
        let texture = SKTexture(rect: unit, in: sheet)
        cache[name] = texture
        return texture
    }

    enum AtlasError: Error {
        case missingFile(String)
        case malformed(String)
    }
}

/// Stand-alone images outside the atlas (`initWithFile` in the original).
enum StandaloneTexture {
    static let background = load("bg.jpg")
    static let obstacle = load("obstacle.png")

    private static func load(_ name: String) -> SKTexture {
        guard let image = UIImage(named: name) else { fatalError("Missing image \(name)") }
        return SKTexture(image: image)
    }
}
