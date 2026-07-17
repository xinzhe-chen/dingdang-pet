import AppKit
import DingdangPetCore
import Foundation

@MainActor
final class PetBehaviorEngine {
    private weak var scene: PetScene?
    private var currentTask: Task<Void, Never>?
    private var behaviorToken = UUID()
    private(set) var context = BehaviorContext()
    private(set) var isPerformingBehavior = false
    var propertyHandler: ((String, BehaviorValue) -> Void)?
    var rootURL: URL?

    init(scene: PetScene) {
        self.scene = scene
    }

    func updateContext(_ key: String, value: BehaviorValue) {
        context.values[key] = value
    }

    func trigger(_ event: String) {
        guard let scene, let pet = scene.pet else { return }
        currentTask?.cancel()
        let token = UUID()
        behaviorToken = token
        isPerformingBehavior = true
        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.behaviorToken == token {
                    self.isPerformingBehavior = false
                    self.currentTask = nil
                }
            }
            if let node = pet.behaviors[event] {
                await self.run(node)
            } else if pet.bindings[event] != nil {
                await self.playBinding(event)
            }
            guard !Task.isCancelled, self.behaviorToken == token else { return }
            scene.playIdle()
        }
    }

    func playLocomotion(direction: Int) {
        let semantic = direction >= 0 ? "moveRight" : "moveLeft"
        guard scene?.currentAnimationName != scene?.pet?.bindings[semantic] else { return }
        currentTask?.cancel()
        currentTask = nil
        behaviorToken = UUID()
        isPerformingBehavior = false
        scene?.playBinding(semantic, forceSingleCycle: false)
    }

    func playLook(angleDegrees: Double, distance: Double) {
        guard let scene, let look = scene.pet?.directionalLook, look.enabled, distance >= look.deadzoneRadius, !look.angles.isEmpty else { return }
        let normalized = angleDegrees.truncatingRemainder(dividingBy: 360) + (angleDegrees < 0 ? 360 : 0)
        let nearest = look.angles.min {
            angularDistance($0.degrees, normalized) < angularDistance($1.degrees, normalized)
        }
        guard let animation = nearest?.animation, scene.currentAnimationName != animation else { return }
        scene.play(animation: animation, forceSingleCycle: false)
    }

    func returnToIdle() { scene?.playIdle() }

    private func run(_ node: BehaviorNode) async {
        guard !Task.isCancelled else { return }
        switch node.type {
        case .play:
            if let animation = node.animation { await play(animation) }
        case .wait:
            let nanoseconds = UInt64(max(0, node.durationMs ?? 0)) * 1_000_000
            try? await Task.sleep(nanoseconds: nanoseconds)
        case .sequence:
            for step in node.steps ?? [] {
                await run(step)
                if Task.isCancelled { return }
            }
        case .random:
            if let choice = BehaviorEvaluator.choose(node.choices ?? []) { await run(choice) }
        case .condition:
            let result = node.condition.map { BehaviorEvaluator.evaluate($0, context: context) } ?? false
            if let branch = result ? node.thenNode : node.elseNode { await run(branch) }
        case .transition:
            if let state = node.state {
                if scene?.pet?.animations[state] != nil { await play(state) }
                else { await playBinding(state) }
            }
        case .playSound:
            playSound(named: node.sound)
        case .set:
            if let property = node.property, let value = node.value {
                context.values[property] = value
                propertyHandler?(property, value)
            }
        }
    }

    private func play(_ animation: String) async {
        await withCheckedContinuation { continuation in
            scene?.play(animation: animation, forceSingleCycle: true) { continuation.resume() }
        }
    }

    private func playBinding(_ semantic: String) async {
        await withCheckedContinuation { continuation in
            scene?.playBinding(semantic, forceSingleCycle: true) { continuation.resume() }
        }
    }

    private func playSound(named name: String?) {
        guard let name, let definition = scene?.pet?.sounds?[name], let rootURL else { return }
        let sound = NSSound(contentsOf: rootURL.appendingPathComponent(definition.file), byReference: true)
        sound?.volume = Float(min(max(definition.volume ?? 1, 0), 1))
        sound?.play()
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        let delta = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(delta, 360 - delta)
    }
}
