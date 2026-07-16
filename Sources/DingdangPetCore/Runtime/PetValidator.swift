import CryptoKit
import Foundation
import ImageIO

public struct ValidationIssue: Codable, Sendable, Equatable {
    public enum Severity: String, Codable, Sendable { case error, warning }
    public var severity: Severity
    public var path: String
    public var message: String

    public init(_ severity: Severity, _ path: String, _ message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }
}

public struct ValidationReport: Codable, Sendable {
    public var issues: [ValidationIssue]
    public var isValid: Bool { !issues.contains(where: { $0.severity == .error }) }

    public init(issues: [ValidationIssue]) {
        self.issues = issues
    }
}

public enum PetSafetyLimits {
    public static let maximumPets = 128
    public static let maximumAtlasesPerPet = 32
    public static let maximumAnimationsPerPet = 512
    public static let maximumFramesPerAnimation = 4_096
    public static let maximumFiles = 4_096
    public static let maximumAtlasDimension = 16_384
    public static let maximumCatalogBytes = 256 * 1_024 * 1_024
    public static let maximumFPS = 60.0
    public static let supportedCapabilities: Set<String> = [
        "desktop-pet", "menu-bar-roaming", "pointer-look", "pointer-look-16",
        "weighted-actions", "behavior-graph", "multiple-atlases", "rect-frames",
        "audio", "codex-pet-v2"
    ]
}

public enum PetValidator {
    public static func validate(catalog: PetCatalog, rootURL: URL? = nil) -> ValidationReport {
        var issues: [ValidationIssue] = []
        if catalog.schemaVersion != 1 {
            issues.append(.init(.error, "schemaVersion", "Only schemaVersion 1 is supported"))
        }
        if catalog.pets.isEmpty || catalog.pets.count > PetSafetyLimits.maximumPets {
            issues.append(.init(.error, "pets", "Catalog must contain 1...\(PetSafetyLimits.maximumPets) pets"))
        }
        if !catalog.pets.contains(where: { $0.id == catalog.defaultPetID }) {
            issues.append(.init(.error, "defaultPetID", "Default pet is missing"))
        }

        var ids = Set<String>()
        for pet in catalog.pets {
            let prefix = "pets.\(pet.id)"
            if pet.id.isEmpty || !ids.insert(pet.id).inserted {
                issues.append(.init(.error, "\(prefix).id", "Pet id must be non-empty and unique"))
            }
            let unsupported = Set(pet.requiredCapabilities).subtracting(PetSafetyLimits.supportedCapabilities)
            if !unsupported.isEmpty {
                issues.append(.init(.error, "\(prefix).requiredCapabilities", "Unsupported capabilities: \(unsupported.sorted().joined(separator: ", "))"))
            }
            if pet.atlases.isEmpty || pet.atlases.count > PetSafetyLimits.maximumAtlasesPerPet {
                issues.append(.init(.error, "\(prefix).atlases", "Invalid atlas count"))
            }
            if pet.animations.isEmpty || pet.animations.count > PetSafetyLimits.maximumAnimationsPerPet {
                issues.append(.init(.error, "\(prefix).animations", "Invalid animation count"))
            }

            let atlasIDs = Set(pet.atlases.map(\.id))
            if atlasIDs.count != pet.atlases.count {
                issues.append(.init(.error, "\(prefix).atlases", "Atlas ids must be unique"))
            }
            for atlas in pet.atlases {
                validate(atlas: atlas, petPrefix: prefix, rootURL: rootURL, issues: &issues)
            }
            for (name, animation) in pet.animations {
                if animation.frames.isEmpty || animation.frames.count > PetSafetyLimits.maximumFramesPerAnimation {
                    issues.append(.init(.error, "\(prefix).animations.\(name)", "Invalid frame count"))
                }
                if let fps = animation.fps, fps <= 0 || fps > PetSafetyLimits.maximumFPS {
                    issues.append(.init(.error, "\(prefix).animations.\(name).fps", "FPS must be in 0...\(PetSafetyLimits.maximumFPS)"))
                }
                for (index, frame) in animation.frames.enumerated() {
                    if !atlasIDs.contains(frame.atlas) {
                        issues.append(.init(.error, "\(prefix).animations.\(name).frames.\(index)", "Unknown atlas \(frame.atlas)"))
                        continue
                    }
                    do { _ = try FrameResolver.resolve(frame: frame, animation: animation, atlases: pet.atlases) }
                    catch { issues.append(.init(.error, "\(prefix).animations.\(name).frames.\(index)", error.localizedDescription)) }
                }
            }
            for (semantic, animation) in pet.bindings where pet.animations[animation] == nil {
                issues.append(.init(.error, "\(prefix).bindings.\(semantic)", "Unknown animation \(animation)"))
            }
            if pet.bindings["defaultIdle"] == nil {
                issues.append(.init(.error, "\(prefix).bindings.defaultIdle", "defaultIdle binding is required"))
            }
            for direction in pet.directionalLook?.angles ?? [] where pet.animations[direction.animation] == nil {
                issues.append(.init(.error, "\(prefix).directionalLook", "Unknown look animation \(direction.animation)"))
            }
        }
        return ValidationReport(issues: issues)
    }

    private static func validate(atlas: AtlasDefinition, petPrefix: String, rootURL: URL?, issues: inout [ValidationIssue]) {
        let path = "\(petPrefix).atlases.\(atlas.id)"
        switch atlas.layout.type {
        case .grid:
            guard let columns = atlas.layout.columns, let rows = atlas.layout.rows,
                  let width = atlas.layout.cellWidth, let height = atlas.layout.cellHeight,
                  columns > 0, rows > 0, width > 0, height > 0 else {
                issues.append(.init(.error, path, "Grid atlas requires positive rows, columns, cellWidth and cellHeight"))
                return
            }
        case .rects:
            if atlas.layout.frames?.isEmpty != false {
                issues.append(.init(.error, path, "Rect atlas requires named frames"))
            }
        }
        guard let rootURL else { return }
        let fileURL = rootURL.appendingPathComponent(atlas.file)
        guard fileURL.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path + "/") else {
            issues.append(.init(.error, path, "Atlas path escapes the pet package"))
            return
        }
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
            issues.append(.init(.error, path, "Atlas image cannot be decoded: \(atlas.file)"))
            return
        }
        if pixelWidth > PetSafetyLimits.maximumAtlasDimension || pixelHeight > PetSafetyLimits.maximumAtlasDimension {
            issues.append(.init(.error, path, "Atlas exceeds maximum dimensions"))
        }
        if atlas.layout.type == .grid,
           let columns = atlas.layout.columns, let rows = atlas.layout.rows,
           let cellWidth = atlas.layout.cellWidth, let cellHeight = atlas.layout.cellHeight {
            let spacing = atlas.layout.spacing ?? 0
            let margin = atlas.layout.margin ?? 0
            let expectedWidth = margin * 2 + columns * cellWidth + max(0, columns - 1) * spacing
            let expectedHeight = margin * 2 + rows * cellHeight + max(0, rows - 1) * spacing
            if expectedWidth > pixelWidth || expectedHeight > pixelHeight {
                issues.append(.init(.error, path, "Grid geometry exceeds atlas image bounds"))
            }
        }
    }
}

public enum ContentSignature {
    public static func verify(manifestData: Data, signatureBase64: String, publicKeyBase64: String) -> Bool {
        guard let signature = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
              let publicKeyData = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else { return false }
        return key.isValidSignature(signature, for: manifestData)
    }

    public static func sign(manifestData: Data, privateKeyBase64: String) throws -> String {
        guard let privateKeyData = Data(base64Encoded: privateKeyBase64) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        return try key.signature(for: manifestData).base64EncodedString()
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
