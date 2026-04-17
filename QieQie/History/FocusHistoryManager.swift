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
        taskName: String = "专注",
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

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to record focus session: \(error.localizedDescription, privacy: .public)")
        }
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
        guard !sessionsToUpdate.isEmpty else { return true }

        for session in sessionsToUpdate {
            session.tagName = normalizedNewName

            if session.note == nil, FocusTagCatalog.sanitize(session.taskName) == normalizedOldName {
                session.taskName = normalizedNewName
            }
        }

        do {
            try modelContext.save()
            return true
        } catch {
            logger.error("Failed to rename tag: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    func deleteTag(named tagName: String) -> Bool {
        guard let normalizedTagName = FocusTagCatalog.normalizeTagName(tagName) else {
            return false
        }

        let sessionsToUpdate = getAllSessions().filter { $0.normalizedTagName == normalizedTagName }
        guard !sessionsToUpdate.isEmpty else { return true }

        for session in sessionsToUpdate {
            session.tagName = nil

            if session.note == nil, FocusTagCatalog.sanitize(session.taskName) == normalizedTagName {
                session.taskName = "专注"
            }
        }

        do {
            try modelContext.save()
            return true
        } catch {
            logger.error("Failed to delete tag: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func normalizedNote(_ note: String) -> String {
        FocusTagCatalog.sanitize(note, maxLength: 80)
    }

    private func storedTaskName(note: String, tagName: String?) -> String {
        if !note.isEmpty {
            return note
        }

        if let tagName {
            return tagName
        }

        return "专注"
    }
}
