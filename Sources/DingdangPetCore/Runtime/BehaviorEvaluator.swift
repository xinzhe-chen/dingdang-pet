import Foundation

public struct BehaviorContext: Sendable {
    public var values: [String: BehaviorValue]

    public init(values: [String: BehaviorValue] = [:]) {
        self.values = values
    }
}

public enum BehaviorEvaluator {
    public static func evaluate(_ condition: BehaviorCondition, context: BehaviorContext) -> Bool {
        if let conditions = condition.all, !conditions.allSatisfy({ evaluate($0, context: context) }) {
            return false
        }
        if let conditions = condition.any, !conditions.contains(where: { evaluate($0, context: context) }) {
            return false
        }
        if let conditions = condition.not, conditions.contains(where: { evaluate($0, context: context) }) {
            return false
        }
        guard let variable = condition.variable else {
            return condition.all != nil || condition.any != nil || condition.not != nil
        }
        guard let actual = context.values[variable] else { return false }
        if let expected = condition.equals, actual != expected { return false }
        if let expected = condition.notEquals, actual == expected { return false }
        if let threshold = condition.lessThan {
            guard let number = actual.numberValue, number < threshold else { return false }
        }
        if let threshold = condition.greaterThan {
            guard let number = actual.numberValue, number > threshold else { return false }
        }
        return true
    }

    public static func choose(_ choices: [WeightedBehavior], random: Double = Double.random(in: 0..<1)) -> BehaviorNode? {
        let valid = choices.filter { $0.weight > 0 }
        let total = valid.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var cursor = max(0, min(random, 0.999_999)) * total
        for choice in valid {
            cursor -= choice.weight
            if cursor < 0 { return choice.run }
        }
        return valid.last?.run
    }
}
