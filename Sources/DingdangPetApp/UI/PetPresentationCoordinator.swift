import AppKit
import Combine
import DingdangPetCore
import SpriteKit

@MainActor
final class PetPresentationCoordinator {
    let settings: AppSettings
    let catalogStore: CatalogStore
    let petView: InteractivePetView
    let scene: PetScene
    let behaviorEngine: PetBehaviorEngine

    private let desktopPanel: NSPanel
    private let menuBarPanel: NSPanel
    private let rangePreviewPanel: NSPanel
    private let rangePreviewView: RainbowRangePreviewView
    private var cancellables: Set<AnyCancellable> = []
    private var movementTimer: Timer?
    private var pointerTimer: Timer?
    private var idleTimer: Timer?
    private var direction = 1
    private var previousMovementDate = Date()
    private var pauseUntil = Date.distantPast
    private var rangePreviewDismissal: DispatchWorkItem?
    private var lastPointerLocation: NSPoint?
    private var lastPointerMovementDate = Date()
    private(set) var currentPet: PetDefinition?
    var showContextMenu: ((NSEvent) -> Void)?

    init(settings: AppSettings, catalogStore: CatalogStore) {
        self.settings = settings
        self.catalogStore = catalogStore
        scene = PetScene(size: CGSize(width: 208, height: 208))
        petView = InteractivePetView(frame: NSRect(x: 0, y: 0, width: 208, height: 208))
        petView.allowsTransparency = true
        petView.presentScene(scene)
        behaviorEngine = PetBehaviorEngine(scene: scene)

        desktopPanel = Self.makePanel(level: .floating)
        menuBarPanel = Self.makePanel(level: .statusBar)
        rangePreviewPanel = Self.makePanel(level: .statusBar)
        rangePreviewView = RainbowRangePreviewView(frame: .zero)
        rangePreviewPanel.ignoresMouseEvents = true
        rangePreviewPanel.contentView = rangePreviewView

        wireInteractions()
        reloadPet()
        observeSettings()
        applyMode(settings.displayMode)
        startPointerTracking()
    }

    func reloadPet() {
        guard let pet = catalogStore.pet(id: settings.selectedPetID) else { return }
        do {
            try scene.load(pet: pet, rootURL: catalogStore.rootURL)
            currentPet = pet
            behaviorEngine.rootURL = catalogStore.rootURL
            if settings.selectedPetID != pet.id { settings.selectedPetID = pet.id }
            settings.clampScale(for: pet)
            resizeDesktopPanel()
            scheduleRandomIdle()
        } catch {
            NSSound.beep()
        }
    }

    func applyMode(_ mode: PetDisplayMode) {
        movementTimer?.invalidate()
        movementTimer = nil
        desktopPanel.orderOut(nil)
        menuBarPanel.orderOut(nil)
        rangePreviewPanel.orderOut(nil)

        switch mode {
        case .desktop:
            scene.setContentInset(2)
            lastPointerLocation = NSEvent.mouseLocation
            lastPointerMovementDate = Date()
            attachPetView(to: desktopPanel)
            petView.allowsWindowDragging = true
            resizeDesktopPanel()
            restoreDesktopPosition()
            desktopPanel.orderFrontRegardless()
            behaviorEngine.returnToIdle()
        case .menuBar:
            scene.setContentInset(0)
            attachPetView(to: menuBarPanel)
            petView.allowsWindowDragging = false
            configureMenuBarPanel(resetPosition: true)
            menuBarPanel.orderFrontRegardless()
            startMenuBarMovement()
        case .hidden:
            petView.removeFromSuperview()
        }
    }

    func setScale(_ value: Double) {
        guard let pet = currentPet else { return }
        settings.scale = min(max(value, pet.presentation.desktop.minimumScale), pet.presentation.desktop.maximumScale)
        if settings.displayMode == .desktop { resizeDesktopPanel() }
    }

    func cycleVisibility() {
        settings.displayMode = settings.displayMode == .hidden ? .desktop : .hidden
    }

    func saveDesktopPosition() {
        let origin = desktopPanel.frame.origin
        UserDefaults.standard.set([origin.x, origin.y], forKey: "desktopPosition")
    }

    private static func makePanel(level: NSWindow.Level) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 208, height: 208),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = level
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }

    private func wireInteractions() {
        petView.onHoverEnter = { [weak self] in self?.behaviorEngine.trigger("hoverEnter") }
        petView.onPrimaryClick = { [weak self] in self?.behaviorEngine.trigger("primaryClick") }
        petView.onSecondaryClick = { [weak self] in self?.behaviorEngine.trigger("secondaryClick") }
        petView.onLongPress = { [weak self] in self?.behaviorEngine.trigger("longPress") }
        petView.onContextMenu = { [weak self] event in self?.showContextMenu?(event) }
        petView.onScaleDelta = { [weak self] delta in
            guard let self, self.settings.displayMode == .desktop else { return }
            self.setScale(self.settings.scale + delta)
        }
        behaviorEngine.propertyHandler = { [weak self] property, value in
            guard let self else { return }
            switch (property, value) {
            case ("scale", .number(let scale)): self.setScale(scale)
            case ("displayMode", .string(let mode)):
                if let parsed = PetDisplayMode(rawValue: mode) { self.settings.displayMode = parsed }
            default: break
            }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: desktopPanel, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.saveDesktopPosition() }
        }
    }

    private func observeSettings() {
        settings.$displayMode.dropFirst().sink { [weak self] mode in self?.applyMode(mode) }.store(in: &cancellables)
        settings.$scale.dropFirst().sink { [weak self] _ in self?.resizeDesktopPanel() }.store(in: &cancellables)
        settings.$alwaysOnTop.dropFirst().sink { [weak self] enabled in
            self?.desktopPanel.level = enabled ? .floating : .normal
        }.store(in: &cancellables)
        settings.$showOnAllSpaces.dropFirst().sink { [weak self] enabled in
            self?.desktopPanel.collectionBehavior = enabled ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary] : [.fullScreenAuxiliary]
        }.store(in: &cancellables)
        settings.$menuBarRangeMode.dropFirst().sink { [weak self] mode in
            self?.configureMenuBarPanel(resetPosition: false, rangeMode: mode)
            self?.showMenuBarRangePreview(rangeMode: mode)
        }.store(in: &cancellables)
        settings.$selectedPetID.dropFirst().sink { [weak self] _ in self?.reloadPet() }.store(in: &cancellables)
        catalogStore.$catalog.dropFirst().sink { [weak self] _ in self?.reloadPet() }.store(in: &cancellables)
    }

    private func attachPetView(to panel: NSPanel) {
        petView.removeFromSuperview()
        panel.contentView = petView
        petView.frame = panel.contentLayoutRect
        petView.autoresizingMask = [.width, .height]
    }

    private func resizeDesktopPanel() {
        guard settings.displayMode == .desktop || currentPet != nil, let pet = currentPet else { return }
        let height = CGFloat(pet.presentation.desktop.height * settings.scale)
        let aspect: CGFloat = {
            guard let animation = pet.bindings["defaultIdle"].flatMap({ pet.animations[$0] }), let frame = animation.frames.first,
                  let resolved = try? FrameResolver.resolve(frame: frame, animation: animation, atlases: pet.atlases) else { return 1 }
            return CGFloat(resolved.rect.width) / CGFloat(max(1, resolved.rect.height))
        }()
        let newSize = NSSize(width: max(48, height * aspect), height: max(48, height))
        desktopPanel.setContentSize(newSize)
        petView.frame = NSRect(origin: .zero, size: newSize)
        scene.size = newSize
    }

    private func restoreDesktopPosition() {
        if let saved = UserDefaults.standard.array(forKey: "desktopPosition") as? [Double], saved.count == 2 {
            desktopPanel.setFrameOrigin(NSPoint(x: saved[0], y: saved[1]))
        } else if let screen = NSScreen.main {
            desktopPanel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - desktopPanel.frame.width - 40, y: screen.visibleFrame.minY + 40))
        }
        clampDesktopToVisibleScreen()
    }

    private func clampDesktopToVisibleScreen() {
        guard let screen = desktopPanel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var origin = desktopPanel.frame.origin
        origin.x = min(max(origin.x, visible.minX), visible.maxX - desktopPanel.frame.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - desktopPanel.frame.height)
        desktopPanel.setFrameOrigin(origin)
    }

    private func activeScreen() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
    }

    private func configureMenuBarPanel(resetPosition: Bool, rangeMode: MenuBarRangeMode? = nil) {
        guard settings.displayMode == .menuBar, let screen = activeScreen(), let pet = currentPet else { return }
        let geometry = menuBarGeometry(on: screen)
        let size = menuBarPanelSize(on: screen, for: pet)
        let bounds = horizontalBounds(on: screen, panelWidth: size.width, rangeMode: rangeMode)
        let x = resetPosition ? bounds.lowerBound : min(max(menuBarPanel.frame.minX, bounds.lowerBound), bounds.upperBound)
        menuBarPanel.setFrame(NSRect(x: x, y: geometry.bottom, width: size.width, height: size.height), display: true)
        petView.frame = NSRect(origin: .zero, size: menuBarPanel.frame.size)
        scene.size = menuBarPanel.frame.size
        if resetPosition {
            direction = 1
        }
    }

    private func menuBarPanelSize(on screen: NSScreen, for pet: PetDefinition) -> CGSize {
        let geometry = menuBarGeometry(on: screen)
        let requestedHeight = max(14, CGFloat(pet.presentation.menuBar.height))
        let height = (pet.presentation.menuBar.fillsAvailableHeight ?? true) ? geometry.height : min(requestedHeight, geometry.height)
        return CGSize(width: max(1, height * menuBarAspectRatio(for: pet)), height: height)
    }

    private func menuBarGeometry(on screen: NSScreen) -> (bottom: CGFloat, height: CGFloat) {
        let geometry = MenuBarMovementResolver.verticalGeometry(
            screenMaxY: Double(screen.frame.maxY),
            visibleFrameMaxY: Double(screen.visibleFrame.maxY),
            systemThickness: Double(NSStatusBar.system.thickness)
        )
        return (CGFloat(geometry.bottom), CGFloat(geometry.height))
    }

    private func menuBarAspectRatio(for pet: PetDefinition) -> CGFloat {
        guard let idleName = pet.bindings["defaultIdle"], let idle = pet.animations[idleName], let frame = idle.frames.first,
              let resolved = try? FrameResolver.resolve(frame: frame, animation: idle, atlases: pet.atlases), resolved.rect.height > 0 else {
            return 1
        }
        return CGFloat(resolved.rect.width) / CGFloat(resolved.rect.height)
    }

    private func horizontalBounds(
        on screen: NSScreen,
        panelWidth: CGFloat? = nil,
        rangeMode: MenuBarRangeMode? = nil
    ) -> ClosedRange<CGFloat> {
        guard let pet = currentPet else { return screen.frame.minX...(screen.frame.maxX - (panelWidth ?? menuBarPanel.frame.width)) }
        let profile = pet.presentation.menuBar
        let resolvedMode = rangeMode ?? settings.menuBarRangeMode
        let left = resolvedMode == .safe ? CGFloat(profile.safeMarginLeft) : 0
        let right = resolvedMode == .safe ? CGFloat(profile.safeMarginRight) : 0
        let resolvedPanelWidth = panelWidth ?? menuBarPanel.frame.width
        let bounds = MenuBarMovementResolver.bounds(
            screenMinX: Double(screen.frame.minX),
            screenMaxX: Double(screen.frame.maxX),
            panelWidth: Double(resolvedPanelWidth),
            leftMargin: Double(left),
            rightMargin: Double(right)
        )
        return CGFloat(bounds.lowerBound)...CGFloat(bounds.upperBound)
    }

    private func showMenuBarRangePreview(rangeMode: MenuBarRangeMode? = nil) {
        guard let screen = activeScreen(), let pet = currentPet else { return }
        let geometry = menuBarGeometry(on: screen)
        let petSize = menuBarPanelSize(on: screen, for: pet)
        let bounds = horizontalBounds(on: screen, panelWidth: petSize.width, rangeMode: rangeMode)
        let width = max(1, bounds.upperBound - bounds.lowerBound + petSize.width)
        rangePreviewPanel.setFrame(
            NSRect(x: bounds.lowerBound, y: geometry.bottom, width: width, height: geometry.height),
            display: true
        )
        rangePreviewView.frame = rangePreviewPanel.contentLayoutRect
        rangePreviewPanel.orderFrontRegardless()
        rangePreviewView.play()

        rangePreviewDismissal?.cancel()
        let dismissal = DispatchWorkItem { [weak self] in self?.rangePreviewPanel.orderOut(nil) }
        rangePreviewDismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: dismissal)
    }

    private func startMenuBarMovement() {
        previousMovementDate = Date()
        pauseUntil = Date.distantPast
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advanceMenuBarPet() }
        }
        behaviorEngine.playLocomotion(direction: direction)
    }

    private func advanceMenuBarPet() {
        guard settings.displayMode == .menuBar, let pet = currentPet, let screen = menuBarPanel.screen ?? activeScreen() else { return }
        let now = Date()
        let delta = min(now.timeIntervalSince(previousMovementDate), 0.1)
        previousMovementDate = now
        guard now >= pauseUntil else { return }

        let locomotionName = direction >= 0 ? pet.bindings["moveRight"] : pet.bindings["moveLeft"]
        guard MenuBarMovementResolver.shouldAdvance(
            isPerformingBehavior: behaviorEngine.isPerformingBehavior,
            currentAnimationName: scene.currentAnimationName,
            locomotionAnimationName: locomotionName
        ) else {
            guard !behaviorEngine.isPerformingBehavior else { return }
            behaviorEngine.playLocomotion(direction: direction)
            return
        }

        let bounds = horizontalBounds(on: screen)
        let notch: ClosedRange<Double>? = {
            guard let leftArea = screen.auxiliaryTopLeftArea, let rightArea = screen.auxiliaryTopRightArea,
                  !leftArea.isEmpty, !rightArea.isEmpty, rightArea.minX > leftArea.maxX else { return nil }
            return Double(leftArea.maxX)...Double(rightArea.minX)
        }()
        let step = MenuBarMovementResolver.advance(
            currentX: Double(menuBarPanel.frame.minX),
            direction: direction,
            speed: pet.presentation.menuBar.speed,
            delta: delta,
            bounds: Double(bounds.lowerBound)...Double(bounds.upperBound),
            panelWidth: Double(menuBarPanel.frame.width),
            notch: notch,
            skipNotch: pet.presentation.menuBar.notchTraversal == .skip
        )
        let nextX = CGFloat(step.x)

        if step.direction != direction {
            direction = step.direction
            behaviorEngine.playLocomotion(direction: direction)
            if let pause = pet.presentation.menuBar.pauseInterval, Double.random(in: 0..<1) < 0.35 {
                pauseUntil = now.addingTimeInterval(Double.random(in: pause.min...max(pause.min, pause.max)))
                behaviorEngine.returnToIdle()
            }
        }
        menuBarPanel.setFrameOrigin(NSPoint(x: nextX, y: menuBarGeometry(on: screen).bottom))
        behaviorEngine.updateContext("distanceToLeftEdge", value: .number(Double(nextX - bounds.lowerBound)))
        behaviorEngine.updateContext("distanceToRightEdge", value: .number(Double(bounds.upperBound - nextX)))
    }

    private func startPointerTracking() {
        pointerTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updatePointerLook() }
        }
    }

    private func updatePointerLook() {
        guard settings.displayMode == .desktop, let window = petView.window, let currentPet else { return }
        let idleName = currentPet.bindings["defaultIdle"]
        let lookNames = Set(currentPet.directionalLook?.angles.map(\.animation) ?? [])
        let pointer = NSEvent.mouseLocation
        let now = Date()
        if let previous = lastPointerLocation {
            let movement = hypot(pointer.x - previous.x, pointer.y - previous.y)
            if PointerActivityResolver.didMove(distance: movement) { lastPointerMovementDate = now }
        } else {
            lastPointerMovementDate = now
        }
        lastPointerLocation = pointer

        let timeout = currentPet.directionalLook?.movementTimeout ?? 2.5
        guard PointerActivityResolver.shouldTrack(
            secondsSinceLastMovement: now.timeIntervalSince(lastPointerMovementDate),
            timeout: timeout
        ) else {
            if scene.currentAnimationName.map(lookNames.contains) == true { behaviorEngine.returnToIdle() }
            return
        }
        guard scene.currentAnimationName == idleName || scene.currentAnimationName.map(lookNames.contains) == true else { return }
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let dx = pointer.x - center.x
        let dy = pointer.y - center.y
        let distance = hypot(dx, dy)
        let degrees = 90 - atan2(dy, dx) * 180 / .pi
        behaviorEngine.playLook(angleDegrees: degrees, distance: distance)
    }

    private func scheduleRandomIdle() {
        idleTimer?.invalidate()
        guard let interval = currentPet?.presentation.randomIdleInterval else { return }
        let delay = Double.random(in: interval.min...max(interval.min, interval.max))
        idleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.behaviorEngine.trigger("randomIdle")
                self?.scheduleRandomIdle()
            }
        }
    }
}
