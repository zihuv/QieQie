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
        let session = FocusSession(
            taskName: normalizedTaskName(taskName),
            startTime: completedAt,
            endTime: completedAt,
            duration: duration,
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

    private func normalizedTaskName(_ taskName: String) -> String {
        let trimmed = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "专注" : trimmed
    }
}
