import Foundation
import SwiftData

/// 专注会话数据模型
/// 用于记录每一次专注时间
@Model
final class FocusSession {
    /// 唯一标识
    var id: UUID

    /// 任务名称
    var taskName: String

    /// 开始时间
    var startTime: Date

    /// 结束时间
    var endTime: Date?

    /// 专注时长（秒）
    var duration: TimeInterval

    /// 是否已完成
    var isCompleted: Bool

    /// 创建时间
    var createdAt: Date

    init(
        taskName: String = "未命名任务",
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval = 0,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.taskName = taskName
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}
