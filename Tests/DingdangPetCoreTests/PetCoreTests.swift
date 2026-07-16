import XCTest
@testable import DingdangPetCore

final class PetCoreTests: XCTestCase {
    func testGridFrameResolutionUsesVariableGeometry() throws {
        let atlas = AtlasDefinition(
            id: "main",
            file: "sheet.png",
            layout: AtlasLayout(type: .grid, columns: 12, rows: 17, cellWidth: 40, cellHeight: 50, spacing: 2, margin: 3)
        )
        let animation = AnimationDefinition(frames: [], fps: 10)
        let frame = AnimationFrame(atlas: "main", row: 4, column: 7)
        let resolved = try FrameResolver.resolve(frame: frame, animation: animation, atlases: [atlas])
        XCTAssertEqual(resolved.rect, FrameRect(x: 297, y: 211, width: 40, height: 50))
        XCTAssertEqual(resolved.duration, 0.1, accuracy: 0.0001)
    }

    func testRectFrameResolution() throws {
        let atlas = AtlasDefinition(
            id: "irregular",
            file: "sheet.webp",
            layout: AtlasLayout(type: .rects, frames: ["wave-2": FrameRect(x: 5, y: 9, width: 88, height: 91)])
        )
        let animation = AnimationDefinition(frames: [])
        let resolved = try FrameResolver.resolve(frame: AnimationFrame(atlas: "irregular", name: "wave-2", durationMs: 250), animation: animation, atlases: [atlas])
        XCTAssertEqual(resolved.rect, FrameRect(x: 5, y: 9, width: 88, height: 91))
        XCTAssertEqual(resolved.duration, 0.25, accuracy: 0.0001)
    }

    func testPingPongFrameOrder() {
        let frames = (0..<4).map { AnimationFrame(atlas: "a", row: 0, column: $0) }
        let animation = AnimationDefinition(frames: frames, playback: .pingPong)
        XCTAssertEqual(FrameResolver.orderedFrames(for: animation).compactMap(\.column), [0, 1, 2, 3, 2, 1])
    }

    func testBehaviorConditionsAndWeightedChoice() {
        let condition = BehaviorCondition(all: [
            BehaviorCondition(variable: "displayMode", equals: .string("menuBar")),
            BehaviorCondition(variable: "distanceToRightEdge", lessThan: 40)
        ])
        let context = BehaviorContext(values: ["displayMode": .string("menuBar"), "distanceToRightEdge": .number(12)])
        XCTAssertTrue(BehaviorEvaluator.evaluate(condition, context: context))

        let first = BehaviorNode(type: .play, animation: "wave")
        let second = BehaviorNode(type: .play, animation: "jump")
        let choices = [WeightedBehavior(weight: 70, run: first), WeightedBehavior(weight: 30, run: second)]
        XCTAssertEqual(BehaviorEvaluator.choose(choices, random: 0.1)?.animation, "wave")
        XCTAssertEqual(BehaviorEvaluator.choose(choices, random: 0.9)?.animation, "jump")
    }

    func testSignatureRoundTrip() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let data = Data("manifest".utf8)
        let signature = try ContentSignature.sign(manifestData: data, privateKeyBase64: privateKey.rawRepresentation.base64EncodedString())
        XCTAssertTrue(ContentSignature.verify(manifestData: data, signatureBase64: signature, publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()))
        XCTAssertFalse(ContentSignature.verify(manifestData: Data("other".utf8), signatureBase64: signature, publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()))
    }

    func testValidatorRejectsAtlasPathTraversal() {
        let atlas = AtlasDefinition(
            id: "main",
            file: "../outside.png",
            layout: AtlasLayout(type: .grid, columns: 1, rows: 1, cellWidth: 1, cellHeight: 1)
        )
        let idle = AnimationDefinition(frames: [AnimationFrame(atlas: "main", row: 0, column: 0)])
        let pet = PetDefinition(
            id: "unsafe",
            displayName: "Unsafe",
            version: "1",
            atlases: [atlas],
            animations: ["idle": idle],
            bindings: ["defaultIdle": "idle"]
        )
        let catalog = PetCatalog(schemaVersion: 1, catalogVersion: "1", defaultPetID: "unsafe", pets: [pet])
        let report = PetValidator.validate(catalog: catalog, rootURL: URL(fileURLWithPath: "/tmp/catalog-root", isDirectory: true))
        XCTAssertTrue(report.issues.contains(where: { $0.message == "Atlas path escapes the pet package" }))
    }

    func testValidatorRejectsUnknownBindingAndCapability() {
        let atlas = AtlasDefinition(
            id: "main",
            file: "sheet.png",
            layout: AtlasLayout(type: .grid, columns: 1, rows: 1, cellWidth: 1, cellHeight: 1)
        )
        let idle = AnimationDefinition(frames: [AnimationFrame(atlas: "main", row: 0, column: 0)])
        let pet = PetDefinition(
            id: "pet",
            displayName: "Pet",
            version: "1",
            requiredCapabilities: ["execute-code"],
            atlases: [atlas],
            animations: ["idle": idle],
            bindings: ["defaultIdle": "missing"]
        )
        let catalog = PetCatalog(schemaVersion: 1, catalogVersion: "1", defaultPetID: "pet", pets: [pet])
        let report = PetValidator.validate(catalog: catalog)
        XCTAssertTrue(report.issues.contains(where: { $0.message.contains("Unsupported capabilities") }))
        XCTAssertTrue(report.issues.contains(where: { $0.message == "Unknown animation missing" }))
    }

    func testArchiveEntryValidatorAcceptsCatalogAssets() throws {
        try ArchiveEntryValidator.validate([
            "catalog.json",
            "pets/dingdang/spritesheet.png",
            "pets/dingdang/sounds/click.wav"
        ])
    }

    func testArchiveEntryValidatorRejectsTraversalAndPlatformPaths() {
        for entries in [["../outside"], ["/absolute"], ["pets\\evil.png"], ["pets/./evil.png"], ["~/secret"]] {
            XCTAssertThrowsError(try ArchiveEntryValidator.validate(entries))
        }
        XCTAssertThrowsError(try ArchiveEntryValidator.validate([]))
        XCTAssertThrowsError(try ArchiveEntryValidator.validate(["a", "b"], maximumFiles: 1))
    }
}

import CryptoKit
