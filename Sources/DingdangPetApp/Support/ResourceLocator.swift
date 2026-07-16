import Foundation

enum ResourceLocator {
    static var rootURL: URL {
        if let bundleResources = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: bundleResources.appendingPathComponent("AppConfig.json").path) {
            return bundleResources
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
    }
}
