import SwiftUI

struct SettingsPopoverMainPanel<CategoryPickerContent: View>: View {
    let phaseTitle: String
    let progressText: String
    let canShowStatistics: Bool
    let formattedFocusDuration: String
    @Binding var isQuickFocusDurationEditorPresented: Bool
    @Binding var quickFocusMinutes: String
    var quickFocusDurationFieldFocused: FocusState<Bool>.Binding
    let canApplyQuickFocusDuration: Bool
    let taskName: Binding<String>
    @Binding var isTagEditorPresented: Bool
    let tagEditorMode: SettingsPopoverTagEditorMode
    @Binding var newTagName: String
    var tagEditorFieldFocused: FocusState<Bool>.Binding
    let canSubmitTagEditor: Bool
    let dashboardStats: FocusStatistics
    let mainButtonTitle: String
    let mainButtonIcon: String
    let canSkip: Bool
    let canReset: Bool
    let onOpenSettings: () -> Void
    let onOpenStatistics: () -> Void
    let onToggleQuickFocusDurationEditor: () -> Void
    let onPrepareQuickFocusDurationEditor: () -> Void
    let onDismissQuickFocusDurationEditor: () -> Void
    let onApplyQuickFocusDuration: () -> Void
    let onPrepareTagEditor: () -> Void
    let onDismissTagEditor: () -> Void
    let onSubmitTagEditor: () -> Void
    let onMainButton: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void
    let categoryPickerField: () -> CategoryPickerContent

    var body: some View {
        VStack(spacing: FocusPanelSpacing.md) {
            PopoverHeaderBar(
                title: phaseTitle,
                titleAccessibilityID: FocusTimerAccessibilityID.SettingsPopover.phaseTitle
            ) {
                Text(progressText)
                    .font(FocusPanelTypography.supportingText)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.progressLabel)

                Button(action: onOpenSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .font(FocusPanelTypography.controlIcon)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.settingsButton)

                Button(action: onOpenStatistics) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(FocusPanelTypography.controlIcon)
                }
                .buttonStyle(.plain)
                .disabled(!canShowStatistics)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.statisticsButton)
            }

            Button(action: onToggleQuickFocusDurationEditor) {
                Text(formattedFocusDuration)
                    .font(FocusPanelTypography.timerValue)
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FocusPanelSpacing.sm)
                    .focusPanelFieldSurface(cornerRadius: FocusPanelCornerRadius.large)
            }
            .buttonStyle(.plain)
            .popover(
                isPresented: $isQuickFocusDurationEditorPresented,
                attachmentAnchor: .point(.bottom),
                arrowEdge: .top
            ) {
                SettingsPopoverQuickFocusDurationEditor(
                    quickFocusMinutes: $quickFocusMinutes,
                    quickFocusDurationFieldFocused: quickFocusDurationFieldFocused,
                    canApplyQuickFocusDuration: canApplyQuickFocusDuration,
                    onPrepare: onPrepareQuickFocusDurationEditor,
                    onDismiss: onDismissQuickFocusDurationEditor,
                    onApply: onApplyQuickFocusDuration
                )
            }
            .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationButton)

            SettingsPopoverTaskMetadataSection(
                taskName: taskName,
                isTagEditorPresented: $isTagEditorPresented,
                categoryPickerField: categoryPickerField
            ) {
                SettingsPopoverTagEditor(
                    mode: tagEditorMode,
                    newTagName: $newTagName,
                    tagEditorFieldFocused: tagEditorFieldFocused,
                    canSubmitTagEditor: canSubmitTagEditor,
                    onPrepare: onPrepareTagEditor,
                    onDismiss: onDismissTagEditor,
                    onSubmit: onSubmitTagEditor
                )
            }

            SettingsPopoverStatisticsSummarySection(statistics: dashboardStats)

            SettingsPopoverControlSection(
                mainButtonTitle: mainButtonTitle,
                mainButtonIcon: mainButtonIcon,
                canSkip: canSkip,
                canReset: canReset,
                onMainButton: onMainButton,
                onSkip: onSkip,
                onReset: onReset
            )
        }
        .padding(FocusPanelChrome.compactPadding)
        .frame(
            width: SettingsPopoverLayout.mainSize.width,
            height: SettingsPopoverLayout.mainSize.height,
            alignment: .top
        )
    }
}

private struct SettingsPopoverQuickFocusDurationEditor: View {
    @Binding var quickFocusMinutes: String
    var quickFocusDurationFieldFocused: FocusState<Bool>.Binding
    let canApplyQuickFocusDuration: Bool
    let onPrepare: () -> Void
    let onDismiss: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: FocusPanelSpacing.lg) {
            HStack(spacing: FocusPanelSpacing.md) {
                TextField("", text: $quickFocusMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 108)
                    .multilineTextAlignment(.center)
                    .focused(quickFocusDurationFieldFocused)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationField)
                    .onChange(of: quickFocusMinutes) { _, newValue in
                        quickFocusMinutes = FocusTimerDurationParser.sanitizeNumericInput(
                            newValue,
                            maxLength: 3
                        )
                    }
                    .onSubmit(onApply)

                Text("分钟")
                    .font(FocusPanelTypography.bodyLabel)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: FocusPanelSpacing.sm) {
                Button("取消", role: .cancel, action: onDismiss)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationCancelButton)

                Button("确定", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!canApplyQuickFocusDuration)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationConfirmButton)
            }
        }
        .padding(FocusPanelSpacing.xl)
        .frame(width: 196)
        .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.quickFocusDurationEditor)
        .onAppear {
            onPrepare()
            Task { @MainActor in
                quickFocusDurationFieldFocused.wrappedValue = true
            }
        }
    }
}

private struct SettingsPopoverTaskMetadataSection<
    CategoryPickerContent: View,
    TagEditorContent: View
>: View {
    let taskName: Binding<String>
    @Binding var isTagEditorPresented: Bool
    let categoryPickerField: () -> CategoryPickerContent
    let tagEditor: () -> TagEditorContent

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.xs) {
            Text("分类与说明")
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)

            HStack(spacing: FocusPanelSpacing.sm) {
                categoryPickerField()

                TextField("补充说明", text: taskName)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.taskNameField)
                    .padding(.horizontal, FocusPanelSpacing.md)
                    .frame(height: FocusPanelControl.fieldHeight)
                    .focusPanelFieldSurface(cornerRadius: FocusPanelCornerRadius.large)
            }
        }
        .popover(
            isPresented: $isTagEditorPresented,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            tagEditor()
        }
    }
}

private struct SettingsPopoverTagEditor: View {
    let mode: SettingsPopoverTagEditorMode
    @Binding var newTagName: String
    var tagEditorFieldFocused: FocusState<Bool>.Binding
    let canSubmitTagEditor: Bool
    let onPrepare: () -> Void
    let onDismiss: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.lg) {
            Text(mode.title)
                .font(FocusPanelTypography.sectionTitle)

            TextField(mode.placeholder, text: $newTagName)
                .textFieldStyle(.roundedBorder)
                .focused(tagEditorFieldFocused)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.tagEditorField)
                .onChange(of: newTagName) { _, newValue in
                    newTagName = FocusTagCatalog.sanitize(
                        newValue,
                        maxLength: FocusTagCatalog.maxTagLength
                    )
                }
                .onSubmit(onSubmit)

            HStack(spacing: FocusPanelSpacing.sm) {
                Button("取消", role: .cancel, action: onDismiss)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button(mode.confirmTitle, action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmitTagEditor)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(FocusPanelSpacing.xl)
        .frame(width: 208)
        .onAppear {
            onPrepare()
            Task { @MainActor in
                tagEditorFieldFocused.wrappedValue = true
            }
        }
    }
}

private struct SettingsPopoverStatisticsSummarySection: View {
    let statistics: FocusStatistics

    var body: some View {
        FocusPanelGroup {
            VStack(alignment: .leading, spacing: FocusPanelSpacing.sm) {
                statisticsRow(title: "今日", period: statistics.today)
                statisticsRow(title: "本周", period: statistics.week)
            }
        }
    }

    private func statisticsRow(title: String, period: FocusStatisticsPeriod) -> some View {
        HStack(spacing: FocusPanelSpacing.lg) {
            Text("\(title):")
                .font(FocusPanelTypography.supportingText)
                .foregroundColor(.secondary)
            Spacer(minLength: FocusPanelSpacing.lg)
            Text(FocusDisplayFormatter.summaryDuration(period.totalDuration))
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }
}

private struct SettingsPopoverControlSection: View {
    let mainButtonTitle: String
    let mainButtonIcon: String
    let canSkip: Bool
    let canReset: Bool
    let onMainButton: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: FocusPanelSpacing.xs) {
            Button(action: onMainButton) {
                HStack(spacing: FocusPanelSpacing.xs) {
                    Image(systemName: mainButtonIcon)
                    Text(mainButtonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.mainButton)

            HStack(spacing: FocusPanelSpacing.xs) {
                Button(action: onSkip) {
                    HStack(spacing: FocusPanelSpacing.xxs) {
                        Image(systemName: "forward.fill")
                        Text("跳过")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!canSkip)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.skipButton)

                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(!canReset)
                .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.resetButton)
            }
        }
    }
}
