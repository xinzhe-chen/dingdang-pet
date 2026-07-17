import AppKit
import DingdangPetCore
import SpriteKit

@MainActor
final class PetScene: SKScene {
    private let sprite = SKSpriteNode()
    private let textures = AtlasTextureStore()
    private(set) var pet: PetDefinition?
    private(set) var currentAnimationName: String?
    private var rootURL: URL?
    private var animationToken = UUID()
    private var contentInset: CGFloat = 2

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        addChild(sprite)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func load(pet: PetDefinition, rootURL: URL) throws {
        self.pet = pet
        self.rootURL = rootURL
        try textures.load(pet: pet, rootURL: rootURL)
        layoutSprite()
        playIdle()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutSprite()
    }

    func playIdle() {
        guard let pet, let idle = pet.bindings["defaultIdle"] else { return }
        play(animation: idle, forceSingleCycle: false, completion: nil)
    }

    func playBinding(_ semantic: String, forceSingleCycle: Bool = true, completion: (() -> Void)? = nil) {
        guard let name = pet?.bindings[semantic] else {
            completion?()
            return
        }
        play(animation: name, forceSingleCycle: forceSingleCycle, completion: completion)
    }

    func play(animation name: String, forceSingleCycle: Bool = false, completion: (() -> Void)? = nil) {
        guard let pet, let definition = pet.animations[name] else {
            completion?()
            return
        }
        let token = UUID()
        animationToken = token
        currentAnimationName = name
        sprite.removeAction(forKey: "animation")

        do {
            let ordered = FrameResolver.orderedFrames(for: definition)
            let frameActions = try ordered.map { sourceFrame -> SKAction in
                let resolved = try FrameResolver.resolve(frame: sourceFrame, animation: definition, atlases: pet.atlases)
                let texture = try textures.texture(for: resolved)
                return SKAction.sequence([
                    SKAction.run { [weak self] in
                        guard let self else { return }
                        self.sprite.texture = texture
                        self.sprite.xScale = resolved.flipX ? -abs(resolved.scale) : abs(resolved.scale)
                        self.sprite.yScale = abs(resolved.scale)
                        self.sprite.position = self.centeredSpritePosition(offsetX: resolved.offsetX, offsetY: resolved.offsetY)
                        self.fitSprite(texture: texture)
                    },
                    SKAction.wait(forDuration: resolved.duration)
                ])
            }
            let cycle = SKAction.sequence(frameActions)
            let action: SKAction
            let repeatsForever: Bool
            if !forceSingleCycle && (definition.loop ?? false) {
                action = SKAction.repeatForever(cycle)
                repeatsForever = true
            } else if let count = definition.loopCount, count > 1 {
                action = SKAction.repeat(cycle, count: min(count, 1_000))
                repeatsForever = false
            } else {
                action = cycle
                repeatsForever = false
            }
            if repeatsForever {
                sprite.run(action, withKey: "animation")
            } else {
                let completed = SKAction.run { [weak self] in
                    guard let self, self.animationToken == token else { return }
                    completion?()
                }
                sprite.run(SKAction.sequence([action, completed]), withKey: "animation")
            }
        } catch {
            completion?()
        }
    }

    func stopAndIdle() {
        animationToken = UUID()
        sprite.removeAction(forKey: "animation")
        playIdle()
    }

    func setContentInset(_ value: CGFloat) {
        contentInset = max(0, value)
        layoutSprite()
    }

    private func layoutSprite() {
        sprite.position = centeredSpritePosition(offsetX: 0, offsetY: 0)
        if let texture = sprite.texture { fitSprite(texture: texture) }
    }

    private func centeredSpritePosition(offsetX: Double, offsetY: Double) -> CGPoint {
        CGPoint(
            x: size.width / 2 + CGFloat(offsetX),
            y: size.height / 2 - CGFloat(offsetY)
        )
    }

    private func fitSprite(texture: SKTexture) {
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else { return }
        let available = CGSize(width: max(1, size.width - contentInset * 2), height: max(1, size.height - contentInset * 2))
        let factor = min(available.width / textureSize.width, available.height / textureSize.height)
        sprite.size = CGSize(width: textureSize.width * factor, height: textureSize.height * factor)
    }
}
