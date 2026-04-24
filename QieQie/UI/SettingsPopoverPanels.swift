import SwiftUI

private enum SettingsPanelTypography {
    static let sectionTitle = Font.system(size: 14, weight: .semibold)
    static let rowLabel = Font.system(size: 13, weight: .medium)
    static let suffixLabel = Font.system(size: 12, weight: .medium)
}

private enum SettingsPanelMetrics {
    static let sectionSpacing: CGFloat = FocusPanelSpacing.md
    static let sectionContentSpacing: CGFloat = 4
    static let rowSpacing: CGFloat = 4
    static let rowVerticalPadding: CGFloat = 4
    static let inputHeight: CGFloat = 24
}

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
            .padding(.horizontal, FocusPanelChrome.compactPadding)
            .padding(.top, FocusPanelSpacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SettingsPanelMetrics.sectionSpacing) {
                    settingsSection(title: "计时选项") {
                        SettingsPopoverOptionList {
                            SettingsPopoverInputRow(
                                title: "番茄时长",
                                value: $focusMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.focusMinutesField,
                                onCommit: onFocusDurationChange
                            )

                            SettingsPopoverInputRow(
                                title: "短休息时长",
                                value: $shortBreakMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.shortBreakMinutesField,
                                onCommit: onShortBreakDurationChange
                            )

                            SettingsPopoverInputRow(
                                title: "长休息时长",
                                value: $longBreakMinutes,
                                suffix: "分钟",
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.longBreakMinutesField,
                                onCommit: onLongBreakDurationChange
                            )

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
                        SettingsPopoverOptionList {
                            SettingsPopoverToggleRow(
                                title: "自动开始下个番茄",
                                isOn: autoStartNextFocusBinding,
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.autoStartNextFocusToggle
                            )

                            SettingsPopoverToggleRow(
                                title: "自动开始休息",
                                isOn: autoStartBreakBinding,
                                accessibilityID: FocusTimerAccessibilityID.SettingsPopover.autoStartBreakToggle
                            )
                        }
                    }
                }
                .padding(.horizontal, FocusPanelChrome.compactPadding)
                .padding(.bottom, FocusPanelSpacing.xxs)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
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
        FocusPanelSection(title: title, contentSpacing: SettingsPanelMetrics.sectionContentSpacing) {
            FocusPanelGroup(
                horizontalPadding: 0,
                verticalPadding: FocusPanelSpacing.xs
            ) {
                content()
            }
        }
        .font(SettingsPanelTypography.sectionTitle)
    }
}

private struct SettingsPopoverOptionList<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: SettingsPanelMetrics.rowSpacing) {
            content()
        }
    }
}

private struct SettingsPopoverOptionRow<Accessory: View>: View {
    let title: String
    let labelWidth: CGFloat
    private let accessory: () -> Accessory

    init(
        title: String,
        labelWidth: CGFloat,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.labelWidth = labelWidth
        self.accessory = accessory
    }

    var body: some View {
        FocusPanelFormRow(
            title: title,
            labelWidth: labelWidth,
            verticalPadding: SettingsPanelMetrics.rowVerticalPadding
        ) {
            accessory()
        }
        .font(SettingsPanelTypography.rowLabel)
    }
}

struct SettingsPopoverStatisticsPanel: View {
    let canOpenStatisticsDetail: Bool
    let dashboardStats: FocusStatistics
    let recentSessions: [FocusSession]
    let onBack: () -> Void
    let onOpenStatistics: () -> Void

    var body: some View {
        VStack(spacing: FocusPanelSpacing.md) {
            PopoverHeaderBar(
                title: "统计概览",
                backAccessibilityID: FocusTimerAccessibilityID.SettingsPopover.backButton,
                onBack: onBack
            ) {
                Button(action: onOpenStatistics) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(FocusPanelTypography.controlIcon)
                }
                .buttonStyle(.plain)
                .help("打开完整统计")
                .disabled(!canOpenStatisticsDetail)
                .accessibilityLabel("打开完整统计")
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.statisticsDetailButton)
            }

            StatisticsOverviewView(
                statistics: dashboardStats,
                recentSessions: Array(recentSessions.prefix(30))
            )
        }
        .padding(FocusPanelChrome.compactPadding)
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
        SettingsPopoverOptionRow(title: title, labelWidth: 82) {
            HStack(spacing: FocusPanelSpacing.xs) {
                TextField("", text: $value)
                    .textFieldStyle(.plain)
                    .font(SettingsPanelTypography.rowLabel)
                    .frame(width: FocusPanelControl.numericFieldWidth, height: SettingsPanelMetrics.inputHeight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FocusPanelSpacing.xs)
                    .focusPanelFieldSurface(cornerRadius: FocusPanelCornerRadius.large)
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
                    .font(SettingsPanelTypography.suffixLabel)
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
        SettingsPopoverOptionRow(title: title, labelWidth: 112) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .accessibilityIdentifier(accessibilityID)
        }
    }
}
