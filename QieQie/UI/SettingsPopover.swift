import AppKit
import SwiftUI

enum SettingsPopoverInitialPanel {
    case main
    case settings
    case statistics
}

enum SettingsPopoverLayout {
    static let mainSize = CGSize(width: 252, height: 340)
    static let settingsSize = CGSize(width: 248, height: 320)
    static let statisticsSize = CGSize(width: 252, height: 320)
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
        static let tagEditorField = "settingsPopover.tagEditorField"
        static let categoryPicker = "settingsPopover.categoryPicker"
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

    private enum TagEditorMode: Equatable {
        case create
        case rename(originalName: String)

        var title: String {
            switch self {
            case .create:
                return "新建分类"
            case .rename:
                return "重命名分类"
            }
        }

        var confirmTitle: String {
            switch self {
            case .create:
                return "添加"
            case .rename:
                return "保存"
            }
        }

        var placeholder: String {
            switch self {
            case .create:
                return "输入分类名"
            case .rename:
                return "输入新分类名"
            }
        }
    }

    @ObservedObject var focusTimerManager: FocusTimerManager

    @State private var panel: Panel = .main
    @State private var isCategoryPickerPresented = false
    @State private var isQuickFocusDurationEditorPresented = false
    @State private var isTagEditorPresented = false
    @State private var tagEditorMode: TagEditorMode = .create
    @State private var quickFocusMinutes = "25"
    @State private var newTagName = ""
    @State private var quickFocusDurationToggleGate = TransientPopoverToggleGate()
    @State private var focusMinutes = "25"
    @State private var shortBreakMinutes = "5"
    @State private var longBreakMinutes = "15"
    @State private var longBreakInterval = "4"
    @State private var autoStartBreak = false
    @State private var autoStartNextFocus = false
    @State private var dashboardStats = FocusStatistics()
    @State private var recentSessions: [FocusSession] = []
    @FocusState private var isQuickFocusDurationFieldFocused: Bool
    @FocusState private var isTagEditorFieldFocused: Bool
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
        .onChange(of: isTagEditorPresented) { _, isPresented in
            if !isPresented {
                newTagName = ""
                isTagEditorFieldFocused = false
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 10) {
            headerRow(title: focusTimerManager.state.currentPhase.title, showsBack: false)
            quickFocusDurationSection
            taskMetadataSection
            statisticsSection
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
                title: "统计概览",
                backAccessibilityID: FocusTimerAccessibilityID.SettingsPopover.backButton,
                onBack: { panel = .main }
            ) {
                Button(action: openStatisticsWindow) {
                    Text("统计")
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

    private var taskMetadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("分类与说明")
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                categoryPickerField

                TextField("补充说明", text: taskNameBinding)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.taskNameField)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
            }
        }
        .popover(
            isPresented: $isTagEditorPresented,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            tagEditor
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tagEditorMode.title)
                .font(FocusPanelTypography.sectionTitle)

            TextField(tagEditorMode.placeholder, text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .focused($isTagEditorFieldFocused)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.tagEditorField)
                .onChange(of: newTagName) { _, newValue in
                    newTagName = FocusTagCatalog.sanitize(
                        newValue,
                        maxLength: FocusTagCatalog.maxTagLength
                    )
                }
                .onSubmit(submitTagEditor)

            HStack(spacing: 8) {
                Button("取消", role: .cancel, action: dismissTagEditor)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button(tagEditorMode.confirmTitle, action: submitTagEditor)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmitTagEditor)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .frame(width: 208)
        .onAppear {
            if tagEditorMode == .create {
                newTagName = ""
            } else {
                switch tagEditorMode {
                case .create:
                    newTagName = ""
                case .rename(let originalName):
                    newTagName = originalName
                }
            }

            Task { @MainActor in
                isTagEditorFieldFocused = true
            }
        }
    }

    private var categoryPickerField: some View {
        Button(action: toggleCategoryPicker) {
            HStack(spacing: 8) {
                Text(selectedTagTitle)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .font(FocusPanelTypography.bodyLabel)
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .frame(width: 104, height: 34, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusPanelSurface(cornerRadius: FocusPanelChrome.sectionCornerRadius)
        .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.categoryPicker)
        .popover(
            isPresented: $isCategoryPickerPresented,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            CategoryPickerPopoverContent(
                availableTags: focusTimerManager.availableTags,
                selectedTagName: focusTimerManager.selectedTagName,
                untaggedTitle: FocusTagCatalog.untaggedName,
                onSelectTag: selectTagFromPicker,
                onCreateTag: openCreateTagEditor,
                onRenameTag: openRenameTagEditor(for:),
                onDeleteTag: deleteTag
            )
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

    private func toggleCategoryPicker() {
        isCategoryPickerPresented.toggle()
    }

    private func openCreateTagEditor() {
        isCategoryPickerPresented = false
        tagEditorMode = .create
        DispatchQueue.main.async {
            isTagEditorPresented = true
        }
    }

    private func openRenameTagEditor(for tagName: String) {
        guard FocusTagCatalog.normalizeTagName(tagName) != nil else { return }
        isCategoryPickerPresented = false
        tagEditorMode = .rename(originalName: tagName)
        DispatchQueue.main.async {
            isTagEditorPresented = true
        }
    }

    private func dismissTagEditor() {
        isTagEditorPresented = false
        newTagName = ""
        isTagEditorFieldFocused = false
    }

    private func deleteTag(_ tagName: String) {
        isCategoryPickerPresented = false
        _ = focusTimerManager.removeTag(tagName)
    }

    private func selectTagFromPicker(_ tagName: String?) {
        focusTimerManager.updateSelectedTagName(tagName)
        isCategoryPickerPresented = false
    }

    private func submitTagEditor() {
        guard canSubmitTagEditor else { return }

        switch tagEditorMode {
        case .create:
            _ = focusTimerManager.addTag(newTagName)
        case .rename(let originalName):
            _ = focusTimerManager.renameTag(from: originalName, to: newTagName)
        }

        dismissTagEditor()
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

    private var selectedTagTitle: String {
        focusTimerManager.selectedTagName ?? FocusTagCatalog.untaggedName
    }

    private var canSubmitTagEditor: Bool {
        guard let normalized = FocusTagCatalog.normalizeTagName(newTagName) else { return false }

        switch tagEditorMode {
        case .create:
            return !focusTimerManager.availableTags.contains(normalized)
        case .rename(let originalName):
            if normalized == originalName {
                return false
            }
            return !focusTimerManager.availableTags.contains(normalized)
        }
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

private struct CategoryPickerPopoverContent: View {
    let availableTags: [String]
    let selectedTagName: String?
    let untaggedTitle: String
    let onSelectTag: (String?) -> Void
    let onCreateTag: () -> Void
    let onRenameTag: (String) -> Void
    let onDeleteTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { onSelectTag(nil) }) {
                pickerRowLabel(title: untaggedTitle, isSelected: selectedTagName == nil)
            }
            .buttonStyle(.plain)

            if !availableTags.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(availableTags, id: \.self) { tag in
                            CategoryPickerTagRowView(
                                title: tag,
                                isSelected: selectedTagName == tag,
                                accessibilityIdentifier: "categoryPicker.row.\(tag)",
                                onSelect: { onSelectTag(tag) },
                                onRename: { onRenameTag(tag) },
                                onDelete: { onDeleteTag(tag) }
                            )
                            .frame(height: 30)
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(availableTags.count) * 34, 180))
            }

            Divider()
                .padding(.top, 2)

            Button(action: onCreateTag) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("新建分类")
                    Spacer(minLength: 0)
                }
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 188)
    }

    private func pickerRowLabel(title: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .font(FocusPanelTypography.bodyLabel)
        .foregroundColor(.primary)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
        )
    }
}

struct CategoryPickerTagRowView: NSViewRepresentable {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String?
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelect: onSelect,
            onRename: onRename,
            onDelete: onDelete
        )
    }

    func makeNSView(context: Context) -> CategoryPickerTagRowControl {
        let view = CategoryPickerTagRowControl()
        if let accessibilityIdentifier {
            view.identifier = NSUserInterfaceItemIdentifier(accessibilityIdentifier)
        }
        view.coordinator = context.coordinator
        view.title = title
        view.isSelected = isSelected
        return view
    }

    func updateNSView(_ nsView: CategoryPickerTagRowControl, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.onRename = onRename
        context.coordinator.onDelete = onDelete
        nsView.coordinator = context.coordinator
        nsView.title = title
        nsView.isSelected = isSelected
    }

    final class Coordinator: NSObject {
        var onSelect: () -> Void
        var onRename: () -> Void
        var onDelete: () -> Void

        init(
            onSelect: @escaping () -> Void,
            onRename: @escaping () -> Void,
            onDelete: @escaping () -> Void
        ) {
            self.onSelect = onSelect
            self.onRename = onRename
            self.onDelete = onDelete
        }

        func showContextMenu(from view: NSView) {
            let menu = makeContextMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.maxY - 2), in: view)
        }

        func makeContextMenu() -> NSMenu {
            let menu = NSMenu()
            menu.addItem(menuItem(title: "重命名分类…") { [weak self] in
                self?.onRename()
            })
            menu.addItem(menuItem(title: "删除分类") { [weak self] in
                self?.onDelete()
            })
            return menu
        }

        @objc
        private func handleMenuItem(_ sender: NSMenuItem) {
            (sender.representedObject as? CategoryPickerMenuAction)?.handler()
        }

        private func menuItem(title: String, handler: @escaping () -> Void) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(handleMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = CategoryPickerMenuAction(handler: handler)
            return item
        }
    }
}

final class CategoryPickerTagRowControl: NSControl {
    weak var coordinator: CategoryPickerTagRowView.Coordinator?
    private let titleField = NSTextField(labelWithString: "")
    private let checkmarkImageView = NSImageView()

    var title: String = "" {
        didSet {
            titleField.stringValue = title
        }
    }

    var isSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            coordinator?.showContextMenu(from: self)
            return
        }

        coordinator?.onSelect()
    }

    override func rightMouseDown(with event: NSEvent) {
        coordinator?.showContextMenu(from: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        coordinator?.makeContextMenu()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.cell?.wraps = false
        titleField.cell?.isScrollable = true
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.image = NSImage(
            systemSymbolName: "checkmark",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
        checkmarkImageView.contentTintColor = .controlAccentColor
        checkmarkImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(titleField)
        addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkImageView.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            checkmarkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 10),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 10)
        ])

        updateSelectionState()
    }

    private func updateSelectionState() {
        layer?.backgroundColor = (
            isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.labelColor.withAlphaComponent(0.04)
        ).cgColor
        checkmarkImageView.isHidden = !isSelected
    }
}

private final class CategoryPickerMenuAction: NSObject {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }
}
