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
        let stagingRootURL = fileManager.temporaryDirectory
            .appendingPathComponent("manuscript-backup-stage-\(UUID().uuidString)", isDirectory: true)
        let stagedProjectURL = stagingRootURL.appendingPathComponent(projectURL.lastPathComponent, isDirectory: true)
        let tempZipURL = fileManager.temporaryDirectory
            .appendingPathComponent("manuscript-backup-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(backupName)
        try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        try fileManager.copyItem(at: projectURL, to: stagedProjectURL)
        let stagedBackupsURL = stagedProjectURL.appendingPathComponent("backups", isDirectory: true)
        if fileManager.fileExists(atPath: stagedBackupsURL.path) {
            try fileManager.removeItem(at: stagedBackupsURL)
        }
        try fileManager.createDirectory(at: stagedBackupsURL, withIntermediateDirectories: true)
        let stagedLockURL = stagedProjectURL.appendingPathComponent(".lock")
        if fileManager.fileExists(atPath: stagedLockURL.path) {
            try? fileManager.removeItem(at: stagedLockURL)
        }
        try fileManager.createDirectory(at: tempZipURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: stagingRootURL)
            try? fileManager.removeItem(at: tempZipURL.deletingLastPathComponent())
        }

        try zipDirectory(source: stagedProjectURL, destinationZip: tempZipURL)
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
            .filter { isManagedBackupFilename($0.lastPathComponent) }
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
        let backupsURL = projectURL.appendingPathComponent("backups", isDirectory: true)
        guard isManagedBackupFilename(backupFilename) else {
            throw ProjectIOError.backupNotFound(backupFilename)
        }

        let backupURL = backupsURL.appendingPathComponent(backupFilename)
        let standardizedBackupsPath = backupsURL.standardizedFileURL.path
        let standardizedBackupPath = backupURL.standardizedFileURL.path
        guard standardizedBackupPath.hasPrefix(standardizedBackupsPath + "/") else {
            throw ProjectIOError.backupNotFound(backupFilename)
        }

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw ProjectIOError.backupNotFound(backupFilename)
        }

        let candidate = destinationDir.appendingPathComponent(projectURL.lastPathComponent, isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: candidate.path) {
            try FileManager.default.removeItem(at: candidate)
        }
        try unzipArchive(sourceZip: backupURL, destinationDir: destinationDir)

        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw ProjectIOError.backupNotFound("Could not locate restored project root in backup")
        }
        do {
            let manifestURL = candidate.appendingPathComponent("manifest.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                throw ProjectIOError.backupNotFound("Restored backup is missing manifest.json")
            }
            do {
                _ = try ManifestCoder.read(from: manifestURL)
            } catch {
                throw ProjectIOError.backupNotFound("Restored backup contains invalid manifest.json")
            }
        } catch {
            // Prevent leaving partial restore contents when validation fails.
            if FileManager.default.fileExists(atPath: candidate.path) {
                try? FileManager.default.removeItem(at: candidate)
            }
            throw error
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

    private static func isManagedBackupFilename(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let nsValue = NSString(string: value)
        guard nsValue.lastPathComponent == value else { return false }
        guard nsValue.pathExtension.lowercased() == "zip" else { return false }
        guard value.hasPrefix("backup-") else { return false }
        guard !value.contains("..") else { return false }
        return true
    }
}
