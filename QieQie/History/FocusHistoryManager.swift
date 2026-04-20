import Foundation
import OSLog
import SwiftData

struct FocusHistorySnapshot {
    let statistics: FocusStatistics
    let insights: FocusHistoryInsights
}

@MainActor
final class FocusHistoryManager: ObservableObject {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    private let logger = Logger(subsystem: "com.zhangzefu.qieqie", category: "FocusHistory")

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func recordCompletedFocus(
        duration: TimeInterval,
        taskName: String = FocusTagCatalog.defaultSessionTitle,
        completedAt: Date = Date()
    ) {
        recordCompletedFocus(
            duration: duration,
            tagName: nil,
            note: taskName,
            completedAt: completedAt
        )
    }

    func recordCompletedFocus(
        duration: TimeInterval,
        tagName: String?,
        note: String,
        completedAt: Date = Date()
    ) {
        let clampedDuration = max(0, duration)
        let normalizedNote = normalizedNote(note)
        let normalizedTagName = FocusTagCatalog.normalizeTagName(tagName)
        let session = FocusSession(
            taskName: storedTaskName(note: normalizedNote, tagName: normalizedTagName),
            tagName: normalizedTagName,
            note: normalizedNote.isEmpty ? nil : normalizedNote,
            startTime: completedAt.addingTimeInterval(-clampedDuration),
            endTime: completedAt,
            duration: clampedDuration,
            isCompleted: true
        )
        modelContext.insert(session)
        if let normalizedTagName {
            _ = upsertTagsIfNeeded(named: [normalizedTagName])
        }
        _ = saveContext("Failed to record focus session")
    }

    func clearAllSessions() -> Bool {
        let sessions = getAllSessions()
        sessions.forEach(modelContext.delete)

        do {
            try modelContext.save()
            return true
        } catch {
            logger.error("Failed to clear sessions: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func getDashboardStatistics() -> FocusStatistics {
        FocusHistoryAnalytics.aggregateStatistics(from: getAllSessions())
    }

    func getHistorySnapshot() -> FocusHistorySnapshot {
        let sessions = getAllSessions()
        return FocusHistorySnapshot(
            statistics: FocusHistoryAnalytics.aggregateStatistics(from: sessions),
            insights: FocusHistoryAnalytics.buildInsights(from: sessions)
        )
    }

    func getStatisticsPageSnapshot(query: FocusStatisticsQuery) -> FocusStatisticsPageSnapshot {
        FocusHistoryAnalytics.pageSnapshot(from: getAllSessions(), query: query)
    }

    func getAllSessions() -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch sessions: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func getAvailableTags() -> [String] {
        let descriptor = FetchDescriptor<FocusTagRecord>(
            sortBy: [
                SortDescriptor(\.createdAt, order: .forward),
                SortDescriptor(\.name, order: .forward)
            ]
        )

        do {
            let records = try modelContext.fetch(descriptor)
            var orderedNames: [String] = []
            var seen = Set<String>()
            var needsSave = false

            for record in records {
                guard let normalizedName = FocusTagCatalog.normalizeTagName(record.name) else {
                    modelContext.delete(record)
                    needsSave = true
                    continue
                }

                if record.name != normalizedName {
                    record.name = normalizedName
                    needsSave = true
                }

                if seen.insert(normalizedName).inserted {
                    orderedNames.append(normalizedName)
                } else {
                    modelContext.delete(record)
                    needsSave = true
                }
            }

            if needsSave {
                _ = saveContext("Failed to normalize stored tags")
            }

            return orderedNames
        } catch {
            logger.error("Failed to fetch tags: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func migrateStorage(using userDefaults: UserDefaults) {
        let sessions = getAllSessions()
        var needsSave = false

        for session in sessions where normalizeSessionForCurrentSchema(session) {
            needsSave = true
        }

        let tagNames = FocusTagCatalog.normalizedTags(
            from: FocusTimerStorage.loadLegacyAvailableTags(from: userDefaults)
                + sessions.compactMap(\.normalizedTagName)
                + (FocusTimerStorage.loadSelectedTagName(from: userDefaults).map { [$0] } ?? [])
        )
        if upsertTagsIfNeeded(named: tagNames) {
            needsSave = true
        }

        if !FocusTimerStorage.loadLegacyAvailableTags(from: userDefaults).isEmpty {
            FocusTimerStorage.clearLegacyAvailableTags(in: userDefaults)
        }

        if needsSave {
            _ = saveContext("Failed to migrate focus storage")
        }
    }

    func ensureTagExists(named tagName: String) {
        guard let normalizedTagName = FocusTagCatalog.normalizeTagName(tagName) else {
            return
        }

        if upsertTagsIfNeeded(named: [normalizedTagName]) {
            _ = saveContext("Failed to persist tag")
        }
    }

    @discardableResult
    func renameTag(from oldName: String, to newName: String) -> Bool {
        guard
            let normalizedOldName = FocusTagCatalog.normalizeTagName(oldName),
            let normalizedNewName = FocusTagCatalog.normalizeTagName(newName),
            normalizedOldName != normalizedNewName
        else {
            return false
        }

        let sessionsToUpdate = getAllSessions().filter { $0.normalizedTagName == normalizedOldName }
        let tagRecords = fetchTagRecords()
        let matchingOldRecords = tagRecords.filter { FocusTagCatalog.normalizeTagName($0.name) == normalizedOldName }
        let hasMatchingNewRecord = tagRecords.contains { FocusTagCatalog.normalizeTagName($0.name) == normalizedNewName }

        guard !sessionsToUpdate.isEmpty || !matchingOldRecords.isEmpty else { return true }

        for session in sessionsToUpdate {
            session.tagName = normalizedNewName
            session.taskName = storedTaskName(note: normalizedNote(session.note), tagName: normalizedNewName)
        }

        if hasMatchingNewRecord {
            matchingOldRecords.forEach(modelContext.delete)
        } else if let firstRecord = matchingOldRecords.first {
            firstRecord.name = normalizedNewName
            matchingOldRecords.dropFirst().forEach(modelContext.delete)
        } else {
            modelContext.insert(FocusTagRecord(name: normalizedNewName))
        }

        return saveContext("Failed to rename tag")
    }

    @discardableResult
    func deleteTag(named tagName: String) -> Bool {
        guard let normalizedTagName = FocusTagCatalog.normalizeTagName(tagName) else {
            return false
        }

        let sessionsToUpdate = getAllSessions().filter { $0.normalizedTagName == normalizedTagName }
        let tagRecords = fetchTagRecords().filter { FocusTagCatalog.normalizeTagName($0.name) == normalizedTagName }
        guard !sessionsToUpdate.isEmpty || !tagRecords.isEmpty else { return true }

        for session in sessionsToUpdate {
            session.tagName = nil
            session.taskName = storedTaskName(note: normalizedNote(session.note), tagName: nil)
        }

        tagRecords.forEach(modelContext.delete)

        return saveContext("Failed to delete tag")
    }

    private func fetchTagRecords() -> [FocusTagRecord] {
        let descriptor = FetchDescriptor<FocusTagRecord>()

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch raw tags: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func normalizedNote(_ note: String?) -> String {
        FocusTagCatalog.sanitize(note, maxLength: 80)
    }

    private func storedTaskName(note: String, tagName: String?) -> String {
        if !note.isEmpty {
            return note
        }

        if let tagName {
            return tagName
        }

        return FocusTagCatalog.defaultSessionTitle
    }

    private func normalizeSessionForCurrentSchema(_ session: FocusSession) -> Bool {
        let normalizedTagName = FocusTagCatalog.normalizeTagName(session.tagName)
        let migratedNote = migratedNote(for: session, normalizedTagName: normalizedTagName)
        let normalizedStoredTaskName = storedTaskName(note: migratedNote, tagName: normalizedTagName)

        var changed = false

        if session.tagName != normalizedTagName {
            session.tagName = normalizedTagName
            changed = true
        }

        let expectedNote: String? = migratedNote.isEmpty ? nil : migratedNote
        if session.note != expectedNote {
            session.note = expectedNote
            changed = true
        }

        if session.taskName != normalizedStoredTaskName {
            session.taskName = normalizedStoredTaskName
            changed = true
        }

        return changed
    }

    private func migratedNote(for session: FocusSession, normalizedTagName: String?) -> String {
        let normalizedStoredNote = normalizedNote(session.note)
        if !normalizedStoredNote.isEmpty {
            return normalizedStoredNote
        }

        let legacyTaskName = FocusTagCatalog.sanitize(session.taskName, maxLength: 80)
        if legacyTaskName.isEmpty || legacyTaskName == FocusTagCatalog.defaultSessionTitle {
            return ""
        }

        if let normalizedTagName, legacyTaskName == normalizedTagName {
            return ""
        }

        return legacyTaskName
    }

    private func upsertTagsIfNeeded(named tagNames: [String]) -> Bool {
        let normalizedTagNames = FocusTagCatalog.normalizedTags(from: tagNames)
        guard !normalizedTagNames.isEmpty else { return false }

        let existingRecords = fetchTagRecords()
        let existingNames = Set(existingRecords.compactMap { FocusTagCatalog.normalizeTagName($0.name) })
        let missingNames = normalizedTagNames.filter { !existingNames.contains($0) }
        guard !missingNames.isEmpty else { return false }

        let baseDate = Date()
        for (offset, name) in missingNames.enumerated() {
            modelContext.insert(
                FocusTagRecord(
                    name: name,
                    createdAt: baseDate.addingTimeInterval(TimeInterval(offset))
                )
            )
        }

        return true
    }

    @discardableResult
    private func saveContext(_ message: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
