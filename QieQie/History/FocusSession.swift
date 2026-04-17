import Foundation
import SwiftData

enum FocusTagCatalog {
    static let untaggedName = "未分类"
    static let defaultTags: [String] = []
    static let maxTagLength = 12

    static func normalizeTagName(_ tagName: String?) -> String? {
        let normalized = sanitize(tagName, maxLength: maxTagLength)
        return normalized.isEmpty ? nil : normalized
    }

    static func sanitize(_ value: String?, maxLength: Int? = nil) -> String {
        var sanitized = (value ?? "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }

        if let maxLength, sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }

        return sanitized
    }

    static func normalizedTags(from tags: [String]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()

        for tag in tags {
            guard let normalized = normalizeTagName(tag), seen.insert(normalized).inserted else {
                continue
            }
            ordered.append(normalized)
        }

        return ordered
    }
}

/// 专注会话数据模型
/// 用于记录每一次专注时间
@Model
final class FocusSession {
    /// 唯一标识
    var id: UUID

    /// 任务名称
    var taskName: String

    /// 分类标签
    var tagName: String?

    /// 备注说明
    var note: String?

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
        tagName: String? = nil,
        note: String? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval = 0,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.taskName = taskName
        self.tagName = tagName
        self.note = note
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
}

extension FocusSession {
    var normalizedTagName: String? {
        FocusTagCatalog.normalizeTagName(tagName)
    }

    var normalizedNote: String {
        let noteText = FocusTagCatalog.sanitize(note)
        if !noteText.isEmpty {
            return noteText
        }

        let legacyTaskName = FocusTagCatalog.sanitize(taskName)
        if legacyTaskName.isEmpty || legacyTaskName == "专注" {
            return ""
        }

        if let normalizedTagName, legacyTaskName == normalizedTagName {
            return ""
        }

        return legacyTaskName
    }

    var displayTagName: String {
        normalizedTagName ?? FocusTagCatalog.untaggedName
    }

    var displayNote: String? {
        let note = normalizedNote
        return note.isEmpty ? nil : note
    }

    var displayTitle: String {
        displayNote ?? displayTagName
    }

    var completionDate: Date {
        endTime ?? startTime
    }
}
