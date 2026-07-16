import Foundation

public enum ArchiveEntryValidationError: LocalizedError, Equatable {
    case invalidEntry(String)
    case invalidEntryCount(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidEntry(let entry): return "Unsafe archive entry: \(entry)"
        case .invalidEntryCount(let count): return "Invalid archive entry count: \(count)"
        }
    }
}

public enum ArchiveEntryValidator {
    public static func validate(_ entries: [String], maximumFiles: Int = PetSafetyLimits.maximumFiles) throws {
        guard !entries.isEmpty, entries.count <= maximumFiles else {
            throw ArchiveEntryValidationError.invalidEntryCount(entries.count)
        }
        for rawEntry in entries {
            let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = entry.split(separator: "/", omittingEmptySubsequences: false)
            guard !entry.isEmpty,
                  !entry.hasPrefix("/"),
                  !entry.hasPrefix("~"),
                  !entry.contains("\\"),
                  !entry.contains("\0"),
                  !components.contains(where: { $0 == "." || $0 == ".." }) else {
                throw ArchiveEntryValidationError.invalidEntry(entry)
            }
        }
    }
}
