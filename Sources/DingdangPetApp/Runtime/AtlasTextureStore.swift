import AppKit
import DingdangPetCore
import SpriteKit

@MainActor
final class AtlasTextureStore {
    struct LoadedAtlas {
        let definition: AtlasDefinition
        let texture: SKTexture
        let pixelWidth: Int
        let pixelHeight: Int
    }

    private var atlases: [String: LoadedAtlas] = [:]

    func load(pet: PetDefinition, rootURL: URL) throws {
        atlases.removeAll()
        for definition in pet.atlases {
            let url = rootURL.appendingPathComponent(definition.file)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw NSError(domain: "DingdangPet.Atlas", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decode atlas \(definition.file)"])
            }
            let texture = SKTexture(cgImage: image)
            texture.filteringMode = definition.filtering == .linear ? .linear : .nearest
            atlases[definition.id] = LoadedAtlas(definition: definition, texture: texture, pixelWidth: image.width, pixelHeight: image.height)
        }
    }

    func texture(for frame: ResolvedFrame) throws -> SKTexture {
        guard let atlas = atlases[frame.atlasID] else {
            throw FrameResolutionError.atlasNotFound(frame.atlasID)
        }
        let rect = frame.rect
        let normalized = CGRect(
            x: CGFloat(rect.x) / CGFloat(atlas.pixelWidth),
            y: CGFloat(atlas.pixelHeight - rect.y - rect.height) / CGFloat(atlas.pixelHeight),
            width: CGFloat(rect.width) / CGFloat(atlas.pixelWidth),
            height: CGFloat(rect.height) / CGFloat(atlas.pixelHeight)
        )
        let texture = SKTexture(rect: normalized, in: atlas.texture)
        texture.filteringMode = atlas.definition.filtering == .linear ? .linear : .nearest
        return texture
    }
}
