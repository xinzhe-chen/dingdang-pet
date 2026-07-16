import Foundation

public final class BehaviorNode: Codable, @unchecked Sendable {
    public var type: BehaviorType
    public var animation: String?
    public var sound: String?
    public var durationMs: Int?
    public var state: String?
    public var steps: [BehaviorNode]?
    public var choices: [WeightedBehavior]?
    public var condition: BehaviorCondition?
    public var thenNode: BehaviorNode?
    public var elseNode: BehaviorNode?
    public var property: String?
    public var value: BehaviorValue?

    enum CodingKeys: String, CodingKey {
        case type, animation, sound, durationMs, state, steps, choices, condition, property, value
        case thenNode = "then"
        case elseNode = "else"
    }

    public init(
        type: BehaviorType,
        animation: String? = nil,
        sound: String? = nil,
        durationMs: Int? = nil,
        state: String? = nil,
        steps: [BehaviorNode]? = nil,
        choices: [WeightedBehavior]? = nil,
        condition: BehaviorCondition? = nil,
        thenNode: BehaviorNode? = nil,
        elseNode: BehaviorNode? = nil,
        property: String? = nil,
        value: BehaviorValue? = nil
    ) {
        self.type = type
        self.animation = animation
        self.sound = sound
        self.durationMs = durationMs
        self.state = state
        self.steps = steps
        self.choices = choices
        self.condition = condition
        self.thenNode = thenNode
        self.elseNode = elseNode
        self.property = property
        self.value = value
    }
}

public enum BehaviorType: String, Codable, Sendable {
    case play
    case wait
    case sequence
    case random
    case condition
    case transition
    case playSound
    case set
}

public struct WeightedBehavior: Codable, Sendable {
    public var weight: Double
    public var run: BehaviorNode

    public init(weight: Double, run: BehaviorNode) {
        self.weight = weight
        self.run = run
    }
}

public struct BehaviorCondition: Codable, Sendable {
    public var variable: String?
    public var equals: BehaviorValue?
    public var notEquals: BehaviorValue?
    public var lessThan: Double?
    public var greaterThan: Double?
    public var all: [BehaviorCondition]?
    public var any: [BehaviorCondition]?
    public var not: [BehaviorCondition]?

    public init(
        variable: String? = nil,
        equals: BehaviorValue? = nil,
        notEquals: BehaviorValue? = nil,
        lessThan: Double? = nil,
        greaterThan: Double? = nil,
        all: [BehaviorCondition]? = nil,
        any: [BehaviorCondition]? = nil,
        not: [BehaviorCondition]? = nil
    ) {
        self.variable = variable
        self.equals = equals
        self.notEquals = notEquals
        self.lessThan = lessThan
        self.greaterThan = greaterThan
        self.all = all
        self.any = any
        self.not = not
    }
}

public enum BehaviorValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }

    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }
}
