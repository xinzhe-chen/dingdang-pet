import Foundation

public enum FrameResolutionError: LocalizedError, Equatable {
    case atlasNotFound(String)
    case invalidGrid(String)
    case frameOutOfBounds(row: Int, column: Int)
    case namedFrameNotFound(String)
    case incompleteReference

    public var errorDescription: String? {
        switch self {
        case .atlasNotFound(let id): return "Atlas not found: \(id)"
        case .invalidGrid(let id): return "Invalid grid layout: \(id)"
        case .frameOutOfBounds(let row, let column): return "Frame is out of bounds: row \(row), column \(column)"
        case .namedFrameNotFound(let name): return "Named frame not found: \(name)"
        case .incompleteReference: return "Frame reference must use row/column or name"
        }
    }
}

public struct ResolvedFrame: Sendable, Equatable {
    public var atlasID: String
    public var rect: FrameRect
    public var duration: TimeInterval
    public var offsetX: Double
    public var offsetY: Double
    public var scale: Double
    public var flipX: Bool

    public init(atlasID: String, rect: FrameRect, duration: TimeInterval, offsetX: Double, offsetY: Double, scale: Double, flipX: Bool) {
        self.atlasID = atlasID
        self.rect = rect
        self.duration = duration
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.flipX = flipX
    }
}

public enum FrameResolver {
    public static func resolve(
        frame: AnimationFrame,
        animation: AnimationDefinition,
        atlases: [AtlasDefinition]
    ) throws -> ResolvedFrame {
        guard let atlas = atlases.first(where: { $0.id == frame.atlas }) else {
            throw FrameResolutionError.atlasNotFound(frame.atlas)
        }

        let rect: FrameRect
        switch atlas.layout.type {
        case .grid:
            guard
                let columns = atlas.layout.columns,
                let rows = atlas.layout.rows,
                let cellWidth = atlas.layout.cellWidth,
                let cellHeight = atlas.layout.cellHeight,
                columns > 0, rows > 0, cellWidth > 0, cellHeight > 0
            else {
                throw FrameResolutionError.invalidGrid(atlas.id)
            }
            guard let row = frame.row, let column = frame.column else {
                throw FrameResolutionError.incompleteReference
            }
            guard row >= 0, row < rows, column >= 0, column < columns else {
                throw FrameResolutionError.frameOutOfBounds(row: row, column: column)
            }
            let spacing = atlas.layout.spacing ?? 0
            let margin = atlas.layout.margin ?? 0
            rect = FrameRect(
                x: margin + column * (cellWidth + spacing),
                y: margin + row * (cellHeight + spacing),
                width: cellWidth,
                height: cellHeight
            )
        case .rects:
            guard let name = frame.name else { throw FrameResolutionError.incompleteReference }
            guard let named = atlas.layout.frames?[name] else {
                throw FrameResolutionError.namedFrameNotFound(name)
            }
            rect = named
        }

        let defaultDuration = 1 / max(1, animation.fps ?? 8)
        return ResolvedFrame(
            atlasID: atlas.id,
            rect: rect,
            duration: frame.durationMs.map { Double($0) / 1_000 } ?? defaultDuration,
            offsetX: frame.offsetX ?? 0,
            offsetY: frame.offsetY ?? 0,
            scale: frame.scale ?? 1,
            flipX: frame.flipX ?? false
        )
    }

    public static func orderedFrames(for animation: AnimationDefinition) -> [AnimationFrame] {
        switch animation.playback ?? .forward {
        case .forward:
            return animation.frames
        case .reverse:
            return animation.frames.reversed()
        case .pingPong:
            guard animation.frames.count > 2 else { return animation.frames }
            return animation.frames + animation.frames.dropFirst().dropLast().reversed()
        }
    }
}
