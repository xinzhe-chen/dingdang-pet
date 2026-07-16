import AppKit
import Combine
import DingdangPetCore
import Foundation
import ServiceManagement

enum PetDisplayMode: String, CaseIterable, Identifiable {
    case desktop
    case menuBar
    case hidden

    var id: String { rawValue }
    var title: String {
        switch self {
        case .desktop: return "显示在桌面"
        case .menuBar: return "在菜单栏漫步"
        case .hidden: return "隐藏宠物"
        }
    }
}

enum MenuBarRangeMode: String, CaseIterable, Identifiable {
    case safe
    case full

    var id: String { rawValue }
    var title: String { self == .safe ? "安全范围" : "整条菜单栏" }
}

@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var displayMode: PetDisplayMode { didSet { defaults.set(displayMode.rawValue, forKey: "displayMode") } }
    @Published var selectedPetID: String { didSet { defaults.set(selectedPetID, forKey: "selectedPetID") } }
    @Published var scale: Double { didSet { defaults.set(scale, forKey: "petScale") } }
    @Published var menuBarRangeMode: MenuBarRangeMode { didSet { defaults.set(menuBarRangeMode.rawValue, forKey: "menuBarRangeMode") } }
    @Published var alwaysOnTop: Bool { didSet { defaults.set(alwaysOnTop, forKey: "alwaysOnTop") } }
    @Published var showOnAllSpaces: Bool { didSet { defaults.set(showOnAllSpaces, forKey: "showOnAllSpaces") } }
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                defaults.set(!launchAtLogin, forKey: "launchAtLogin")
            }
        }
    }
    @Published var feedURLOverride: String { didSet { defaults.set(feedURLOverride, forKey: "feedURLOverride") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = PetDisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "desktop") ?? .desktop
        selectedPetID = defaults.string(forKey: "selectedPetID") ?? ""
        scale = defaults.object(forKey: "petScale") as? Double ?? 1
        menuBarRangeMode = MenuBarRangeMode(rawValue: defaults.string(forKey: "menuBarRangeMode") ?? "safe") ?? .safe
        alwaysOnTop = defaults.object(forKey: "alwaysOnTop") as? Bool ?? true
        showOnAllSpaces = defaults.object(forKey: "showOnAllSpaces") as? Bool ?? true
        launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        feedURLOverride = defaults.string(forKey: "feedURLOverride") ?? ""
    }

    func clampScale(for pet: PetDefinition) {
        scale = min(max(scale, pet.presentation.desktop.minimumScale), pet.presentation.desktop.maximumScale)
    }
}
