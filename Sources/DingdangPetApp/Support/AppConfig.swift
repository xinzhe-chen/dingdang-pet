import Foundation

struct AppConfig: Codable {
    var githubLatestReleaseURL: URL?
    var contentPublicKeyBase64: String
    var allowUnsignedDevelopmentFeeds: Bool

    static func load() -> AppConfig {
        let url = ResourceLocator.rootURL.appendingPathComponent("AppConfig.json")
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig(githubLatestReleaseURL: nil, contentPublicKeyBase64: "", allowUnsignedDevelopmentFeeds: false)
        }
        return config
    }
}
