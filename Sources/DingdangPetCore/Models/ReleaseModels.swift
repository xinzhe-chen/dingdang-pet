import Foundation

public struct CatalogReleaseManifest: Codable, Sendable {
    public var schemaVersion: Int
    public var catalogVersion: String
    public var createdAt: String
    public var archive: ReleaseArchive

    public init(schemaVersion: Int, catalogVersion: String, createdAt: String, archive: ReleaseArchive) {
        self.schemaVersion = schemaVersion
        self.catalogVersion = catalogVersion
        self.createdAt = createdAt
        self.archive = archive
    }
}

public struct ReleaseArchive: Codable, Sendable {
    public var url: String
    public var sha256: String
    public var size: Int

    public init(url: String, sha256: String, size: Int) {
        self.url = url
        self.sha256 = sha256
        self.size = size
    }
}

public struct GitHubRelease: Codable, Sendable {
    public struct Asset: Codable, Sendable {
        public var name: String
        public var browserDownloadURL: URL
        public var size: Int
        public var digest: String?

        enum CodingKeys: String, CodingKey {
            case name, size, digest
            case browserDownloadURL = "browser_download_url"
        }
    }

    public var id: Int
    public var tagName: String
    public var prerelease: Bool
    public var draft: Bool
    public var assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case id, prerelease, draft, assets
        case tagName = "tag_name"
    }
}
