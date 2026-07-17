import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: AppSettings, catalogStore: CatalogStore, updater: PetResourceUpdater) {
        let root = SettingsView(settings: settings, catalogStore: catalogStore, updater: updater)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Dingdang Pet 设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var catalogStore: CatalogStore
    @ObservedObject var updater: PetResourceUpdater

    var body: some View {
        Form {
            Section("宠物") {
                Picker("当前宠物", selection: $settings.selectedPetID) {
                    ForEach(catalogStore.catalog.pets) { pet in Text(pet.displayName).tag(pet.id) }
                }
                Picker("显示位置", selection: $settings.displayMode) {
                    ForEach(PetDisplayMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                HStack {
                    Text("桌面大小")
                    Slider(value: $settings.scale, in: 0.4...3, step: 0.05)
                    Text("\(Int(settings.scale * 100))%").monospacedDigit().frame(width: 54, alignment: .trailing)
                }
                .disabled(settings.displayMode != .desktop)
                Toggle("桌面宠物始终置顶", isOn: $settings.alwaysOnTop)
                Toggle("在所有桌面空间显示", isOn: $settings.showOnAllSpaces)
                Toggle("登录时自动启动", isOn: $settings.launchAtLogin)
            }
            Section("菜单栏") {
                Picker("活动范围", selection: $settings.menuBarRangeMode) {
                    ForEach(MenuBarRangeMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                Text("整条菜单栏模式可能短暂覆盖当前应用菜单或系统状态图标。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("GitHub 宠物资源") {
                TextField("Latest Release API URL", text: $settings.feedURLOverride)
                    .textFieldStyle(.roundedBorder)
                Text(updater.state.text).font(.caption).foregroundStyle(.secondary)
                Button("立即检查宠物更新") { Task { await updater.checkForUpdates() } }
                Button("恢复内置宠物") { catalogStore.restoreBundledCatalog() }
            }
            Section("关于") {
                Text("Dingdang Pet Runtime 1 · 资源协议 1")
                Text("App 代码固定；外观、动画、交互和移动参数由签名的 GitHub Release 提供。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 500)
    }
}
