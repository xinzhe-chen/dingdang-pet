import AppKit
import Combine
import DingdangPetCore
import Foundation

@MainActor
final class PetResourceUpdater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case downloading(String)
        case installed(String)
        case current
        case notConfigured
        case failed(String)

        var text: String {
            switch self {
            case .idle: return "尚未检查"
            case .checking: return "正在检查 GitHub Release…"
            case .downloading(let version): return "正在下载宠物资源 \(version)…"
            case .installed(let version): return "已安装宠物资源 \(version)"
            case .current: return "宠物资源已是最新版本"
            case .notConfigured: return "尚未配置 GitHub Release 地址或内容公钥"
            case .failed(let message): return "更新失败：\(message)"
            }
        }
    }

    @Published private(set) var state: State = .idle

    private let config: AppConfig
    private let settings: AppSettings
    private let catalogStore: CatalogStore
    private let session: URLSession
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    init(config: AppConfig, settings: AppSettings, catalogStore: CatalogStore, session: URLSession = .shared) {
        self.config = config
        self.settings = settings
        self.catalogStore = catalogStore
        self.session = session
    }

    func checkOnLaunch() {
        Task { await checkForUpdates(userInitiated: false) }
    }

    func checkForUpdates(userInitiated: Bool = true) async {
        guard state != .checking else { return }
        guard let feedURL = resolvedFeedURL else {
            state = .notConfigured
            return
        }
        if config.contentPublicKeyBase64.isEmpty && !config.allowUnsignedDevelopmentFeeds {
            state = .notConfigured
            return
        }

        state = .checking
        do {
            var request = URLRequest(url: feedURL)
            request.timeoutInterval = 15
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("DingdangPet/1", forHTTPHeaderField: "User-Agent")
            if let etag = defaults.string(forKey: "releaseETag") { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw UpdateError.invalidResponse }
            if http.statusCode == 304 {
                state = .current
                return
            }
            guard (200..<300).contains(http.statusCode) else { throw UpdateError.http(http.statusCode) }
            if let etag = http.value(forHTTPHeaderField: "ETag") { defaults.set(etag, forKey: "releaseETag") }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard !release.draft, !release.prerelease else { throw UpdateError.invalidRelease }
            if defaults.integer(forKey: "installedReleaseID") == release.id {
                state = .current
                return
            }
            try await install(release: release)
            defaults.set(release.id, forKey: "installedReleaseID")
        } catch {
            state = .failed(error.localizedDescription)
            if userInitiated { NSSound.beep() }
        }
    }

    private var resolvedFeedURL: URL? {
        if !settings.feedURLOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(string: settings.feedURLOverride)
        }
        return config.githubLatestReleaseURL
    }

    private func install(release: GitHubRelease) async throws {
        guard let manifestAsset = release.assets.first(where: { $0.name == "manifest.json" }),
              let signatureAsset = release.assets.first(where: { $0.name == "manifest.sig" }),
              let archiveAsset = release.assets.first(where: { $0.name.hasPrefix("pet-catalog-") && $0.name.hasSuffix(".zip") }) else {
            throw UpdateError.missingAssets
        }
        let manifestData = try await fetch(manifestAsset.browserDownloadURL, maximumBytes: 1_000_000)
        let signatureData = try await fetch(signatureAsset.browserDownloadURL, maximumBytes: 16_384)
        let signature = String(decoding: signatureData, as: UTF8.self)
        if !config.contentPublicKeyBase64.isEmpty {
            guard ContentSignature.verify(manifestData: manifestData, signatureBase64: signature, publicKeyBase64: config.contentPublicKeyBase64) else {
                throw UpdateError.invalidSignature
            }
        } else if !config.allowUnsignedDevelopmentFeeds {
            throw UpdateError.invalidSignature
        }

        let manifest = try JSONDecoder().decode(CatalogReleaseManifest.self, from: manifestData)
        guard manifest.schemaVersion == 1 else { throw UpdateError.unsupportedSchema }
        guard manifest.archive.size > 0, manifest.archive.size <= PetSafetyLimits.maximumCatalogBytes else { throw UpdateError.archiveTooLarge }
        state = .downloading(manifest.catalogVersion)
        let archiveData = try await fetch(archiveAsset.browserDownloadURL, maximumBytes: PetSafetyLimits.maximumCatalogBytes)
        guard archiveData.count == manifest.archive.size else { throw UpdateError.sizeMismatch }
        guard ContentSignature.sha256Hex(archiveData) == manifest.archive.sha256.lowercased() else { throw UpdateError.hashMismatch }

        try fileManager.createDirectory(at: catalogStore.releasesURL, withIntermediateDirectories: true)
        let tempRoot = catalogStore.releasesURL.appendingPathComponent(".incoming-\(UUID().uuidString)", isDirectory: true)
        let zipURL = tempRoot.appendingPathExtension("zip")
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try archiveData.write(to: zipURL, options: .atomic)
        defer { try? fileManager.removeItem(at: zipURL) }
        try validateArchiveListing(zipURL)
        try extract(zipURL: zipURL, to: tempRoot)
        try validateExtractedTree(tempRoot)

        let finalName = "\(manifest.catalogVersion)-\(release.id)"
        let finalRoot = catalogStore.releasesURL.appendingPathComponent(finalName, isDirectory: true)
        if fileManager.fileExists(atPath: finalRoot.path) { try fileManager.removeItem(at: finalRoot) }
        try fileManager.moveItem(at: tempRoot, to: finalRoot)
        do {
            try catalogStore.activate(releaseDirectory: finalRoot)
        } catch {
            try? fileManager.removeItem(at: finalRoot)
            throw error
        }
        state = .installed(manifest.catalogVersion)
    }

    private func fetch(_ url: URL, maximumBytes: Int) async throws -> Data {
        guard url.scheme == "https" else { throw UpdateError.insecureURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("DingdangPet/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw UpdateError.invalidResponse }
        guard data.count <= maximumBytes else { throw UpdateError.archiveTooLarge }
        return data
    }

    private func extract(zipURL: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", "--noqtn", zipURL.path, destination.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw UpdateError.extractionFailed(message)
        }
    }

    private func validateArchiveListing(_ zipURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", zipURL.path]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw UpdateError.extractionFailed(message)
        }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard data.count <= 2_000_000, let listing = String(data: data, encoding: .utf8) else {
            throw UpdateError.invalidArchive
        }
        let entries = listing.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        do { try ArchiveEntryValidator.validate(entries) }
        catch { throw UpdateError.invalidArchive }
    }

    private func validateExtractedTree(_ root: URL) throws {
        guard fileManager.fileExists(atPath: root.appendingPathComponent("catalog.json").path) else { throw UpdateError.missingCatalog }
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
            throw UpdateError.invalidArchive
        }
        var totalSize = 0
        let allowedExtensions = Set(["json", "png", "webp", "jpg", "jpeg", "m4a", "wav", "aiff"])
        for case let url as URL in enumerator {
            let standardized = url.standardizedFileURL.path
            guard standardized.hasPrefix(root.standardizedFileURL.path + "/") else { throw UpdateError.invalidArchive }
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            if values.isSymbolicLink == true { throw UpdateError.invalidArchive }
            if values.isRegularFile == true {
                guard allowedExtensions.contains(url.pathExtension.lowercased()) else { throw UpdateError.disallowedFile(url.lastPathComponent) }
                totalSize += values.fileSize ?? 0
                if totalSize > PetSafetyLimits.maximumCatalogBytes { throw UpdateError.archiveTooLarge }
            }
        }
    }
}

private enum UpdateError: LocalizedError {
    case invalidResponse, invalidRelease, missingAssets, invalidSignature, unsupportedSchema
    case archiveTooLarge, sizeMismatch, hashMismatch, insecureURL, missingCatalog, invalidArchive
    case disallowedFile(String), extractionFailed(String), http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "服务器响应无效"
        case .invalidRelease: return "Release 尚未正式发布"
        case .missingAssets: return "Release 缺少 manifest、签名或宠物 ZIP"
        case .invalidSignature: return "宠物资源签名无效"
        case .unsupportedSchema: return "资源协议版本不受支持"
        case .archiveTooLarge: return "宠物资源包超过安全上限"
        case .sizeMismatch: return "资源包大小与 manifest 不一致"
        case .hashMismatch: return "资源包 SHA-256 校验失败"
        case .insecureURL: return "资源下载必须使用 HTTPS"
        case .missingCatalog: return "资源包缺少 catalog.json"
        case .invalidArchive: return "资源包目录结构不安全"
        case .disallowedFile(let name): return "资源包包含不允许的文件：\(name)"
        case .extractionFailed(let message): return "解压失败：\(message)"
        case .http(let status): return "GitHub 返回 HTTP \(status)"
        }
    }
}
