import SwiftUI

enum SettingsPopoverInitialPanel {
    case main
    case settings
    case statistics
}

enum SettingsPopoverLayout {
    static let mainSize = FocusPanelLayout.unifiedPanelSize
    static let settingsSize = FocusPanelLayout.unifiedPanelSize
    static let statisticsSize = FocusPanelLayout.unifiedPanelSize
}

enum FocusTimerAccessibilityID {
    enum SettingsPopover {
        static let root = "settingsPopover.root"
        static let statisticsButton = "settingsPopover.statisticsButton"
        static let settingsButton = "settingsPopover.settingsButton"
        static let backButton = "settingsPopover.backButton"
        static let phaseTitle = "settingsPopover.phaseTitle"
        static let progressLabel = "settingsPopover.progressLabel"
        static let quickFocusDurationButton = "settingsPopover.quickFocusDurationButton"
        static let quickFocusDurationEditor = "settingsPopover.quickFocusDurationEditor"
        static let quickFocusDurationField = "settingsPopover.quickFocusDurationField"
        static let quickFocusDurationCancelButton = "settingsPopover.quickFocusDurationCancelButton"
        static let quickFocusDurationConfirmButton = "settingsPopover.quickFocusDurationConfirmButton"
        static let mainButton = "settingsPopover.mainButton"
        static let resetButton = "settingsPopover.resetButton"
        static let skipButton = "settingsPopover.skipButton"
        static let taskNameField = "settingsPopover.taskNameField"
        static let focusMinutesField = "settingsPopover.focusMinutesField"
        static let shortBreakMinutesField = "settingsPopover.shortBreakMinutesField"
        static let longBreakMinutesField = "settingsPopover.longBreakMinutesField"
        static let intervalField = "settingsPopover.intervalField"
        static let autoStartNextFocusToggle = "settingsPopover.autoStartNextFocusToggle"
        static let autoStartBreakToggle = "settingsPopover.autoStartBreakToggle"
        static let statisticsDetailButton = "settingsPopover.statisticsDetailButton"
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
        case statistics
    }

    @ObservedObject var focusTimerManager: FocusTimerManager

    @State private var panel: Panel = .main
    @State private var isQuickFocusDurationEditorPresented = false
    @State private var quickFocusMinutes = "25"
    @State private var quickFocusDurationToggleGate = TransientPopoverToggleGate()
    @State private var focusMinutes = "25"
    @State private var shortBreakMinutes = "5"
    @State private var longBreakMinutes = "15"
    @State private var longBreakInterval = "4"
    @State private var autoStartBreak = true
    @State private var autoStartNextFocus = true
    @State private var dashboardStats = FocusStatistics()
    @State private var recentSessions: [FocusSession] = []
    @FocusState private var isQuickFocusDurationFieldFocused: Bool
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
        case .statistics:
            panelValue = .statistics
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
            case .statistics:
                statisticsContent
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
            if panel == .statistics {
                refreshStatistics()
            }
            reportPreferredSize()
        }
        .onChange(of: isQuickFocusDurationEditorPresented) { wasPresented, isPresented in
            if wasPresented, !isPresented {
                quickFocusDurationToggleGate.recordDismiss(at: Date())
                syncQuickFocusDurationField()
                isQuickFocusDurationFieldFocused = false
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 10) {
            headerRow(title: focusTimerManager.state.currentPhase.title, showsBack: false)
            quickFocusDurationSection
            taskNameSection
            statisticsSection
            Spacer(minLength: 0)
            controlSection
        }
        .padding(FocusPanelChrome.compactPadding)
        .frame(
            width: SettingsPopoverLayout.mainSize.width,
            height: SettingsPopoverLayout.mainSize.height,
            alignment: .top
        )
    }

    private var settingsContent: some View {
        VStack(spacing: 8) {
            headerRow(title: "设置", showsBack: true)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    settingsSection(title: "计时选项") {
                        VStack(spacing: 0) {
                            settingsInputRow(
                                title: "番茄时长",
                                value: $focusMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.focusMinutesField
                            ) { updateFocusDuration() }

                            settingsDivider

                            settingsInputRow(
                                title: "短休息时长",
                                value: $shortBreakMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.shortBreakMinutesField
                            ) { updateShortBreakDuration() }

                            settingsDivider

                            settingsInputRow(
                                title: "长休息时长",
                                value: $longBreakMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.longBreakMinutesField
                            ) { updateLongBreakDuration() }

                            settingsDivider

                            settingsInputRow(
                                title: "长休息间隔番茄数",
                                value: $longBreakInterval,
                                suffix: "个",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.intervalField,
                                maxLength: 2,
                                upperBound: 10
                            ) { updateLongBreakInterval() }
                        }
                    }

                    settingsSection(title: "自动选项") {
                        VStack(spacing: 0) {
                            settingsToggleRow(
                                title: "自动开始下个番茄",
                                isOn: $autoStartNextFocus,
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.autoStartNextFocusToggle
                            )

                            settingsDivider

                            settingsToggleRow(
                                title: "自动开始休息",
                                isOn: $autoStartBreak,
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.autoStartBreakToggle
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 0)
            }
        }
        .padding(10)
        .frame(
            width: SettingsPopoverLayout.settingsSize.width,
            height: SettingsPopoverLayout.settingsSize.height,
            alignment: .top
        )
        .onChange(of: autoStartBreak) { _, newValue in
            var configuration = focusTimerManager.configuration
            configuration.autoStartBreak = newValue
            focusTimerManager.updateConfiguration(configuration)
        }
        .onChange(of: autoStartNextFocus) { _, newValue in
            var configuration = focusTimerManager.configuration
            configuration.autoStartNextFocus = newValue
            focusTimerManager.updateConfiguration(configuration)
        }
    }

    private var statisticsContent: some View {
        VStack(spacing: 0) {
            PopoverHeaderBar(
                title: "统计",
                backAccessibilityID: FocusTimerAccessibilityID.SettingsPopover.backButton,
                onBack: { panel = .main }
            ) {
                Button(action: openStatisticsWindow) {
                    Text("详情")
                        .font(FocusPanelTypography.supportingText)
                }
                .buttonStyle(.plain)
                .disabled(!canOpenStatisticsDetail)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.statisticsDetailButton)
            }
            .padding(.horizontal, FocusPanelChrome.compactPadding)
            .padding(.top, 10)

            StatisticsOverviewView(
                statistics: dashboardStats,
                recentSessions: Array(recentSessions.prefix(30))
            )
            .padding(.top, 2)
        }
        .frame(
            width: SettingsPopoverLayout.statisticsSize.width,
            height: SettingsPopoverLayout.statisticsSize.height,
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
                    .font(FocusPanelTypography.supportingText)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.progressLabel)

                Button(action: { panel = .settings }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(FocusPanelTypography.controlIcon)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.settingsButton)

                Button(action: showStatisticsOverview) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(FocusPanelTypography.controlIcon)
                }
                .buttonStyle(.plain)
                .disabled(!canShowStatistics)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.statisticsButton)
            }
        }
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            statisticsRow(title: "今日", period: dashboardStats.today)
            statisticsRow(title: "本周", period: dashboardStats.week)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
    }

    private var quickFocusDurationSection: some View {
        Button(action: toggleQuickFocusDurationEditor) {
            Text(formattedFocusDuration)
                .font(FocusPanelTypography.timerValue)
                .monospacedDigit()
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .focusPanelSurface()
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isQuickFocusDurationEditorPresented,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            quickFocusDurationEditor
        }
        .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationButton)
    }

    private var quickFocusDurationEditor: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("", text: $quickFocusMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 108)
                    .multilineTextAlignment(.center)
                    .focused($isQuickFocusDurationFieldFocused)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationField)
                    .onChange(of: quickFocusMinutes) { _, newValue in
                        quickFocusMinutes = FocusTimerDurationParser.sanitizeNumericInput(
                            newValue,
                            maxLength: 3
                        )
                    }
                    .onSubmit(applyQuickFocusDuration)

                Text("分钟")
                    .font(FocusPanelTypography.bodyLabel)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Button("取消", role: .cancel, action: dismissQuickFocusDurationEditor)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationCancelButton)

                Button("确定", action: applyQuickFocusDuration)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!canApplyQuickFocusDuration)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationConfirmButton)
            }
        }
        .padding(14)
        .frame(width: 196)
        .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationEditor)
        .onAppear {
            syncQuickFocusDurationField()
            Task { @MainActor in
                isQuickFocusDurationFieldFocused = true
            }
        }
    }

    private var taskNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("当前任务")
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)

            TextField("输入任务", text: taskNameBinding)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.taskNameField)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
        }
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
            switch focusTimerManager.state.currentPhase {
            case .focus:
                return "开始"
            case .shortBreak, .longBreak:
                return "开始休息"
            }
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
        HStack(spacing: 12) {
            Text("\(title):")
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)
            Spacer(minLength: 12)
            Text(FocusDisplayFormatter.summaryDuration(period.totalDuration))
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FocusPanelTypography.sectionTitle)
                .foregroundColor(.secondary)

            settingsCard {
                content()
            }
        }
    }

    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .focusPanelSurface()
    }

    private var settingsDivider: some View {
        Divider()
            .padding(.leading, 8)
    }

    private func settingsInputRow(
        title: String,
        value: Binding<String>,
        suffix: String,
        accessibilityID: String,
        maxLength: Int = 3,
        upperBound: Int? = nil,
        onCommit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(FocusPanelTypography.bodyLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                TextField("", text: value)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.mini)
                    .frame(width: 64)
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
                    .font(FocusPanelTypography.supportingText)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 24, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func settingsToggleRow(
        title: String,
        isOn: Binding<Bool>,
        accessibilityID: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(FocusPanelTypography.bodyLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .allowsTightening(true)
                .frame(width: 112, alignment: .leading)

            Spacer(minLength: 4)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityIdentifier(accessibilityID)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func syncConfigurationFields() {
        let configuration = focusTimerManager.configuration
        quickFocusMinutes = minutesString(from: configuration.focusDuration)
        focusMinutes = minutesString(from: configuration.focusDuration)
        shortBreakMinutes = minutesString(from: configuration.shortBreakDuration)
        longBreakMinutes = minutesString(from: configuration.longBreakDuration)
        longBreakInterval = String(configuration.longBreakInterval)
        autoStartBreak = configuration.autoStartBreak
        autoStartNextFocus = configuration.autoStartNextFocus
        refreshStatistics()
    }

    private func refreshStatistics() {
        dashboardStats = focusTimerManager.focusHistoryManager?.getDashboardStatistics() ?? FocusStatistics()
        recentSessions = focusTimerManager.focusHistoryManager?.getAllSessions() ?? []
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

    private var taskNameBinding: Binding<String> {
        Binding(
            get: { focusTimerManager.currentTaskName },
            set: { focusTimerManager.updateCurrentTaskName($0) }
        )
    }

    private var canShowStatistics: Bool {
        focusTimerManager.focusHistoryManager != nil
    }

    private var canOpenStatisticsDetail: Bool {
        canShowStatistics && onOpenStatistics != nil
    }

    private func showStatisticsOverview() {
        guard canShowStatistics else { return }
        refreshStatistics()
        panel = .statistics
    }

    private func openStatisticsWindow() {
        guard canOpenStatisticsDetail else { return }
        onOpenStatistics?()
    }

    private func reportPreferredSize() {
        onPreferredSizeChange?(preferredSize)
    }

    private func toggleQuickFocusDurationEditor() {
        if quickFocusDurationToggleGate.consumeDismissIfNeeded(at: Date()) {
            return
        }

        if isQuickFocusDurationEditorPresented {
            dismissQuickFocusDurationEditor()
        } else {
            presentQuickFocusDurationEditor()
        }
    }

    private func presentQuickFocusDurationEditor() {
        syncQuickFocusDurationField()
        isQuickFocusDurationEditorPresented = true
    }

    private func dismissQuickFocusDurationEditor() {
        isQuickFocusDurationEditorPresented = false
    }

    private func applyQuickFocusDuration() {
        guard let minutes = Int(quickFocusMinutes), minutes > 0 else { return }

        var configuration = focusTimerManager.configuration
        configuration.focusDuration = TimeInterval(minutes * 60)
        focusTimerManager.updateConfiguration(configuration)
        isQuickFocusDurationEditorPresented = false
    }

    private func syncQuickFocusDurationField() {
        quickFocusMinutes = minutesString(from: focusTimerManager.configuration.focusDuration)
    }

    private var preferredSize: CGSize {
        switch panel {
        case .main:
            return SettingsPopoverLayout.mainSize
        case .settings:
            return SettingsPopoverLayout.settingsSize
        case .statistics:
            return SettingsPopoverLayout.statisticsSize
        }
    }

    private var formattedFocusDuration: String {
        FocusDisplayFormatter.countdown(focusTimerManager.configuration.focusDuration)
    }

    private var canApplyQuickFocusDuration: Bool {
        guard let minutes = Int(quickFocusMinutes) else { return false }
        return minutes > 0
    }
}

struct SettingsPopover_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPopover(focusTimerManager: FocusTimerManager())
    }
}

struct TransientPopoverToggleGate {
    private(set) var lastDismissedAt: Date?
    let suppressionInterval: TimeInterval

    init(suppressionInterval: TimeInterval = 0.25) {
        self.suppressionInterval = suppressionInterval
    }

    mutating func recordDismiss(at date: Date) {
        lastDismissedAt = date
    }

    mutating func consumeDismissIfNeeded(at date: Date) -> Bool {
        guard let lastDismissedAt else { return false }

        let shouldSuppress = date.timeIntervalSince(lastDismissedAt) < suppressionInterval
        if shouldSuppress {
            self.lastDismissedAt = nil
        }

        return shouldSuppress
    }
}
