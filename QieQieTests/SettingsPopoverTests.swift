import AppKit
import SwiftUI
import SwiftData
import Vision
import XCTest
@testable import QieQie

@MainActor
final class SettingsPopoverTests: XCTestCase {
    func testMainPanelShowsTaskInputFieldAndCurrentTaskName() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let manager = FocusTimerManager(userDefaults: defaults)
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
        XCTAssertEqual(taskField.placeholderString, "输入任务")

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
        XCTAssertTrue(recognizedText.contains("自动开始休息"), "Recognized text: \(recognizedText)")

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

    func testStatisticsWindowContentUsesStandaloneLayout() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FocusSession.self, configurations: configuration)
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

        XCTAssertTrue(recognizedText.contains("今日"), "Recognized text: \(recognizedText)")
        XCTAssertTrue(recognizedText.contains("本周"), "Recognized text: \(recognizedText)")
        XCTAssertFalse(recognizedText.contains("返回"), "Recognized text: \(recognizedText)")

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

    func testPopoverLayoutUsesDedicatedPanelSizes() {
        XCTAssertEqual(SettingsPopoverLayout.mainSize.width, 236)
        XCTAssertEqual(SettingsPopoverLayout.mainSize.height, 220)
        XCTAssertEqual(SettingsPopoverLayout.settingsSize.width, 344)
        XCTAssertEqual(SettingsPopoverLayout.settingsSize.height, 408)
        XCTAssertEqual(StatisticsWindowLayout.defaultSize.width, 480)
        XCTAssertEqual(StatisticsWindowLayout.defaultSize.height, 420)
        XCTAssertEqual(StatisticsWindowLayout.minSize.width, 440)
        XCTAssertEqual(StatisticsWindowLayout.minSize.height, 380)
        XCTAssertLessThan(SettingsPopoverLayout.mainSize.width, SettingsPopoverLayout.settingsSize.width)
        XCTAssertLessThan(SettingsPopoverLayout.mainSize.height, SettingsPopoverLayout.settingsSize.height)
        XCTAssertGreaterThan(StatisticsWindowLayout.defaultSize.width, SettingsPopoverLayout.settingsSize.width)
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
        XCTAssertGreaterThanOrEqual(unwrappedMainReportedSize.height, SettingsPopoverLayout.mainSize.height)
        XCTAssertLessThan(unwrappedMainReportedSize.height, SettingsPopoverLayout.settingsSize.height)

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

        mainWindow.orderOut(nil)
        settingsWindow.orderOut(nil)
    }

    func testStatisticsEntryAppearsWhenWindowActionIsAvailable() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FocusSession.self, configurations: configuration)
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

        XCTAssertTrue(recognizedText.contains("查看统计"), "Recognized text: \(recognizedText)")

        window.orderOut(nil)
    }

    func testStatusBarManagerShowsStandaloneStatisticsWindow() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FocusSession.self, configurations: configuration)
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
