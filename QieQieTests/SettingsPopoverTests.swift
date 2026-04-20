import AppKit
import SwiftUI
import SwiftData
import Vision
import XCTest
@testable import QieQie

@MainActor
final class SettingsPopoverTests: XCTestCase {
    func testTransientPopoverToggleGateSuppressesImmediateReopenAfterDismiss() {
        var gate = TransientPopoverToggleGate(suppressionInterval: 0.25)
        let dismissedAt = Date(timeIntervalSinceReferenceDate: 100)

        gate.recordDismiss(at: dismissedAt)

        XCTAssertTrue(gate.consumeDismissIfNeeded(at: dismissedAt.addingTimeInterval(0.05)))
        XCTAssertNil(gate.lastDismissedAt)
    }

    func testTransientPopoverToggleGateAllowsLaterToggle() {
        var gate = TransientPopoverToggleGate(suppressionInterval: 0.25)
        let dismissedAt = Date(timeIntervalSinceReferenceDate: 100)

        gate.recordDismiss(at: dismissedAt)

        XCTAssertFalse(gate.consumeDismissIfNeeded(at: dismissedAt.addingTimeInterval(0.3)))
        XCTAssertEqual(gate.lastDismissedAt, dismissedAt)
    }

    func testMainPanelShowsQuickFocusDurationShortcut() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        let host = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: manager)
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("25:00"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("专注时长"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testQuickFocusDurationShortcutReflectsConfigurationChanges() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        let host = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: manager)
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        var configuration = manager.configuration
        configuration.focusDuration = 40 * 60
        manager.updateConfiguration(configuration)
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("40:00"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("专注时长"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testMainPanelShowsTagSelectorAndNoteField() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        manager.updateSelectedTagName("开发")
        manager.updateCurrentTaskName("整理需求")
        let host = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: manager)
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let taskField = try XCTUnwrap(findEditableTextFields(in: host.view).first)
        XCTAssertEqual(taskField.stringValue, "整理需求")
        XCTAssertEqual(taskField.placeholderString, "补充说明")

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)
        XCTAssertTrue(recognizedText.contains("开发"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testCategoryPickerTagRowProvidesContextMenuWithoutBeingSelected() throws {
        let host = NSHostingController(
            rootView: CategoryPickerTagRowView(
                title: "开发",
                isSelected: false,
                accessibilityIdentifier: "categoryPicker.row.开发",
                onSelect: {},
                onRename: {},
                onDelete: {}
            )
        )
        let window = makeWindow(size: CGSize(width: 188, height: 40))

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let categoryRow = try XCTUnwrap(
            findView(
                in: host.view,
                matchingIdentifier: "categoryPicker.row.开发"
            )
        )
        let menu = try XCTUnwrap(categoryRow.menu(for: makeRightMouseEvent(windowNumber: window.windowNumber)))

        XCTAssertEqual(menu.items.map(\.title), ["重命名分类…", "删除分类"])
        XCTAssertTrue(menu.items.allSatisfy(\.isEnabled))

        window.orderOut(nil)
    }

    func testCategoryPickerTagRowInvokesSelectionOnLeftClick() throws {
        var didSelect = false
        let host = NSHostingController(
            rootView: CategoryPickerTagRowView(
                title: "开发",
                isSelected: false,
                accessibilityIdentifier: "categoryPicker.row.开发",
                onSelect: { didSelect = true },
                onRename: {},
                onDelete: {}
            )
        )
        let window = makeWindow(size: CGSize(width: 188, height: 40))

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let categoryRow = try XCTUnwrap(
            findView(
                in: host.view,
                matchingIdentifier: "categoryPicker.row.开发"
            )
        )
        categoryRow.mouseDown(with: makeLeftMouseEvent(windowNumber: window.windowNumber))

        XCTAssertTrue(didSelect)

        window.orderOut(nil)
    }

    func testMainPanelHidesRemovedSummaryCard() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        let host = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: manager)
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("今日"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("本周"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("时间显示在状态栏"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("自动切换"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("查看统计"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testMainPanelKeepsBottomControlsVisibleAfterHeightTrim() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        let host = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: manager)
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("开始"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("跳过"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testConfigurationFieldsReflectManagerSettings() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        let host = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: manager,
                initialPanel: .settings
            )
        )
        let window = makeWindow(size: SettingsPopoverLayout.settingsSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        manager.updateConfiguration(
            FocusTimerConfiguration(
                focusDuration: 30 * 60,
                shortBreakDuration: 7 * 60,
                longBreakDuration: 20 * 60,
                longBreakInterval: 3,
                autoStartBreak: false,
                autoStartNextFocus: true
            )
        )
        pumpMainRunLoop()

        let textFieldValues = findTextFields(in: host.view).map(\.stringValue)
        XCTAssertTrue(textFieldValues.contains("30"))
        XCTAssertTrue(textFieldValues.contains("7"))
        XCTAssertTrue(textFieldValues.contains("20"))
        XCTAssertTrue(textFieldValues.contains("3"))

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)
        XCTAssertTrue(recognizedText.contains("返回"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("自动开始下个番茄"), "Recognized text: \(recognizedText)")
        XCTAssertGreaterThanOrEqual(findSwitches(in: host.view).count, 2)

        window.orderOut(nil)
    }

    func testFreshSettingsPanelDefaultsAutoOptionsToOff() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        let host = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: manager,
                initialPanel: .settings
            )
        )
        let window = makeWindow(size: SettingsPopoverLayout.settingsSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let switches = findSwitches(in: host.view)
        XCTAssertEqual(switches.count, 2)
        XCTAssertTrue(switches.allSatisfy { $0.state == .off })

        window.orderOut(nil)
    }

    func testMainPanelUsesStartBreakLabelWhenBreakIsWaitingToBeStarted() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        manager.state = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartBreak: false),
            currentPhase: .shortBreak,
            cycleFocusCount: 1,
            phaseDuration: 5 * 60,
            endTime: nil,
            isPaused: false,
            pausedAt: nil
        )
        let host = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: manager)
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("开始休息"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testSkipButtonKeepsPausedStateAcrossPhaseChangeInPopover() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        let pausedAt = Date()
        manager.state = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartBreak: false, autoStartNextFocus: false),
            currentPhase: .focus,
            cycleFocusCount: 0,
            phaseDuration: 25 * 60,
            endTime: pausedAt.addingTimeInterval(20 * 60),
            isPaused: true,
            pausedAt: pausedAt
        )

        let host = NSHostingController(
            rootView: SettingsPopover(focusTimerManager: manager)
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)
        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        manager.skipCurrentPhase()
        pumpMainRunLoop()

        XCTAssertEqual(manager.state.currentPhase, .shortBreak)
        XCTAssertEqual(manager.state.status, .paused)

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)
        XCTAssertTrue(recognizedText.contains("继续"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("暂停"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testStatisticsWindowContentUsesStandaloneLayout() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FocusSession.self,
            FocusTagRecord.self,
            configurations: configuration
        )
        let historyManager = FocusHistoryManager(modelContainer: container)
        let host = NSHostingController(
            rootView: HistoryView(historyManager: historyManager)
        )
        let window = makeWindow(size: StatisticsWindowLayout.defaultSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("概览"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("专注详情"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("专注记录"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("返回"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testHistoryViewRefreshesWhenReopened() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FocusSession.self,
            FocusTagRecord.self,
            configurations: configuration
        )
        let historyManager = FocusHistoryManager(modelContainer: container)
        let initialHost = NSHostingController(rootView: HistoryView(historyManager: historyManager))
        let window = makeWindow(size: StatisticsWindowLayout.defaultSize)

        window.contentViewController = initialHost
        window.makeKeyAndOrderFront(nil)
        _ = initialHost.view
        initialHost.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        historyManager.recordCompletedFocus(
            duration: 40 * 60,
            taskName: "ReloadCheck",
            completedAt: Date()
        )
        let reopenedHost = NSHostingController(rootView: HistoryView(historyManager: historyManager))
        window.contentViewController = reopenedHost
        pumpMainRunLoop()
        _ = reopenedHost.view
        reopenedHost.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: reopenedHost.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("ReloadCheck"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("40m"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("当前周期没有已完成的专注记录"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testStatisticsOverviewPanelShowsSummaryAndRecentRecord() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FocusSession.self,
            FocusTagRecord.self,
            configurations: configuration
        )
        let historyManager = FocusHistoryManager(modelContainer: container)
        let completedAt = Date(timeIntervalSinceReferenceDate: 10_000)
        historyManager.recordCompletedFocus(
            duration: 40 * 60,
            taskName: "毕设",
            completedAt: completedAt
        )

        let manager = FocusTimerManager(
            focusHistoryManager: historyManager,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let host = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: manager,
                initialPanel: .statistics,
                onOpenStatistics: {}
            )
        )
        let window = makeWindow(size: SettingsPopoverLayout.statisticsSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertTrue(recognizedText.contains("今日番茄"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("总专注时长"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testBreakCountdownUsesGreenStatusBarTint() {
        XCTAssertNil(StatusBarManager.countdownTintColor(for: .focus))
        XCTAssertTrue(StatusBarManager.countdownTintColor(for: .shortBreak)?.isEqual(NSColor.systemGreen) == true)
        XCTAssertTrue(StatusBarManager.countdownTintColor(for: .longBreak)?.isEqual(NSColor.systemGreen) == true)
    }

    func testStatusBarCountdownDoesNotPinForegroundColor() throws {
        let manager = FocusTimerManager(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let statusBarManager = StatusBarManager(focusTimerManager: manager)
        let pausedAt = Date()

        manager.state = FocusTimerState(
            configuration: .default,
            currentPhase: .focus,
            cycleFocusCount: 0,
            phaseDuration: 25 * 60,
            endTime: pausedAt.addingTimeInterval(25 * 60),
            isPaused: true,
            pausedAt: pausedAt
        )
        pumpMainRunLoop()

        let button = try XCTUnwrap(statusBarButton(from: statusBarManager))
        XCTAssertEqual(button.title, "25:00")
        XCTAssertNil(button.contentTintColor)
        XCTAssertNil(button.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil))
    }

    func testIdleBreakShowsPendingBreakCountdownInStatusBar() throws {
        let manager = FocusTimerManager(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let statusBarManager = StatusBarManager(focusTimerManager: manager)

        manager.state = FocusTimerState(
            configuration: FocusTimerConfiguration(autoStartBreak: false),
            currentPhase: .shortBreak,
            cycleFocusCount: 1,
            phaseDuration: 5 * 60,
            endTime: nil,
            isPaused: false,
            pausedAt: nil
        )
        pumpMainRunLoop()

        let button = try XCTUnwrap(statusBarButton(from: statusBarManager))
        XCTAssertNotNil(button.image)
        let renderedImage = try XCTUnwrap(renderImage(from: button))
        XCTAssertTrue(imageContainsGreenPixels(renderedImage))
    }

    func testRunningBreakUsesGreenForegroundColorInStatusBar() throws {
        let manager = FocusTimerManager(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let statusBarManager = StatusBarManager(focusTimerManager: manager)
        let now = Date()

        manager.state = FocusTimerState(
            configuration: .default,
            currentPhase: .shortBreak,
            cycleFocusCount: 1,
            phaseDuration: 5 * 60,
            endTime: now.addingTimeInterval(5 * 60),
            isPaused: false,
            pausedAt: nil
        )
        pumpMainRunLoop()

        let button = try XCTUnwrap(statusBarButton(from: statusBarManager))
        XCTAssertNotNil(button.image)
        let renderedImage = try XCTUnwrap(renderImage(from: button))
        XCTAssertTrue(imageContainsGreenPixels(renderedImage))
    }

    func testPopoverLayoutUsesUpdatedMainPanelAndLargerStatisticsWindow() {
        XCTAssertGreaterThan(SettingsPopoverLayout.mainSize.width, FocusPanelLayout.unifiedPanelSize.width)
        XCTAssertGreaterThan(SettingsPopoverLayout.mainSize.height, FocusPanelLayout.unifiedPanelSize.height)
        XCTAssertGreaterThanOrEqual(SettingsPopoverLayout.settingsSize.width, FocusPanelLayout.unifiedPanelSize.width)
        XCTAssertGreaterThanOrEqual(SettingsPopoverLayout.statisticsSize.width, FocusPanelLayout.unifiedPanelSize.width)
        XCTAssertGreaterThan(StatisticsWindowLayout.defaultSize.width, SettingsPopoverLayout.statisticsSize.width)
        XCTAssertGreaterThan(StatisticsWindowLayout.defaultSize.height, SettingsPopoverLayout.statisticsSize.height)
        XCTAssertLessThanOrEqual(StatisticsWindowLayout.minSize.width, StatisticsWindowLayout.defaultSize.width)
        XCTAssertLessThanOrEqual(StatisticsWindowLayout.minSize.height, StatisticsWindowLayout.defaultSize.height)
    }

    func testPreferredSizeCallbackMatchesCurrentPanel() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
        var mainReportedSize: CGSize?
        var settingsReportedSize: CGSize?

        let mainHost = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: manager,
                onPreferredSizeChange: { mainReportedSize = $0 }
            )
        )
        let mainWindow = makeWindow(size: SettingsPopoverLayout.mainSize)
        mainWindow.contentViewController = mainHost
        mainWindow.makeKeyAndOrderFront(nil)
        _ = mainHost.view
        mainHost.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let unwrappedMainReportedSize = try XCTUnwrap(mainReportedSize)
        XCTAssertEqual(unwrappedMainReportedSize.width, SettingsPopoverLayout.mainSize.width, accuracy: 0.5)
        XCTAssertEqual(unwrappedMainReportedSize.height, SettingsPopoverLayout.mainSize.height, accuracy: 0.5)

        let settingsHost = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: manager,
                initialPanel: .settings,
                onPreferredSizeChange: { settingsReportedSize = $0 }
            )
        )
        let settingsWindow = makeWindow(size: SettingsPopoverLayout.settingsSize)
        settingsWindow.contentViewController = settingsHost
        settingsWindow.makeKeyAndOrderFront(nil)
        _ = settingsHost.view
        settingsHost.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let unwrappedSettingsReportedSize = try XCTUnwrap(settingsReportedSize)
        XCTAssertEqual(unwrappedSettingsReportedSize.width, SettingsPopoverLayout.settingsSize.width, accuracy: 0.5)
        XCTAssertEqual(unwrappedSettingsReportedSize.height, SettingsPopoverLayout.settingsSize.height, accuracy: 0.5)

        var statisticsReportedSize: CGSize?
        let statisticsHost = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: manager,
                initialPanel: .statistics,
                onPreferredSizeChange: { statisticsReportedSize = $0 }
            )
        )
        let statisticsWindow = makeWindow(size: SettingsPopoverLayout.statisticsSize)
        statisticsWindow.contentViewController = statisticsHost
        statisticsWindow.makeKeyAndOrderFront(nil)
        _ = statisticsHost.view
        statisticsHost.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let unwrappedStatisticsReportedSize = try XCTUnwrap(statisticsReportedSize)
        XCTAssertEqual(unwrappedStatisticsReportedSize.width, SettingsPopoverLayout.statisticsSize.width, accuracy: 0.5)
        XCTAssertEqual(unwrappedStatisticsReportedSize.height, SettingsPopoverLayout.statisticsSize.height, accuracy: 0.5)

        mainWindow.orderOut(nil)
        settingsWindow.orderOut(nil)
        statisticsWindow.orderOut(nil)
    }

    func testMainPanelDoesNotShowStatisticsEntryWhenWindowActionIsAvailable() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FocusSession.self,
            FocusTagRecord.self,
            configurations: configuration
        )
        let historyManager = FocusHistoryManager(modelContainer: container)
        let manager = FocusTimerManager(
            focusHistoryManager: historyManager,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let host = NSHostingController(
            rootView: SettingsPopover(
                focusTimerManager: manager,
                onOpenStatistics: {}
            )
        )
        let window = makeWindow(size: SettingsPopoverLayout.mainSize)

        window.contentViewController = host
        window.makeKeyAndOrderFront(nil)
        _ = host.view
        host.view.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        let renderedImage = try XCTUnwrap(renderImage(from: host.view))
        let recognizedText = try recognizedText(in: renderedImage)

        XCTAssertFalse(recognizedText.contains("查看统计"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testStatusBarManagerShowsStandaloneStatisticsWindow() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FocusSession.self,
            FocusTagRecord.self,
            configurations: configuration
        )
        let historyManager = FocusHistoryManager(modelContainer: container)
        let manager = FocusTimerManager(
            focusHistoryManager: historyManager,
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let statusBarManager = StatusBarManager(focusTimerManager: manager)

        XCTAssertFalse(statusBarManager.isStatisticsWindowShown)

        statusBarManager.showStatisticsWindow()
        pumpMainRunLoop()

        XCTAssertTrue(statusBarManager.isStatisticsWindowShown)

        statusBarManager.closeStatisticsWindow()
        pumpMainRunLoop()

        XCTAssertFalse(statusBarManager.isStatisticsWindowShown)
    }

    private func makeWindow(size: CGSize) -> NSWindow {
        NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
    }

    private func pumpMainRunLoop() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    private func statusBarButton(from statusBarManager: StatusBarManager) -> NSStatusBarButton? {
        let mirror = Mirror(reflecting: statusBarManager)
        let statusItem = mirror.children.first { $0.label == "statusItem" }?.value as? NSStatusItem
        return statusItem?.button
    }

    private func findTextFields(in view: NSView) -> [NSTextField] {
        var matches: [NSTextField] = []
        if let textField = view as? NSTextField {
            matches.append(textField)
        }

        for subview in view.subviews {
            matches.append(contentsOf: findTextFields(in: subview))
        }

        return matches
    }

    private func findEditableTextFields(in view: NSView) -> [NSTextField] {
        findTextFields(in: view).filter(\.isEditable)
    }

    private func findView(in view: NSView, matchingIdentifier identifier: String) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }

        for subview in view.subviews {
            if let match = findView(in: subview, matchingIdentifier: identifier) {
                return match
            }
        }

        return nil
    }

    private func findButtons(in view: NSView) -> [NSButton] {
        var matches: [NSButton] = []
        if let button = view as? NSButton {
            matches.append(button)
        }

        for subview in view.subviews {
            matches.append(contentsOf: findButtons(in: subview))
        }

        return matches
    }

    private func makeRightMouseEvent(windowNumber: Int) -> NSEvent {
        NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: NSPoint(x: 12, y: 12),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    private func makeLeftMouseEvent(windowNumber: Int) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 12, y: 12),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    private func findSwitches(in view: NSView) -> [NSSwitch] {
        var matches: [NSSwitch] = []
        if let toggle = view as? NSSwitch {
            matches.append(toggle)
        }

        for subview in view.subviews {
            matches.append(contentsOf: findSwitches(in: subview))
        }

        return matches
    }

    private func renderImage(from view: NSView) -> CGImage? {
        let bounds = view.bounds
        guard
            let representation = view.bitmapImageRepForCachingDisplay(in: bounds)
        else {
            return nil
        }

        view.cacheDisplay(in: bounds, to: representation)
        return representation.cgImage
    }

    private func imageContainsGreenPixels(_ image: CGImage) -> Bool {
        guard let dataProvider = image.dataProvider, let data = dataProvider.data else {
            return false
        }

        let bytes = CFDataGetBytePtr(data)
        let length = CFDataGetLength(data)

        for index in stride(from: 0, to: length, by: 4) {
            let red = Int(bytes![index])
            let green = Int(bytes![index + 1])
            let blue = Int(bytes![index + 2])
            let alpha = Int(bytes![index + 3])

            if alpha > 0, green > 80, green > red + 30, green > blue + 20 {
                return true
            }
        }

        return false
    }

    private func recognizedText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let observations = request.results ?? []
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }
}
