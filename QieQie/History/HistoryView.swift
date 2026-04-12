import SwiftUI

/// 历史记录视图
struct HistoryView: View {
    /// 历史记录管理器
    let historyManager: FocusHistoryManager

    /// 返回按钮绑定
    @Binding var showHistory: Bool

    /// 按日期分组的会话数据
    @State private var groupedSessions: [(date: Date, sessions: [FocusSession])] = []

    /// 总统计
    @State private var totalStats: FocusStatistics = FocusStatistics()

    /// 要删除的会话
    @State private var sessionToDelete: FocusSession?
    @State private var showDeleteConfirmation: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // 头部
            headerSection

            // 统计信息
            statisticsSection

            Divider()

            // 历史记录列表
            historyList

            // 返回按钮
            Button(action: { showHistory = false }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("返回")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(16)
        .frame(width: 300, height: 380)
        .onAppear {
            loadData()
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("确定要删除这条记录吗？")
        }
    }

    /// 头部
    private var headerSection: some View {
        HStack {
            Text("历史记录")
                .font(.headline)
            Spacer()
        }
    }

    /// 统计信息
    private var statisticsSection: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(totalStats.sessionCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("总次数")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 2) {
                Text(FocusStatistics.formatDuration(totalStats.allTimeTotal))
                    .font(.title2)
                    .fontWeight(.bold)
                Text("总时长")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 2) {
                Text("\(totalStats.completedCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("已完成")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    /// 历史记录列表
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if groupedSessions.isEmpty {
                    Text("暂无记录")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(groupedSessions, id: \.date) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            // 日期标题
                            Text(FocusDisplayFormatter.date(group.date))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            // 会话列表
                            ForEach(group.sessions, id: \.id) { session in
                                sessionRow(session)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 会话行
    private func sessionRow(_ session: FocusSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.taskName)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Text(FocusDisplayFormatter.time(session.startTime))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(FocusStatistics.formatDuration(session.duration))
                .font(.system(size: 12))
                .fontWeight(.medium)

            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            // 删除按钮
            Button(action: {
                sessionToDelete = session
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .padding(.trailing, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(6)
    }

    // MARK: - 私有方法

    /// 加载数据
    private func loadData() {
        let snapshot = historyManager.getHistorySnapshot()
        groupedSessions = snapshot.groupedSessions
        totalStats = snapshot.totalStatistics
    }

    /// 删除会话
    private func deleteSession() {
        guard let session = sessionToDelete else { return }

        if historyManager.deleteSession(session) {
            loadData()
        }
    }
}
