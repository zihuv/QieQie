import SwiftUI

enum SettingsPopoverInitialPanel {
    case main
    case settings
}

enum SettingsPopoverLayout {
    static let mainWidth: CGFloat = 236
    static let mainEstimatedHeight: CGFloat = 180
    static let mainSize = CGSize(width: mainWidth, height: mainEstimatedHeight)
    static let settingsSize = CGSize(width: 244, height: 258)

    static func fittedMainSize(for measuredSize: CGSize) -> CGSize {
        CGSize(
            width: mainWidth,
            height: max(ceil(measuredSize.height), mainEstimatedHeight)
        )
    }
}

enum FocusTimerAccessibilityID {
    enum SettingsPopover {
        static let root = "settingsPopover.root"
        static let statisticsButton = "settingsPopover.statisticsButton"
        static let settingsButton = "settingsPopover.settingsButton"
        static let backButton = "settingsPopover.backButton"
        static let phaseTitle = "settingsPopover.phaseTitle"
        static let progressLabel = "settingsPopover.progressLabel"
        static let mainButton = "settingsPopover.mainButton"
        static let resetButton = "settingsPopover.resetButton"
        static let skipButton = "settingsPopover.skipButton"
        static let focusMinutesField = "settingsPopover.focusMinutesField"
        static let shortBreakMinutesField = "settingsPopover.shortBreakMinutesField"
        static let longBreakMinutesField = "settingsPopover.longBreakMinutesField"
        static let intervalField = "settingsPopover.intervalField"
        static let autoAdvanceToggle = "settingsPopover.autoAdvanceToggle"
    }

    enum StatusBar {
        static let button = "statusBar.button"
        static let popover = "statusBar.popover"
    }
}

struct SettingsPopover: View {
    private enum Panel {
        case main
        case settings
    }

    @ObservedObject var focusTimerManager: FocusTimerManager

    @State private var panel: Panel = .main
    @State private var focusMinutes = "25"
    @State private var shortBreakMinutes = "5"
    @State private var longBreakMinutes = "15"
    @State private var longBreakInterval = "4"
    @State private var autoAdvance = true
    @State private var dashboardStats = FocusStatistics()
    @State private var mainContentSize = SettingsPopoverLayout.mainSize
    private let onPreferredSizeChange: ((CGSize) -> Void)?
    private let onOpenStatistics: (() -> Void)?

    init(
        focusTimerManager: FocusTimerManager,
        initialPanel: SettingsPopoverInitialPanel = .main,
        onPreferredSizeChange: ((CGSize) -> Void)? = nil,
        onOpenStatistics: (() -> Void)? = nil
    ) {
        self.focusTimerManager = focusTimerManager
        self.onPreferredSizeChange = onPreferredSizeChange
        self.onOpenStatistics = onOpenStatistics
        let panelValue: Panel
        switch initialPanel {
        case .main:
            panelValue = .main
        case .settings:
            panelValue = .settings
        }
        _panel = State(initialValue: panelValue)
    }

    var body: some View {
        Group {
            switch panel {
            case .main:
                mainContent
            case .settings:
                settingsContent
            }
        }
        .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.root)
        .onAppear {
            syncConfigurationFields()
            refreshStatistics()
            reportPreferredSize()
        }
        .onChange(of: focusTimerManager.state.configuration) { _, _ in
            syncConfigurationFields()
        }
        .onChange(of: focusTimerManager.state.currentPhase) { _, _ in
            refreshStatistics()
        }
        .onChange(of: focusTimerManager.state.cycleFocusCount) { _, _ in
            refreshStatistics()
        }
        .onChange(of: panel) { _, _ in
            reportPreferredSize()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 10) {
            headerRow(title: focusTimerManager.state.currentPhase.title, showsBack: false)
            statisticsSection
            controlSection
        }
        .padding(10)
        .frame(width: SettingsPopoverLayout.mainWidth, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .onContentSizeChange { newSize in
            guard newSize.height > 0 else { return }

            let fittedSize = SettingsPopoverLayout.fittedMainSize(for: newSize)
            guard fittedSize != mainContentSize else { return }

            mainContentSize = fittedSize
            if panel == .main {
                reportPreferredSize()
            }
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 10) {
            headerRow(title: "设置", showsBack: true)
            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    settingsRow(
                        title: "专注时长",
                        value: $focusMinutes,
                        suffix: "分钟",
                        accessibilityID: FocusTimerAccessibilityID.SettingsPopover.focusMinutesField
                    ) { updateFocusDuration() }

                    settingsRow(
                        title: "短休息",
                        value: $shortBreakMinutes,
                        suffix: "分钟",
                        accessibilityID: FocusTimerAccessibilityID.SettingsPopover.shortBreakMinutesField
                    ) { updateShortBreakDuration() }

                    settingsRow(
                        title: "长休息",
                        value: $longBreakMinutes,
                        suffix: "分钟",
                        accessibilityID: FocusTimerAccessibilityID.SettingsPopover.longBreakMinutesField
                    ) { updateLongBreakDuration() }

                    settingsRow(
                        title: "长休息间隔",
                        value: $longBreakInterval,
                        suffix: "次专注",
                        accessibilityID: FocusTimerAccessibilityID.SettingsPopover.intervalField,
                        maxLength: 2,
                        upperBound: 10
                    ) { updateLongBreakInterval() }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                .cornerRadius(12)

                Toggle("自动进入下一阶段", isOn: $autoAdvance)
                    .toggleStyle(.switch)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .cornerRadius(12)
                    .onChange(of: autoAdvance) { _, newValue in
                        var configuration = focusTimerManager.configuration
                        configuration.autoAdvance = newValue
                        focusTimerManager.updateConfiguration(configuration)
                    }
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.autoAdvanceToggle)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .padding(10)
        .frame(
            width: SettingsPopoverLayout.settingsSize.width,
            height: SettingsPopoverLayout.settingsSize.height,
            alignment: .top
        )
    }

    private func headerRow(title: String, showsBack: Bool) -> some View {
        PopoverHeaderBar(
            title: title,
            titleAccessibilityID: FocusTimerAccessibilityID.SettingsPopover.phaseTitle,
            backAccessibilityID: showsBack ? FocusTimerAccessibilityID.SettingsPopover.backButton : nil,
            onBack: showsBack ? { panel = .main } : nil
        ) {
            if !showsBack {
                Text(focusTimerManager.state.progressText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.progressLabel)

                Button(action: { panel = .settings }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.settingsButton)

                Button(action: openStatisticsWindow) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .disabled(!canOpenStatistics)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.statisticsButton)
            }
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            statisticsRow(title: "今日", period: dashboardStats.today)
            statisticsRow(title: "本周", period: dashboardStats.week)

            Button(action: openStatisticsWindow) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("查看统计")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .disabled(!canOpenStatistics)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
        .cornerRadius(12)
    }

    private var controlSection: some View {
        VStack(spacing: 6) {
            Button(action: mainButtonAction) {
                HStack(spacing: 6) {
                    Image(systemName: mainButtonIcon)
                    Text(mainButtonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.mainButton)

            HStack(spacing: 6) {
                Button(action: focusTimerManager.skipCurrentPhase) {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                        Text("跳过")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!focusTimerManager.state.canSkip)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.skipButton)

                Button(action: focusTimerManager.resetCurrentPhase) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!focusTimerManager.state.canReset)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.resetButton)
            }
        }
    }

    private var mainButtonTitle: String {
        switch focusTimerManager.state.status {
        case .idle:
            return "开始"
        case .running:
            return "暂停"
        case .paused:
            return "继续"
        }
    }

    private var mainButtonIcon: String {
        switch focusTimerManager.state.status {
        case .idle:
            return "play.fill"
        case .running:
            return "pause.fill"
        case .paused:
            return "play.circle.fill"
        }
    }

    private func statisticsRow(title: String, period: FocusStatisticsPeriod) -> some View {
        HStack {
            Text("\(title):")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(period.sessionCount) 次")
                .font(.caption)
            Text(FocusStatistics.formatDuration(period.totalDuration))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private func settingsRow(
        title: String,
        value: Binding<String>,
        suffix: String,
        accessibilityID: String,
        maxLength: Int = 3,
        upperBound: Int? = nil,
        onCommit: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            TextField("", text: value)
                .textFieldStyle(.roundedBorder)
                .frame(width: 46)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(accessibilityID)
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = FocusTimerDurationParser.sanitizeNumericInput(
                        newValue,
                        maxLength: maxLength,
                        upperBound: upperBound
                    )
                    onCommit()
                }
            Text(suffix)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func syncConfigurationFields() {
        let configuration = focusTimerManager.configuration
        focusMinutes = minutesString(from: configuration.focusDuration)
        shortBreakMinutes = minutesString(from: configuration.shortBreakDuration)
        longBreakMinutes = minutesString(from: configuration.longBreakDuration)
        longBreakInterval = String(configuration.longBreakInterval)
        autoAdvance = configuration.autoAdvance
        refreshStatistics()
    }

    private func refreshStatistics() {
        dashboardStats = focusTimerManager.focusHistoryManager?.getDashboardStatistics() ?? FocusStatistics()
    }

    private func mainButtonAction() {
        switch focusTimerManager.state.status {
        case .idle:
            focusTimerManager.startCurrentPhase()
        case .running:
            focusTimerManager.pauseCurrentPhase()
        case .paused:
            focusTimerManager.resumeCurrentPhase()
        }
    }

    private func updateFocusDuration() {
        guard let minutes = Int(focusMinutes), minutes > 0 else { return }
        var configuration = focusTimerManager.configuration
        configuration.focusDuration = TimeInterval(minutes * 60)
        focusTimerManager.updateConfiguration(configuration)
    }

    private func updateShortBreakDuration() {
        guard let minutes = Int(shortBreakMinutes), minutes > 0 else { return }
        var configuration = focusTimerManager.configuration
        configuration.shortBreakDuration = TimeInterval(minutes * 60)
        focusTimerManager.updateConfiguration(configuration)
    }

    private func updateLongBreakDuration() {
        guard let minutes = Int(longBreakMinutes), minutes > 0 else { return }
        var configuration = focusTimerManager.configuration
        configuration.longBreakDuration = TimeInterval(minutes * 60)
        focusTimerManager.updateConfiguration(configuration)
    }

    private func updateLongBreakInterval() {
        guard let interval = Int(longBreakInterval), interval > 0 else { return }
        var configuration = focusTimerManager.configuration
        configuration.longBreakInterval = interval
        focusTimerManager.updateConfiguration(configuration)
    }

    private func minutesString(from duration: TimeInterval) -> String {
        String(max(1, Int(duration.rounded(.down)) / 60))
    }

    private var canOpenStatistics: Bool {
        focusTimerManager.focusHistoryManager != nil && onOpenStatistics != nil
    }

    private func openStatisticsWindow() {
        guard canOpenStatistics else { return }
        onOpenStatistics?()
    }

    private func reportPreferredSize() {
        onPreferredSizeChange?(preferredSize)
    }

    private var preferredSize: CGSize {
        switch panel {
        case .main:
            return mainContentSize
        case .settings:
            return SettingsPopoverLayout.settingsSize
        }
    }
}

struct SettingsPopover_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPopover(focusTimerManager: FocusTimerManager())
    }
}

private struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private extension View {
    func onContentSizeChange(_ action: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: ContentSizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(ContentSizePreferenceKey.self, perform: action)
    }
}
