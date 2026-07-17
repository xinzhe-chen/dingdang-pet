import Foundation

public enum PointerActivityResolver {
    public static func didMove(distance: Double, threshold: Double = 1.5) -> Bool {
        distance >= max(0, threshold)
    }

    public static func shouldTrack(secondsSinceLastMovement: Double, timeout: Double) -> Bool {
        secondsSinceLastMovement <= max(0, timeout)
    }
}
