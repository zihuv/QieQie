import Foundation
import SwiftData

/// 专注历史记录管理器
/// 负责查询和统计所有专注记录
@MainActor
class FocusHistoryManager: ObservableObject {
    /// 模型容器
    let modelContainer: ModelContainer?

    /// 模型上下文
    private var modelContext: ModelContext?

    init(modelContainer: ModelContainer?) {
        self.modelContainer = modelContainer
        if let container = modelContainer {
            self.modelContext = container.mainContext
        }
    }

    /// 创建新的专注会话
    /// - Parameter taskName: 任务名称
    /// - Returns: 创建的会话对象
    func createSession(taskName: String) -> FocusSession? {
        guard let context = modelContext else { return nil }

        let session = FocusSession(taskName: taskName)
        context.insert(session)

        do {
            try context.save()
            return session
        } catch {
            print("Failed to create session: \(error)")
            return nil
        }
    }

    /// 完成会话
    /// - Parameters:
    ///   - session: 会话对象
    ///   - duration: 专注时长
    ///   - isCompleted: 是否完成
    func finishSession(_ session: FocusSession, duration: TimeInterval, isCompleted: Bool) {
        guard let context = modelContext else { return }

        session.endTime = Date()
        session.duration = duration
        session.isCompleted = isCompleted

        do {
            try context.save()
        } catch {
            print("Failed to finish session: \(error)")
        }
    }

    /// 获取今日统计
    func getTodayStatistics() -> FocusStatistics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return queryStatistics(from: startOfDay)
    }

    /// 获取本周统计
    func getWeekStatistics() -> FocusStatistics {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return queryStatistics(from: startOfWeek)
    }

    /// 获取本月统计
    func getMonthStatistics() -> FocusStatistics {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return queryStatistics(from: startOfMonth)
    }

    /// 获取累计统计
    func getAllTimeStatistics() -> FocusStatistics {
        return queryStatistics(from: Date.distantPast)
    }

    /// 查询统计
    private func queryStatistics(from startDate: Date) -> FocusStatistics {
        guard let context = modelContext else { return FocusStatistics() }

        var statistics = FocusStatistics()

        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= startDate },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            let sessions = try context.fetch(descriptor)
            statistics.sessionCount = sessions.count
            statistics.completedCount = sessions.filter { $0.isCompleted }.count

            for session in sessions {
                statistics.allTimeTotal += session.duration
            }

            // 计算今日、本周、本月
            let calendar = Calendar.current
            let now = Date()

            let startOfDay = calendar.startOfDay(for: now)
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

            statistics.todayTotal = sessions.filter { $0.startTime >= startOfDay }.reduce(0) { $0 + $1.duration }
            statistics.weekTotal = sessions.filter { $0.startTime >= startOfWeek }.reduce(0) { $0 + $1.duration }
            statistics.monthTotal = sessions.filter { $0.startTime >= startOfMonth }.reduce(0) { $0 + $1.duration }

        } catch {
            print("Failed to fetch statistics: \(error)")
        }

        return statistics
    }

    /// 获取所有会话
    func getAllSessions() -> [FocusSession] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch sessions: \(error)")
            return []
        }
    }

    /// 按日期分组会话
    func getSessionsGroupedByDate() -> [(date: Date, sessions: [FocusSession])] {
        let sessions = getAllSessions()
        let calendar = Calendar.current

        var grouped: [Date: [FocusSession]] = [:]

        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.startTime)
            if grouped[dayStart] != nil {
                grouped[dayStart]?.append(session)
            } else {
                grouped[dayStart] = [session]
            }
        }

        return grouped.map { (date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }
}
