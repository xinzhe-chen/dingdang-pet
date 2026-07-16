import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings!
    private var catalogStore: CatalogStore!
    private var presentation: PetPresentationCoordinator!
    private var updater: PetResourceUpdater!
    private var statusItemController: StatusItemController!
    private var settingsWindowController: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settings = AppSettings()
        catalogStore = CatalogStore()
        presentation = PetPresentationCoordinator(settings: settings, catalogStore: catalogStore)
        updater = PetResourceUpdater(config: AppConfig.load(), settings: settings, catalogStore: catalogStore)
        settingsWindowController = SettingsWindowController(settings: settings, catalogStore: catalogStore, updater: updater)
        statusItemController = StatusItemController(settings: settings, presentation: presentation)
        statusItemController.showSettings = { [weak self] in self?.settingsWindowController.show() }
        statusItemController.checkForUpdates = { [weak self] in
            guard let self else { return }
            Task { await self.updater.checkForUpdates() }
        }
        updater.checkOnLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
