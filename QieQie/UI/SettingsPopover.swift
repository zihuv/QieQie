import SwiftUI

enum SettingsPopoverInitialPanel {
    case main
    case settings
    case statistics
}

enum SettingsPopoverLayout {
    static let mainSize = CGSize(width: 252, height: 284)
    static let settingsSize = CGSize(width: 252, height: 306)
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

enum SettingsPopoverTagEditorMode: Equatable {
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

struct SettingsPopover: View {
    private enum Panel {
        case main
        case settings
        case statistics
    }

    @ObservedObject var focusTimerManager: FocusTimerManager

    @State private var panel: Panel = .main
    @State private var isCategoryPickerPresented = false
    @State private var isQuickFocusDurationEditorPresented = false
    @State private var isTagEditorPresented = false
    @State private var tagEditorMode: SettingsPopoverTagEditorMode = .create
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
        SettingsPopoverMainPanel(
            phaseTitle: focusTimerManager.state.currentPhase.title,
            progressText: focusTimerManager.state.progressText,
            canShowStatistics: canShowStatistics,
            formattedFocusDuration: formattedFocusDuration,
            isQuickFocusDurationEditorPresented: $isQuickFocusDurationEditorPresented,
            quickFocusMinutes: $quickFocusMinutes,
            quickFocusDurationFieldFocused: $isQuickFocusDurationFieldFocused,
            canApplyQuickFocusDuration: canApplyQuickFocusDuration,
            taskName: taskNameBinding,
            isTagEditorPresented: $isTagEditorPresented,
            tagEditorMode: tagEditorMode,
            newTagName: $newTagName,
            tagEditorFieldFocused: $isTagEditorFieldFocused,
            canSubmitTagEditor: canSubmitTagEditor,
            dashboardStats: dashboardStats,
            mainButtonTitle: mainButtonTitle,
            mainButtonIcon: mainButtonIcon,
            canSkip: focusTimerManager.state.canSkip,
            canReset: focusTimerManager.state.canReset,
            onOpenSettings: { panel = .settings },
            onOpenStatistics: showStatisticsOverview,
            onToggleQuickFocusDurationEditor: toggleQuickFocusDurationEditor,
            onPrepareQuickFocusDurationEditor: syncQuickFocusDurationField,
            onDismissQuickFocusDurationEditor: dismissQuickFocusDurationEditor,
            onApplyQuickFocusDuration: applyQuickFocusDuration,
            onPrepareTagEditor: prepareTagEditor,
            onDismissTagEditor: dismissTagEditor,
            onSubmitTagEditor: submitTagEditor,
            onMainButton: mainButtonAction,
            onSkip: focusTimerManager.skipCurrentPhase,
            onReset: focusTimerManager.resetCurrentPhase
        ) {
            SettingsPopoverCategoryPickerField(
                isPresented: $isCategoryPickerPresented,
                availableTags: focusTimerManager.availableTags,
                selectedTagName: focusTimerManager.selectedTagName,
                selectedTagTitle: selectedTagTitle,
                onSelectTag: selectTagFromPicker,
                onCreateTag: openCreateTagEditor,
                onRenameTag: openRenameTagEditor(for:),
                onDeleteTag: deleteTag
            )
        }
    }

    private var settingsContent: some View {
        SettingsPopoverSettingsPanel(
            focusMinutes: $focusMinutes,
            shortBreakMinutes: $shortBreakMinutes,
            longBreakMinutes: $longBreakMinutes,
            longBreakInterval: $longBreakInterval,
            autoStartNextFocus: $autoStartNextFocus,
            autoStartBreak: $autoStartBreak,
            onBack: { panel = .main },
            onFocusDurationChange: updateFocusDuration,
            onShortBreakDurationChange: updateShortBreakDuration,
            onLongBreakDurationChange: updateLongBreakDuration,
            onLongBreakIntervalChange: updateLongBreakInterval,
            onAutoStartNextFocusChange: updateAutoStartNextFocus,
            onAutoStartBreakChange: updateAutoStartBreak
        )
    }

    private var statisticsContent: some View {
        SettingsPopoverStatisticsPanel(
            canOpenStatisticsDetail: canOpenStatisticsDetail,
            dashboardStats: dashboardStats,
            recentSessions: recentSessions,
            onBack: { panel = .main },
            onOpenStatistics: openStatisticsWindow
        )
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

    private func updateAutoStartBreak(_ value: Bool) {
        var configuration = focusTimerManager.configuration
        configuration.autoStartBreak = value
        focusTimerManager.updateConfiguration(configuration)
    }

    private func updateAutoStartNextFocus(_ value: Bool) {
        var configuration = focusTimerManager.configuration
        configuration.autoStartNextFocus = value
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

    private func prepareTagEditor() {
        switch tagEditorMode {
        case .create:
            newTagName = ""
        case .rename(let originalName):
            newTagName = originalName
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
