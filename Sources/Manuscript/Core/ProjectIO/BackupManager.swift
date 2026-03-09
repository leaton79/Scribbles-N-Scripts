import Foundation

struct BackupManager {
    private static let filenameFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func createBackup(projectURL: URL, retentionCount: Int) throws -> BackupInfo {
        let fileManager = FileManager.default
        let backupsURL = projectURL.appendingPathComponent("backups", isDirectory: true)
        try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)

        let timestamp = filenameFormatter.string(from: Date())
        let backupName = "backup-\(timestamp).zip"
        let backupURL = backupsURL.appendingPathComponent(backupName)
        let tempZipURL = fileManager.temporaryDirectory
            .appendingPathComponent("manuscript-backup-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(backupName)
        try fileManager.createDirectory(at: tempZipURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempZipURL.deletingLastPathComponent())
        }

        try zipDirectory(source: projectURL, destinationZip: tempZipURL)
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.moveItem(at: tempZipURL, to: backupURL)
        // Always keep the backup just created by this call.
        let effectiveRetention = max(1, retentionCount)
        try pruneBackups(projectURL: projectURL, retentionCount: effectiveRetention)

        let attrs = try fileManager.attributesOfItem(atPath: backupURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        return BackupInfo(filename: backupName, date: Date(), sizeBytes: size)
    }

    static func listBackups(projectURL: URL) -> [BackupInfo] {
        let backupsURL = projectURL.appendingPathComponent("backups", isDirectory: true)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { $0.pathExtension.lowercased() == "zip" }
            .compactMap { url in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                guard let date = values?.contentModificationDate else { return nil }
                return BackupInfo(
                    filename: url.lastPathComponent,
                    date: date,
                    sizeBytes: Int64(values?.fileSize ?? 0)
                )
            }
            .sorted { $0.date > $1.date }
    }

    static func restoreBackup(projectURL: URL, backupFilename: String, to destinationDir: URL) throws -> URL {
        let backupURL = projectURL
            .appendingPathComponent("backups", isDirectory: true)
            .appendingPathComponent(backupFilename)

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw ProjectIOError.backupNotFound(backupFilename)
        }

        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        try unzipArchive(sourceZip: backupURL, destinationDir: destinationDir)

        let candidate = destinationDir.appendingPathComponent(projectURL.lastPathComponent)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw ProjectIOError.backupNotFound("Could not locate restored project root in backup")
        }
        let restoredLockURL = candidate.appendingPathComponent(".lock")
        if FileManager.default.fileExists(atPath: restoredLockURL.path) {
            try? FileManager.default.removeItem(at: restoredLockURL)
        }
        return candidate
    }

    static func pruneBackups(projectURL: URL, retentionCount: Int) throws {
        guard retentionCount >= 0 else { return }
        let backupsURL = projectURL.appendingPathComponent("backups", isDirectory: true)
        let backups = listBackups(projectURL: projectURL)
        guard backups.count > retentionCount else { return }

        for backup in backups.dropFirst(retentionCount) {
            try? FileManager.default.removeItem(at: backupsURL.appendingPathComponent(backup.filename))
        }
    }

    private static func zipDirectory(source: URL, destinationZip: URL) throws {
        if FileManager.default.fileExists(atPath: destinationZip.path) {
            try FileManager.default.removeItem(at: destinationZip)
        }

        try runProcess(
            executable: "/usr/bin/ditto",
            arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destinationZip.path]
        )
    }

    private static func unzipArchive(sourceZip: URL, destinationDir: URL) throws {
        try runProcess(
            executable: "/usr/bin/ditto",
            arguments: ["-x", "-k", sourceZip.path, destinationDir.path]
        )
    }

    private static func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Backup process failed"
            throw ProjectIOError.invalidHierarchy(details: msg)
        }
    }
}
