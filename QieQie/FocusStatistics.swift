import Foundation

/// 专注统计数据模型
/// 用于展示不同时间范围的统计数据
struct FocusStatistics {
    /// 今日累计时长（秒）
    var todayTotal: TimeInterval = 0

    /// 本周累计时长（秒）
    var weekTotal: TimeInterval = 0

    /// 本月累计时长（秒）
    var monthTotal: TimeInterval = 0

    /// 累计总时长（秒）
    var allTimeTotal: TimeInterval = 0

    /// 会话总数
    var sessionCount: Int = 0

    /// 已完成会话数
    var completedCount: Int = 0

    /// 格式化时长为可读字符串
    /// - Parameter interval: 时长（秒）
    /// - Returns: 格式化的时间字符串
    static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "0分钟"
        }
    }
}
