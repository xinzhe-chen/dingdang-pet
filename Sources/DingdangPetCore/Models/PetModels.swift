import Foundation

public struct PetCatalog: Codable, Sendable {
    public var schemaVersion: Int
    public var catalogVersion: String
    public var defaultPetID: String
    public var pets: [PetDefinition]

    public init(schemaVersion: Int, catalogVersion: String, defaultPetID: String, pets: [PetDefinition]) {
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.defaultPetID = defaultPetID
        self.pets = pets
    }
}

public struct PetDefinition: Codable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    public var description: String?
    public var author: String?
    public var version: String
    public var format: String
    public var requiredCapabilities: [String]
    public var atlases: [AtlasDefinition]
    public var animations: [String: AnimationDefinition]
    public var bindings: [String: String]
    public var behaviors: [String: BehaviorNode]
    public var directionalLook: DirectionalLookDefinition?
    public var presentation: PresentationDefinition
    public var sounds: [String: SoundDefinition]?

    public init(
        id: String,
        displayName: String,
        description: String? = nil,
        author: String? = nil,
        version: String,
        format: String = "dingdang-pet-v1",
        requiredCapabilities: [String] = [],
        atlases: [AtlasDefinition],
        animations: [String: AnimationDefinition],
        bindings: [String: String],
        behaviors: [String: BehaviorNode] = [:],
        directionalLook: DirectionalLookDefinition? = nil,
        presentation: PresentationDefinition = .default,
        sounds: [String: SoundDefinition]? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.author = author
        self.version = version
        self.format = format
        self.requiredCapabilities = requiredCapabilities
        self.atlases = atlases
        self.animations = animations
        self.bindings = bindings
        self.behaviors = behaviors
        self.directionalLook = directionalLook
        self.presentation = presentation
        self.sounds = sounds
    }
}

public struct AtlasDefinition: Codable, Sendable, Identifiable {
    public var id: String
    public var file: String
    public var layout: AtlasLayout
    public var filtering: TextureFiltering?

    public init(id: String, file: String, layout: AtlasLayout, filtering: TextureFiltering? = nil) {
        self.id = id
        self.file = file
        self.layout = layout
        self.filtering = filtering
    }
}

public enum TextureFiltering: String, Codable, Sendable {
    case nearest
    case linear
}

public struct AtlasLayout: Codable, Sendable {
    public var type: LayoutType
    public var columns: Int?
    public var rows: Int?
    public var cellWidth: Int?
    public var cellHeight: Int?
    public var spacing: Int?
    public var margin: Int?
    public var frames: [String: FrameRect]?

    public init(
        type: LayoutType,
        columns: Int? = nil,
        rows: Int? = nil,
        cellWidth: Int? = nil,
        cellHeight: Int? = nil,
        spacing: Int? = nil,
        margin: Int? = nil,
        frames: [String: FrameRect]? = nil
    ) {
        self.type = type
        self.columns = columns
        self.rows = rows
        self.cellWidth = cellWidth
        self.cellHeight = cellHeight
        self.spacing = spacing
        self.margin = margin
        self.frames = frames
    }
}

public enum LayoutType: String, Codable, Sendable {
    case grid
    case rects
}

public struct FrameRect: Codable, Sendable, Equatable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AnimationDefinition: Codable, Sendable {
    public var frames: [AnimationFrame]
    public var fps: Double?
    public var loop: Bool?
    public var loopCount: Int?
    public var playback: PlaybackMode?
    public var priority: Int?
    public var interruptible: Bool?

    public init(
        frames: [AnimationFrame],
        fps: Double? = nil,
        loop: Bool? = nil,
        loopCount: Int? = nil,
        playback: PlaybackMode? = nil,
        priority: Int? = nil,
        interruptible: Bool? = nil
    ) {
        self.frames = frames
        self.fps = fps
        self.loop = loop
        self.loopCount = loopCount
        self.playback = playback
        self.priority = priority
        self.interruptible = interruptible
    }
}

public struct AnimationFrame: Codable, Sendable {
    public var atlas: String
    public var row: Int?
    public var column: Int?
    public var name: String?
    public var durationMs: Int?
    public var offsetX: Double?
    public var offsetY: Double?
    public var scale: Double?
    public var flipX: Bool?

    public init(
        atlas: String,
        row: Int? = nil,
        column: Int? = nil,
        name: String? = nil,
        durationMs: Int? = nil,
        offsetX: Double? = nil,
        offsetY: Double? = nil,
        scale: Double? = nil,
        flipX: Bool? = nil
    ) {
        self.atlas = atlas
        self.row = row
        self.column = column
        self.name = name
        self.durationMs = durationMs
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.flipX = flipX
    }
}

public enum PlaybackMode: String, Codable, Sendable {
    case forward
    case reverse
    case pingPong
}

public struct DirectionalLookDefinition: Codable, Sendable {
    public var enabled: Bool
    public var deadzoneRadius: Double
    public var selection: String
    public var angles: [DirectionalAnimation]
    public var movementTimeout: Double?

    public init(enabled: Bool = true, deadzoneRadius: Double = 40, selection: String = "nearest-angle", angles: [DirectionalAnimation], movementTimeout: Double? = nil) {
        self.enabled = enabled
        self.deadzoneRadius = deadzoneRadius
        self.selection = selection
        self.angles = angles
        self.movementTimeout = movementTimeout
    }
}

public struct DirectionalAnimation: Codable, Sendable {
    public var degrees: Double
    public var animation: String

    public init(degrees: Double, animation: String) {
        self.degrees = degrees
        self.animation = animation
    }
}

public struct PresentationDefinition: Codable, Sendable {
    public var desktop: DisplayProfile
    public var menuBar: MenuBarProfile
    public var randomIdleInterval: ClosedRangeValue?

    public static let `default` = PresentationDefinition(
        desktop: DisplayProfile(defaultScale: 1, minimumScale: 0.4, maximumScale: 3, height: 208),
        menuBar: MenuBarProfile(height: 22, fillsAvailableHeight: true, speed: 32, safeMarginLeft: 80, safeMarginRight: 220, pauseInterval: ClosedRangeValue(min: 2, max: 7), avoidNotch: true, notchTraversal: .continuous),
        randomIdleInterval: ClosedRangeValue(min: 8, max: 20)
    )

    public init(desktop: DisplayProfile, menuBar: MenuBarProfile, randomIdleInterval: ClosedRangeValue? = nil) {
        self.desktop = desktop
        self.menuBar = menuBar
        self.randomIdleInterval = randomIdleInterval
    }
}

public struct DisplayProfile: Codable, Sendable {
    public var defaultScale: Double
    public var minimumScale: Double
    public var maximumScale: Double
    public var height: Double
    public var anchorX: Double?
    public var anchorY: Double?

    public init(defaultScale: Double, minimumScale: Double, maximumScale: Double, height: Double, anchorX: Double? = nil, anchorY: Double? = nil) {
        self.defaultScale = defaultScale
        self.minimumScale = minimumScale
        self.maximumScale = maximumScale
        self.height = height
        self.anchorX = anchorX
        self.anchorY = anchorY
    }
}

public struct MenuBarProfile: Codable, Sendable {
    public var height: Double
    public var fillsAvailableHeight: Bool?
    public var speed: Double
    public var safeMarginLeft: Double
    public var safeMarginRight: Double
    public var pauseInterval: ClosedRangeValue?
    public var avoidNotch: Bool
    public var notchTraversal: NotchTraversal?

    public init(height: Double, fillsAvailableHeight: Bool? = nil, speed: Double, safeMarginLeft: Double, safeMarginRight: Double, pauseInterval: ClosedRangeValue? = nil, avoidNotch: Bool = true, notchTraversal: NotchTraversal? = nil) {
        self.height = height
        self.fillsAvailableHeight = fillsAvailableHeight
        self.speed = speed
        self.safeMarginLeft = safeMarginLeft
        self.safeMarginRight = safeMarginRight
        self.pauseInterval = pauseInterval
        self.avoidNotch = avoidNotch
        self.notchTraversal = notchTraversal
    }
}

public enum NotchTraversal: String, Codable, Sendable {
    case continuous
    case skip
}

public struct ClosedRangeValue: Codable, Sendable {
    public var min: Double
    public var max: Double

    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
}

public struct SoundDefinition: Codable, Sendable {
    public var file: String
    public var volume: Double?

    public init(file: String, volume: Double? = nil) {
        self.file = file
        self.volume = volume
    }
}
