import Foundation
import OSLog
import SwiftData

/// 历史记录快照，避免视图层重复查询同一批数据
struct FocusHistorySnapshot {
    let groupedSessions: [(date: Date, sessions: [FocusSession])]
    let totalStatistics: FocusStatistics
    let insights: FocusHistoryInsights
}

/// 专注历史记录管理器
/// 负责查询和统计所有专注记录
@MainActor
final class FocusHistoryManager: ObservableObject {
    /// 模型上下文
    private let modelContext: ModelContext

    /// 日志
    private let logger = Logger(subsystem: "com.zhangzefu.qieqie", category: "FocusHistory")

    init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
    }

    /// 创建新的专注会话
    /// - Parameter taskName: 任务名称
    /// - Returns: 创建的会话对象
    func createSession(taskName: String, startTime: Date = Date()) -> FocusSession? {
        let session = FocusSession(taskName: taskName, startTime: startTime)
        modelContext.insert(session)

        do {
            try modelContext.save()
            return session
        } catch {
            logger.error("Failed to create session: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 完成会话
    /// - Parameters:
    ///   - session: 会话对象
    ///   - duration: 专注时长
    ///   - isCompleted: 是否完成
    func finishSession(_ session: FocusSession, endTime: Date = Date(), duration: TimeInterval, isCompleted: Bool) {
        session.endTime = endTime
        session.duration = duration
        session.isCompleted = isCompleted

        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to finish session: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 删除会话
    func deleteSession(_ session: FocusSession) -> Bool {
        modelContext.delete(session)

        do {
            try modelContext.save()
            return true
        } catch {
            logger.error("Failed to delete session: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 获取今日统计
    func getTodayStatistics() -> FocusStatistics {
        queryStatistics(from: startDate(for: .today))
    }

    /// 获取本周统计
    func getWeekStatistics() -> FocusStatistics {
        queryStatistics(from: startDate(for: .week))
    }

    /// 获取本月统计
    func getMonthStatistics() -> FocusStatistics {
        queryStatistics(from: startDate(for: .month))
    }

    /// 获取累计统计
    func getAllTimeStatistics() -> FocusStatistics {
        queryStatistics(from: startDate(for: .allTime))
    }

    /// 获取设置面板展示所需的统计信息
    func getDashboardStatistics() -> FocusStatistics {
        FocusHistoryAnalytics.aggregateStatistics(from: getAllSessions())
    }

    /// 获取历史记录所需的全部数据
    func getHistorySnapshot() -> FocusHistorySnapshot {
        let sessions = getAllSessions()
        return FocusHistorySnapshot(
            groupedSessions: groupSessionsByDate(sessions),
            totalStatistics: FocusHistoryAnalytics.aggregateStatistics(from: sessions),
            insights: FocusHistoryAnalytics.buildInsights(from: sessions)
        )
    }

    /// 查询统计
    private func queryStatistics(from startDate: Date) -> FocusStatistics {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= startDate },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            return FocusHistoryAnalytics.aggregateStatistics(from: try modelContext.fetch(descriptor))
        } catch {
            logger.error("Failed to fetch statistics: \(error.localizedDescription, privacy: .public)")
            return FocusStatistics()
        }
    }

    /// 获取所有会话
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

    /// 按日期分组会话
    func getSessionsGroupedByDate() -> [(date: Date, sessions: [FocusSession])] {
        groupSessionsByDate(getAllSessions())
    }

    private func startDate(for scope: FocusStatisticsScope) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch scope {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .allTime:
            return Date.distantPast
        }
    }

    private func groupSessionsByDate(_ sessions: [FocusSession]) -> [(date: Date, sessions: [FocusSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }

        return grouped
            .map { (date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }
}
