import DingdangPetCore
import Foundation

@MainActor
final class CatalogStore: ObservableObject {
    @Published private(set) var catalog: PetCatalog
    @Published private(set) var rootURL: URL
    @Published private(set) var lastError: String?

    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()

    init() {
        let bundledRoot = ResourceLocator.rootURL.appendingPathComponent("DefaultCatalog", isDirectory: true)
        let bundledCatalog = bundledRoot.appendingPathComponent("catalog.json")
        let localDecoder = JSONDecoder()
        let decoded = (try? Data(contentsOf: bundledCatalog)).flatMap { try? localDecoder.decode(PetCatalog.self, from: $0) }
        self.catalog = decoded ?? PetCatalog(schemaVersion: 1, catalogVersion: "0.0.0", defaultPetID: "", pets: [])
        self.rootURL = bundledRoot
        loadActiveCatalog(fallbackRoot: bundledRoot)
    }

    var applicationSupportURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("DingdangPet", isDirectory: true)
    }

    var releasesURL: URL { applicationSupportURL.appendingPathComponent("releases", isDirectory: true) }

    var activePointerURL: URL { applicationSupportURL.appendingPathComponent("active-release.txt") }

    func pet(id: String?) -> PetDefinition? {
        if let id, let match = catalog.pets.first(where: { $0.id == id }) { return match }
        return catalog.pets.first(where: { $0.id == catalog.defaultPetID }) ?? catalog.pets.first
    }

    func activate(releaseDirectory: URL) throws {
        let catalogURL = releaseDirectory.appendingPathComponent("catalog.json")
        let data = try Data(contentsOf: catalogURL)
        let candidate = try decoder.decode(PetCatalog.self, from: data)
        let report = PetValidator.validate(catalog: candidate, rootURL: releaseDirectory)
        guard report.isValid else {
            throw NSError(domain: "DingdangPet.Catalog", code: 1, userInfo: [NSLocalizedDescriptionKey: report.issues.map(\.message).joined(separator: "; ")])
        }
        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        try releaseDirectory.lastPathComponent.write(to: activePointerURL, atomically: true, encoding: .utf8)
        catalog = candidate
        rootURL = releaseDirectory
        lastError = nil
        pruneOldReleases(keeping: 2)
    }

    func restoreBundledCatalog() {
        let bundledRoot = ResourceLocator.rootURL.appendingPathComponent("DefaultCatalog", isDirectory: true)
        loadCatalog(at: bundledRoot)
    }

    private func loadActiveCatalog(fallbackRoot: URL) {
        guard let name = try? String(contentsOf: activePointerURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            loadCatalog(at: fallbackRoot)
            return
        }
        let activeRoot = releasesURL.appendingPathComponent(name, isDirectory: true)
        if !loadCatalog(at: activeRoot) { loadCatalog(at: fallbackRoot) }
    }

    @discardableResult
    private func loadCatalog(at root: URL) -> Bool {
        do {
            let data = try Data(contentsOf: root.appendingPathComponent("catalog.json"))
            let decoded = try decoder.decode(PetCatalog.self, from: data)
            let report = PetValidator.validate(catalog: decoded, rootURL: root)
            guard report.isValid else { throw NSError(domain: "DingdangPet.Catalog", code: 2, userInfo: [NSLocalizedDescriptionKey: report.issues.map(\.message).joined(separator: "; ")]) }
            catalog = decoded
            rootURL = root
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func pruneOldReleases(keeping count: Int) {
        guard let directories = try? fileManager.contentsOfDirectory(at: releasesURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        let sorted = directories.sorted {
            let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhs > rhs
        }
        for directory in sorted.dropFirst(count) { try? fileManager.removeItem(at: directory) }
    }
}
