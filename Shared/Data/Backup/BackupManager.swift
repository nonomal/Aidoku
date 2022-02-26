//
//  BackupManager.swift
//  Aidoku
//
//  Created by Skitty on 2/26/22.
//

import Foundation

class BackupManager {

    static let shared = BackupManager()

    static let directory = FileManager.default.documentDirectory.appendingPathComponent("Backups", isDirectory: true)

    static var backupUrls: [URL] {
        Self.directory.contentsByDateAdded
    }

    static var backups: [Backup] {
        Self.backupUrls.compactMap { Backup.load(from: $0) }
    }

    func saveNewBackup() {
        Self.directory.createDirctory()

        let backup = createBackup()
        if let json = try? JSONEncoder().encode(backup) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let path = Self.directory.appendingPathComponent("aidoku_\(dateFormatter.string(from: Date())).json")
            try? json.write(to: path)
            NotificationCenter.default.post(name: Notification.Name("updateBackupList"), object: nil)
        }
    }

    func importBackup(from url: URL) {
        Self.directory.createDirctory()
        try? FileManager.default.moveItem(at: url, to: Self.directory.appendingPathComponent(url.lastPathComponent))
        NotificationCenter.default.post(name: Notification.Name("updateBackupList"), object: nil)
    }

    func createBackup() -> Backup {
        let library = (try? DataManager.shared.getLibraryObjects())?.map {
            BackupLibraryManga(libraryObject: $0)
        } ?? []
        let history = (try? DataManager.shared.getReadHistory())?.map {
            BackupHistory(historyObject: $0)
        } ?? []
        let manga = (try? DataManager.shared.getMangaObjects())?.map {
            BackupManga(mangaObject: $0)
        } ?? []
        let chapters = (try? DataManager.shared.getChapterObjects())?.map {
            BackupChapter(chapterObject: $0)
        } ?? []

        return Backup(
            library: library,
            history: history,
            manga: manga,
            chapters: chapters,
            date: Date(),
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
    }

    func removeBackup(url: URL) {
        try? FileManager.default.removeItem(at: url)
        NotificationCenter.default.post(name: Notification.Name("updateBackupList"), object: nil)
    }

    func restore(from backup: Backup) {
        // this should probably do some more checks before running, idk

        if !backup.history.isEmpty {
            DataManager.shared.clearHistory()
            backup.history.forEach {
                _ = $0.toObject(context: DataManager.shared.container.viewContext)
            }
        }

        if !backup.manga.isEmpty {
            DataManager.shared.clearManga()
            backup.manga.forEach {
                _ = $0.toObject(context: DataManager.shared.container.viewContext)
            }
        }

        if !backup.library.isEmpty {
            DataManager.shared.clearLibrary()
            backup.library.forEach {
                let libraryObject = $0.toObject(context: DataManager.shared.container.viewContext)
                if let manga = DataManager.shared.getMangaObject(withId: $0.mangaId, sourceId: $0.sourceId) {
                    libraryObject.manga = manga
                }
            }
        }

        if !backup.chapters.isEmpty {
            DataManager.shared.clearChapters()
            backup.chapters.forEach {
                let chapter = $0.toObject(context: DataManager.shared.container.viewContext)
                chapter.manga = DataManager.shared.getMangaObject(withId: $0.mangaId, sourceId: $0.sourceId)
            }
        }

        _ = DataManager.shared.save()

        DataManager.shared.loadLibrary()
    }
}