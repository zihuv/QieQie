# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **macOS menu bar application** (menubar app) built with SwiftUI. It's a countdown utility that runs entirely in the system menu bar without appearing in the Dock. The app uses only native Apple frameworks—no external dependencies.

## Build and Run Commands

### Quick Build (推荐)

使用项目根目录的构建脚本：

```bash
# 编译 Debug 版本（默认）
./build.sh

# 编译 Release 版本（优化后）
./build.sh Release

# 运行应用
./build/run.sh
# 或双击 build/countdown.app
```

构建产物位于 `build/countdown.app`，可以直接双击运行或分发。

### Building the Project (手动编译)

```bash
# 方法1: 使用 xcodebuild 直接编译
xcodebuild -project timer/timer.xcodeproj -scheme countdown -configuration Debug build

# 方法2: 进入 timer 目录编译
cd timer
xcodebuild -project timer.xcodeproj -scheme countdown -configuration Release build
```

### Running the Application

```bash
# 方法1: 使用构建脚本
./build/run.sh

# 方法2: 直接打开 .app 文件
open build/countdown.app

# 方法3: 从 Xcode DerivedData 打开
open ~/Library/Developer/Xcode/DerivedData/countdown-*/Build/Products/Debug/countdown.app

# 方法4: 在 Xcode 中运行
open timer/timer.xcodeproj  # 然后按 ⌘R
```

### Regenerating the Xcode Project

If you modify the project structure or need to regenerate the Xcode project file:

```bash
cd timer
./create_project.sh
```

The `create_project.sh` script programmatically generates the `timer.xcodeproj/project.pbxproj` file with all necessary build configurations, source file references, and settings.

## Architecture

### Application Structure

The app follows a clean SwiftUI architecture with clear separation of concerns:

```
countdownApp (Entry Point)
    └── AppDelegate (Lifecycle Management)
            ├── CountdownManager (Core Logic)
            └── StatusBarManager (UI Layer)
                    └── SettingsPopover (Settings UI)
```

### Key Components

**1. countdownApp.swift** (`timer/timer/countdownApp.swift`)
- SwiftUI App entry point with `@main` attribute
- Uses `@NSApplicationDelegateAdaptor` to inject AppDelegate
- Contains empty Settings scene to prevent automatic window creation

**2. AppDelegate.swift** (`timer/timer/AppDelegate.swift`)
- Application lifecycle management
- Initializes CountdownManager and StatusBarManager during `applicationDidFinishLaunching`
- Sets activation policy to `.accessory` (required for menubar-only apps)
- Ensures app doesn't terminate when windows close

**3. CountdownManager.swift** (`timer/timer/CountdownManager.swift`)
- **Core business logic** for countdown functionality
- Uses `@Published var state` to publish countdown state changes
- Maintains single source of truth: `endTime: Date?`
- Implements Timer-based updates every second
- Provides `startCountdown(duration:)` and `resetCountdown()` methods
- Automatically stops timer when countdown reaches zero

**4. CountdownState.swift** (`timer/timer/CountdownState.swift`)
- Immutable data model with value semantics
- Contains `endTime: Date?` as the core state
- Computed properties:
  - `status`: returns `.idle`, `.running`, or `.finished`
  - `remainingTime: TimeInterval?`: calculated from `endTime - Date()`
- State transitions are explicit: new state objects are created to trigger `@Published` updates

**5. StatusBarManager.swift** (`timer/timer/StatusBarManager.swift`)
- Manages `NSStatusItem` for menubar integration
- Updates menubar title based on countdown state (🕐, formatted time, or "Done")
- Handles menu actions (Settings, Reset, Quit)
- Shows/hides SettingsPopover on menubar item click
- Uses Combine framework to subscribe to CountdownManager state changes

**6. SettingsPopover.swift** (`timer/timer/SettingsPopover.swift`)
- SwiftUI view for time input (minutes:seconds format)
- Validates user input before starting countdown
- Calls `CountdownManager.startCountdown()` with validated duration
- Handles invalid input gracefully

### Data Flow

```
User Input (SettingsPopover)
    → CountdownManager.startCountdown(duration:)
    → Updates state.endTime
    → @Published triggers update
    → StatusBarManager receives update via Combine
    → Updates NSStatusItem title
    → Timer fires every second
    → CountdownManager.updateState() creates new state object
    → Triggers UI update
```

### State Management Pattern

The app uses a **unidirectional data flow** pattern:

1. **State is immutable**: Each state change creates a new `CountdownState` object
2. **Single source of truth**: All timing logic derives from `endTime: Date?`
3. **Reactive updates**: Combine framework propagates changes from CountdownManager to StatusBarManager
4. **Explicit updates**: Reassigning entire `state` object triggers `@Published` updates (not just individual properties)

### Menubar App Configuration

Two critical configurations make this a menubar-only app:

1. **Info.plist** (`timer/timer/Info.plist:25-26`):
   ```xml
   <key>LSUIElement</key>
   <true/>
   ```
   Prevents Dock icon appearance

2. **AppDelegate** (`timer/timer/AppDelegate.swift:26`):
   ```swift
   NSApp.setActivationPolicy(.accessory)
   ```
   Sets app as auxiliary (menubar-only)

Both are required—neither alone is sufficient.

### Timer Lifecycle

1. **Idle State**: `state.endTime == nil`, menubar shows 🕐
2. **Start**: User sets time in SettingsPopover → calls `startCountdown(duration:)`
3. **Running**: Timer fires every second → creates new state object → triggers UI update
4. **Finished**: When `remainingTime <= 0` → timer stops → menubar shows "Done"
5. **Reset**: `resetCountdown()` clears `endTime` and stops timer

## Important Implementation Details

- **No external dependencies**: Uses only AppKit, SwiftUI, Combine, and Foundation
- **Minimum macOS version**: 12.0 (defined in project.pbxproj)
- **Swift version**: 5.0
- **App Sandbox**: Enabled (see `timer/timer/countdown.entitlements`)
- **No testing infrastructure**: No unit tests or test targets configured
- **Comments are in Chinese**: Original developer documented code in Chinese

## Development Workflow

When modifying the app:

1. **Logic changes**: Modify `CountdownManager.swift` or `CountdownState.swift`
2. **UI changes**: Modify `StatusBarManager.swift` (menubar) or `SettingsPopover.swift` (settings)
3. **Adding new source files**: Must update `create_project.sh` and regenerate `project.pbxproj`
4. **Configuration changes**: Edit Info.plist or countdown.entitlements directly
5. **Always test menubar behavior**: Since there's no Dock icon, use the menubar icon to access the app

## Common Tasks

- **Add new countdown features**: Extend `CountdownManager` methods, update `CountdownState` if new state needed
- **Modify menubar display**: Update `StatusBarManager.updateTitle()` formatting
- **Change settings UI**: Modify `SettingsPopover.swift` SwiftUI view
- **Adjust timer interval**: Change Timer interval in `CountdownManager.startTimer()` (currently 1.0 seconds)

Always use Context7 MCP when you need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.
