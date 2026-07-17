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

    func testMenuBarBoundsReachBothSides() {
        let bounds = MenuBarMovementResolver.bounds(
            screenMinX: 0,
            screenMaxX: 1_440,
            panelWidth: 24,
            leftMargin: 90,
            rightMargin: 230
        )
        XCTAssertEqual(bounds.lowerBound, 90)
        XCTAssertEqual(bounds.upperBound, 1_186)
    }

    func testMenuBarVerticalGeometryUsesActualReservedHeightAndStaysOnScreen() {
        XCTAssertEqual(
            MenuBarMovementResolver.verticalGeometry(
                screenMaxY: 956,
                visibleFrameMaxY: 923,
                systemThickness: 22
            ),
            MenuBarVerticalGeometry(bottom: 923, height: 33)
        )
        XCTAssertEqual(
            MenuBarMovementResolver.verticalGeometry(
                screenMaxY: 956,
                visibleFrameMaxY: 956,
                systemThickness: 22
            ),
            MenuBarVerticalGeometry(bottom: 934, height: 22)
        )
    }

    func testMenuBarMovementCrossesNotchContinuouslyWithoutTurningAround() {
        let right = MenuBarMovementResolver.advance(
            currentX: 674,
            direction: 1,
            speed: 40,
            delta: 0.1,
            bounds: 90...1_186,
            panelWidth: 24,
            notch: 700...740
        )
        XCTAssertEqual(right.x, 678)
        XCTAssertEqual(right.direction, 1)
        XCTAssertFalse(right.crossedNotch)

        let left = MenuBarMovementResolver.advance(
            currentX: 742,
            direction: -1,
            speed: 40,
            delta: 0.1,
            bounds: 90...1_186,
            panelWidth: 24,
            notch: 700...740
        )
        XCTAssertEqual(left.x, 738)
        XCTAssertEqual(left.direction, -1)
        XCTAssertFalse(left.crossedNotch)
    }

    func testMenuBarNotchSkipRemainsExplicitlyConfigurable() {
        let step = MenuBarMovementResolver.advance(
            currentX: 674,
            direction: 1,
            speed: 40,
            delta: 0.1,
            bounds: 90...1_186,
            panelWidth: 24,
            notch: 700...740,
            skipNotch: true
        )
        XCTAssertEqual(step.x, 740)
        XCTAssertTrue(step.crossedNotch)
    }

    func testMenuBarMovementTurnsOnlyAtOuterBoundary() {
        let step = MenuBarMovementResolver.advance(
            currentX: 1_185,
            direction: 1,
            speed: 40,
            delta: 0.1,
            bounds: 90...1_186,
            panelWidth: 24
        )
        XCTAssertEqual(step.x, 1_186)
        XCTAssertEqual(step.direction, -1)
        XCTAssertTrue(step.reachedBoundary)
    }

    func testMenuBarAdvancesOnlyDuringMatchingLocomotion() {
        XCTAssertTrue(MenuBarMovementResolver.shouldAdvance(
            isPerformingBehavior: false,
            currentAnimationName: "running-right",
            locomotionAnimationName: "running-right"
        ))
        XCTAssertFalse(MenuBarMovementResolver.shouldAdvance(
            isPerformingBehavior: false,
            currentAnimationName: "idle",
            locomotionAnimationName: "running-right"
        ))
        XCTAssertFalse(MenuBarMovementResolver.shouldAdvance(
            isPerformingBehavior: false,
            currentAnimationName: "running-left",
            locomotionAnimationName: "running-right"
        ))
        XCTAssertFalse(MenuBarMovementResolver.shouldAdvance(
            isPerformingBehavior: true,
            currentAnimationName: "running-right",
            locomotionAnimationName: "running-right"
        ))
    }
}

import CryptoKit
