import SwiftUI

struct SettingsPopoverSettingsPanel: View {
    @Binding var focusMinutes: String
    @Binding var shortBreakMinutes: String
    @Binding var longBreakMinutes: String
    @Binding var longBreakInterval: String
    @Binding var autoStartNextFocus: Bool
    @Binding var autoStartBreak: Bool
    let onBack: () -> Void
    let onFocusDurationChange: () -> Void
    let onShortBreakDurationChange: () -> Void
    let onLongBreakDurationChange: () -> Void
    let onLongBreakIntervalChange: () -> Void
    let onAutoStartNextFocusChange: (Bool) -> Void
    let onAutoStartBreakChange: (Bool) -> Void

    var body: some View {
        VStack(spacing: FocusPanelSpacing.sm) {
            PopoverHeaderBar(
                title: "设置",
                backAccessibilityID: FocusTimerAccessibilityID.SettingsPopover.backButton,
                onBack: onBack
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FocusPanelSpacing.md) {
                    settingsSection(title: "计时选项") {
                        VStack(spacing: 0) {
                            SettingsPopoverInputRow(
                                title: "番茄时长",
                                value: $focusMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.focusMinutesField,
                                onCommit: onFocusDurationChange
                            )

                            FocusPanelDivider()

                            SettingsPopoverInputRow(
                                title: "短休息时长",
                                value: $shortBreakMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.shortBreakMinutesField,
                                onCommit: onShortBreakDurationChange
                            )

                            FocusPanelDivider()

                            SettingsPopoverInputRow(
                                title: "长休息时长",
                                value: $longBreakMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.longBreakMinutesField,
                                onCommit: onLongBreakDurationChange
                            )

                            FocusPanelDivider()

                            SettingsPopoverInputRow(
                                title: "长休息间隔番茄数",
                                value: $longBreakInterval,
                                suffix: "个",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.intervalField,
                                maxLength: 2,
                                upperBound: 10,
                                onCommit: onLongBreakIntervalChange
                            )
                        }
                    }

                    settingsSection(title: "自动选项") {
                        VStack(spacing: 0) {
                            SettingsPopoverToggleRow(
                                title: "自动开始下个番茄",
                                isOn: autoStartNextFocusBinding,
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.autoStartNextFocusToggle
                            )

                            FocusPanelDivider()

                            SettingsPopoverToggleRow(
                                title: "自动开始休息",
                                isOn: autoStartBreakBinding,
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.autoStartBreakToggle
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(FocusPanelSpacing.md)
        .frame(
            width: SettingsPopoverLayout.settingsSize.width,
            height: SettingsPopoverLayout.settingsSize.height,
            alignment: .top
        )
    }

    private var autoStartNextFocusBinding: Binding<Bool> {
        Binding(
            get: { autoStartNextFocus },
            set: {
                autoStartNextFocus = $0
                onAutoStartNextFocusChange($0)
            }
        )
    }

    private var autoStartBreakBinding: Binding<Bool> {
        Binding(
            get: { autoStartBreak },
            set: {
                autoStartBreak = $0
                onAutoStartBreakChange($0)
            }
        )
    }

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        FocusPanelSection(title: title) {
            FocusPanelGroup {
                content()
            }
        }
    }
}

struct SettingsPopoverStatisticsPanel: View {
    let canOpenStatisticsDetail: Bool
    let dashboardStats: FocusStatistics
    let recentSessions: [FocusSession]
    let onBack: () -> Void
    let onOpenStatistics: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeaderBar(
                title: "统计概览",
                backAccessibilityID: FocusTimerAccessibilityID.SettingsPopover.backButton,
                onBack: onBack
            ) {
                Button(action: onOpenStatistics) {
                    Text("统计")
                        .font(FocusPanelTypography.supportingText)
                }
                .buttonStyle(.plain)
                .disabled(!canOpenStatisticsDetail)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.statisticsDetailButton)
            }
            .padding(.horizontal, FocusPanelChrome.compactPadding)
            .padding(.top, FocusPanelSpacing.md)

            StatisticsOverviewView(
                statistics: dashboardStats,
                recentSessions: Array(recentSessions.prefix(30))
            )
            .padding(.top, FocusPanelSpacing.xxs)
        }
        .frame(
            width: SettingsPopoverLayout.statisticsSize.width,
            height: SettingsPopoverLayout.statisticsSize.height,
            alignment: .top
        )
    }
}

private struct SettingsPopoverInputRow: View {
    let title: String
    @Binding var value: String
    let suffix: String
    let accessibilityID: String
    let maxLength: Int
    let upperBound: Int?
    let onCommit: () -> Void

    init(
        title: String,
        value: Binding<String>,
        suffix: String,
        accessibilityID: String,
        maxLength: Int = 3,
        upperBound: Int? = nil,
        onCommit: @escaping () -> Void
    ) {
        self.title = title
        _value = value
        self.suffix = suffix
        self.accessibilityID = accessibilityID
        self.maxLength = maxLength
        self.upperBound = upperBound
        self.onCommit = onCommit
    }

    var body: some View {
        FocusPanelFormRow(title: title, labelWidth: 82) {
            HStack(spacing: FocusPanelSpacing.xs) {
                TextField("", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.mini)
                    .frame(width: FocusPanelControl.numericFieldWidth)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(accessibilityID)
                    .onChange(of: value) { _, newValue in
                        value = FocusTimerDurationParser.sanitizeNumericInput(
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
                    .frame(width: FocusPanelControl.unitLabelWidth, alignment: .leading)
            }
        }
    }
}

private struct SettingsPopoverToggleRow: View {
    let title: String
    let isOn: Binding<Bool>
    let accessibilityID: String

    var body: some View {
        FocusPanelFormRow(title: title, labelWidth: 112) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityIdentifier(accessibilityID)
        }
    }
}
