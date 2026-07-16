import CryptoKit
import DingdangPetCore
import Foundation

enum ToolError: LocalizedError {
    case usage(String)
    case validation([ValidationIssue])
    case process(String)

    var errorDescription: String? {
        switch self {
        case .usage(let text): return text
        case .validation(let issues): return issues.map { "[\($0.severity.rawValue)] \($0.path): \($0.message)" }.joined(separator: "\n")
        case .process(let text): return text
        }
    }
}

@main
struct DingdangPetTool {
    static func main() {
        do { try run() }
        catch {
            FileHandle.standardError.write(Data(("error: \(error.localizedDescription)\n").utf8))
            exit(1)
        }
    }

    static func run() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else { throw ToolError.usage(usage) }
        arguments.removeFirst()
        switch command {
        case "validate":
            guard arguments.count == 1 else { throw ToolError.usage("validate <catalog-directory>") }
            let root = URL(fileURLWithPath: arguments[0], isDirectory: true).standardizedFileURL
            let catalog = try loadCatalog(root)
            let report = PetValidator.validate(catalog: catalog, rootURL: root)
            let data = try JSONEncoder.pretty.encode(report)
            print(String(decoding: data, as: UTF8.self))
            if !report.isValid { throw ToolError.validation(report.issues) }
        case "generate-key":
            guard arguments.count == 2 else { throw ToolError.usage("generate-key <private-key-file> <public-key-file>") }
            let key = Curve25519.Signing.PrivateKey()
            try key.rawRepresentation.base64EncodedString().write(toFile: arguments[0], atomically: true, encoding: .utf8)
            try key.publicKey.rawRepresentation.base64EncodedString().write(toFile: arguments[1], atomically: true, encoding: .utf8)
            print("private_key=\(arguments[0])")
            print("public_key=\(arguments[1])")
        case "sign":
            guard arguments.count == 3 else { throw ToolError.usage("sign <manifest.json> <private-key-file> <manifest.sig>") }
            let manifest = try Data(contentsOf: URL(fileURLWithPath: arguments[0]))
            let privateKey = try String(contentsOfFile: arguments[1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            let signature = try ContentSignature.sign(manifestData: manifest, privateKeyBase64: privateKey)
            try signature.write(toFile: arguments[2], atomically: true, encoding: .utf8)
        case "verify":
            guard arguments.count == 3 else { throw ToolError.usage("verify <manifest.json> <manifest.sig> <public-key-file>") }
            let manifest = try Data(contentsOf: URL(fileURLWithPath: arguments[0]))
            let signature = try String(contentsOfFile: arguments[1], encoding: .utf8)
            let publicKey = try String(contentsOfFile: arguments[2], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            guard ContentSignature.verify(manifestData: manifest, signatureBase64: signature, publicKeyBase64: publicKey) else {
                throw ToolError.process("signature verification failed")
            }
            print("signature=valid")
        case "package":
            guard arguments.count == 5 else { throw ToolError.usage("package <catalog-directory> <version> <asset-base-url> <output-directory> <private-key-file>") }
            try package(catalogDirectory: arguments[0], version: arguments[1], assetBaseURL: arguments[2], outputDirectory: arguments[3], privateKeyFile: arguments[4])
        case "import-codex-v2":
            guard arguments.count == 5 else {
                throw ToolError.usage("import-codex-v2 <atlas.png> <pet-id> <display-name> <version> <output-directory>")
            }
            try importCodexV2(
                atlasPath: arguments[0],
                petID: arguments[1],
                displayName: arguments[2],
                version: arguments[3],
                outputDirectory: arguments[4]
            )
        default:
            throw ToolError.usage(usage)
        }
    }

    static func importCodexV2(atlasPath: String, petID: String, displayName: String, version: String, outputDirectory: String) throws {
        let source = URL(fileURLWithPath: atlasPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ToolError.process("atlas does not exist: \(source.path)")
        }

        let root = URL(fileURLWithPath: outputDirectory, isDirectory: true).standardizedFileURL
        let petDirectory = root.appendingPathComponent("pets/\(petID)", isDirectory: true)
        try FileManager.default.createDirectory(at: petDirectory, withIntermediateDirectories: true)
        let destination = petDirectory.appendingPathComponent("spritesheet.png")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)

        let catalog = makeCodexV2Catalog(petID: petID, displayName: displayName, version: version)
        try JSONEncoder.pretty.encode(catalog).write(to: root.appendingPathComponent("catalog.json"), options: .atomic)
        let report = PetValidator.validate(catalog: catalog, rootURL: root)
        guard report.isValid else { throw ToolError.validation(report.issues) }
        print("catalog=\(root.appendingPathComponent("catalog.json").path)")
        print("atlas=\(destination.path)")
    }

    static func makeCodexV2Catalog(petID: String, displayName: String, version: String) -> PetCatalog {
        func frames(row: Int, durations: [Int]) -> [AnimationFrame] {
            durations.enumerated().map { column, duration in
                AnimationFrame(atlas: "main", row: row, column: column, durationMs: duration)
            }
        }

        let definitions: [(String, Int, [Int], Bool)] = [
            ("idle", 0, [280, 110, 110, 140, 140, 320], true),
            ("running-right", 1, [120, 120, 120, 120, 120, 120, 120, 220], true),
            ("running-left", 2, [120, 120, 120, 120, 120, 120, 120, 220], true),
            ("waving", 3, [140, 140, 140, 280], false),
            ("jumping", 4, [140, 140, 140, 140, 280], false),
            ("failed", 5, [140, 140, 140, 140, 140, 140, 140, 240], false),
            ("waiting", 6, [150, 150, 150, 150, 150, 260], true),
            ("running", 7, [120, 120, 120, 120, 120, 220], true),
            ("review", 8, [150, 150, 150, 150, 150, 280], true)
        ]
        var animations = Dictionary(uniqueKeysWithValues: definitions.map { name, row, durations, loop in
            (name, AnimationDefinition(frames: frames(row: row, durations: durations), loop: loop))
        })
        var lookAngles: [DirectionalAnimation] = []
        for index in 0..<16 {
            let degrees = Double(index) * 22.5
            let name = String(format: "look-%03d", Int(degrees * 10))
            let row = index < 8 ? 9 : 10
            let column = index % 8
            animations[name] = AnimationDefinition(frames: [AnimationFrame(atlas: "main", row: row, column: column)], loop: true)
            lookAngles.append(DirectionalAnimation(degrees: degrees, animation: name))
        }

        let pet = PetDefinition(
            id: petID,
            displayName: displayName,
            description: "Codex Pet v2 compatible animated pet",
            author: "Dingdang Pet",
            version: version,
            format: "codex-pet-v2",
            requiredCapabilities: ["desktop-pet", "menu-bar-roaming", "pointer-look", "behavior-graph"],
            atlases: [
                AtlasDefinition(
                    id: "main",
                    file: "pets/\(petID)/spritesheet.png",
                    layout: AtlasLayout(type: .grid, columns: 8, rows: 11, cellWidth: 192, cellHeight: 208, spacing: 0, margin: 0),
                    filtering: .nearest
                )
            ],
            animations: animations,
            bindings: [
                "defaultIdle": "idle",
                "moveRight": "running-right",
                "moveLeft": "running-left",
                "primaryClick": "waving",
                "secondaryClick": "jumping",
                "longPress": "waiting"
            ],
            behaviors: [
                "primaryClick": BehaviorNode(type: .random, choices: [
                    WeightedBehavior(weight: 70, run: BehaviorNode(type: .play, animation: "waving")),
                    WeightedBehavior(weight: 30, run: BehaviorNode(type: .play, animation: "jumping"))
                ]),
                "secondaryClick": BehaviorNode(type: .sequence, steps: [
                    BehaviorNode(type: .play, animation: "jumping"),
                    BehaviorNode(type: .wait, durationMs: 100),
                    BehaviorNode(type: .play, animation: "waving")
                ]),
                "longPress": BehaviorNode(type: .play, animation: "waiting"),
                "randomIdle": BehaviorNode(type: .random, choices: [
                    WeightedBehavior(weight: 45, run: BehaviorNode(type: .play, animation: "waving")),
                    WeightedBehavior(weight: 30, run: BehaviorNode(type: .play, animation: "review")),
                    WeightedBehavior(weight: 25, run: BehaviorNode(type: .play, animation: "running"))
                ])
            ],
            directionalLook: DirectionalLookDefinition(enabled: true, deadzoneRadius: 90, selection: "nearest-angle", angles: lookAngles),
            presentation: PresentationDefinition(
                desktop: DisplayProfile(defaultScale: 0.55, minimumScale: 0.2, maximumScale: 2.5, height: 208, anchorX: 0.5, anchorY: 0.05),
                menuBar: MenuBarProfile(height: 22, speed: 34, safeMarginLeft: 90, safeMarginRight: 230, pauseInterval: ClosedRangeValue(min: 1.5, max: 5), avoidNotch: true),
                randomIdleInterval: ClosedRangeValue(min: 9, max: 24)
            )
        )
        return PetCatalog(schemaVersion: 1, catalogVersion: version, defaultPetID: petID, pets: [pet])
    }

    static func package(catalogDirectory: String, version: String, assetBaseURL: String, outputDirectory: String, privateKeyFile: String) throws {
        let root = URL(fileURLWithPath: catalogDirectory, isDirectory: true).standardizedFileURL
        let catalog = try loadCatalog(root)
        let report = PetValidator.validate(catalog: catalog, rootURL: root)
        guard report.isValid else { throw ToolError.validation(report.issues) }

        let output = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let assetName = "pet-catalog-\(version).zip"
        let archiveURL = output.appendingPathComponent(assetName)
        try? FileManager.default.removeItem(at: archiveURL)
        try process("/usr/bin/ditto", ["-c", "-k", "--norsrc", "--noextattr", root.path + "/", archiveURL.path])
        let archive = try Data(contentsOf: archiveURL)
        let manifest = CatalogReleaseManifest(
            schemaVersion: 1,
            catalogVersion: version,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            archive: ReleaseArchive(
                url: assetBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + assetName,
                sha256: ContentSignature.sha256Hex(archive),
                size: archive.count
            )
        )
        let manifestData = try JSONEncoder.canonical.encode(manifest)
        let manifestURL = output.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestURL, options: .atomic)
        let privateKey = try String(contentsOfFile: privateKeyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = try ContentSignature.sign(manifestData: manifestData, privateKeyBase64: privateKey)
        try signature.write(to: output.appendingPathComponent("manifest.sig"), atomically: true, encoding: .utf8)
        print("archive=\(archiveURL.path)")
        print("manifest=\(manifestURL.path)")
        print("signature=\(output.appendingPathComponent("manifest.sig").path)")
    }

    static func loadCatalog(_ root: URL) throws -> PetCatalog {
        let data = try Data(contentsOf: root.appendingPathComponent("catalog.json"))
        return try JSONDecoder().decode(PetCatalog.self, from: data)
    }

    static func process(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw ToolError.process(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
        }
    }

    static let usage = """
    dingdang-pet-tool commands:
      validate <catalog-directory>
      generate-key <private-key-file> <public-key-file>
      sign <manifest.json> <private-key-file> <manifest.sig>
      verify <manifest.json> <manifest.sig> <public-key-file>
      package <catalog-directory> <version> <asset-base-url> <output-directory> <private-key-file>
      import-codex-v2 <atlas.png> <pet-id> <display-name> <version> <output-directory>
    """
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static var canonical: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
