import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var presentation: PetPresentationCoordinator?
    private let settings: AppSettings
    var showSettings: (() -> Void)?
    var checkForUpdates: (() -> Void)?

    init(settings: AppSettings, presentation: PetPresentationCoordinator) {
        self.settings = settings
        self.presentation = presentation
        super.init()
        let image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Dingdang Pet")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Dingdang Pet"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleMenu)
        presentation.showContextMenu = { [weak self] _ in self?.showMenu() }
    }

    @objc private func toggleMenu() { showMenu() }

    func showMenu() {
        let menu = buildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Dingdang Pet")
        menu.delegate = self
        for mode in PetDisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = settings.displayMode == mode ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let petsMenu = NSMenu(title: "宠物选择")
        for pet in presentation?.catalogStore.catalog.pets ?? [] {
            let item = NSMenuItem(title: pet.displayName, action: #selector(selectPet(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pet.id
            item.state = settings.selectedPetID == pet.id ? .on : .off
            petsMenu.addItem(item)
        }
        let petsItem = NSMenuItem(title: "宠物选择", action: nil, keyEquivalent: "")
        petsItem.submenu = petsMenu
        menu.addItem(petsItem)

        let sizeMenu = NSMenu(title: "桌面大小")
        for value in [0.5, 0.75, 1.0, 1.5, 2.0] {
            let item = NSMenuItem(title: "\(Int(value * 100))%", action: #selector(selectScale(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(settings.scale - value) < 0.01 ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "桌面大小", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        sizeItem.isEnabled = settings.displayMode == .desktop
        menu.addItem(sizeItem)

        let rangeMenu = NSMenu(title: "菜单栏活动范围")
        for mode in MenuBarRangeMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectRange(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = settings.menuBarRangeMode == mode ? .on : .off
            rangeMenu.addItem(item)
        }
        let rangeItem = NSMenuItem(title: "菜单栏活动范围", action: nil, keyEquivalent: "")
        rangeItem.submenu = rangeMenu
        menu.addItem(rangeItem)
        menu.addItem(.separator())

        let update = NSMenuItem(title: "检查宠物更新…", action: #selector(checkUpdate), keyEquivalent: "")
        update.target = self
        menu.addItem(update)
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 Dingdang Pet", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = PetDisplayMode(rawValue: raw) { settings.displayMode = mode }
    }

    @objc private func selectPet(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { settings.selectedPetID = id }
    }

    @objc private func selectScale(_ sender: NSMenuItem) {
        if let scale = sender.representedObject as? Double { presentation?.setScale(scale) }
    }

    @objc private func selectRange(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let mode = MenuBarRangeMode(rawValue: raw) { settings.menuBarRangeMode = mode }
    }

    @objc private func checkUpdate() { checkForUpdates?() }
    @objc private func openSettings() { showSettings?() }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
