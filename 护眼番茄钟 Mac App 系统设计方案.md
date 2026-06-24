# EyePomo（暂定名）系统设计方案

> 版本：v0.1 设计稿  
> 日期：2026-06-23  
> 目标平台：macOS 13+  
> 产品方向：轻量护眼提醒 + 番茄钟专注 + 本地数据 + Markdown AI 分析

## 1. 背景与目标

EyePomo 是一个轻量 Mac 菜单栏应用，核心目标是帮助用户在长时间使用电脑时规律放松眼睛，同时用番茄钟维持基本的专注节奏。

产品不追求成为完整生产力套件，而是解决两个高频、明确、低认知负担的问题：

- 到时间提醒用户看远处，降低长时间盯屏带来的眼疲劳。
- 在需要进入工作状态时，提供简单可靠的番茄钟。

设计参考：

- [LeroyPine/happy-workdog](https://github.com/LeroyPine/happy-workdog)：参考原生 macOS、菜单栏、工作陪伴工具的实现方向，但不照搬其大而全功能边界。
- [Time Out](https://www.dejal.com/timeout/)：参考微休息和长休息模型。
- [LookAway](https://lookaway.com/)：参考护眼优先、低打扰、智能休息的产品表达。
- [BreakTimer](https://breaktimer.app/)：参考休息提醒、工作时段和跳过/稍后交互。
- [Flow](https://www.flow.app/)：参考轻量番茄钟和极简专注体验。

## 2. 产品定位

一句话定位：

> 一个安静常驻菜单栏的护眼番茄钟，用最少的按钮提醒用户规律看远方，并在需要时进入专注节奏。

核心原则：

- 护眼优先，番茄钟辅助。
- 菜单栏常驻，不占 Dock，不打扰主工作流。
- 功能轻量，默认可用，设置尽量少。
- 所有数据本地保存，不依赖账号和云服务。
- 原始数据结构化保存，自动生成 Markdown，方便本地 AI 分析。

## 3. 目标用户与典型场景

目标用户：

- 长时间使用 Mac 办公、写作、编程、学习的人。
- 想要提醒休息，但不想使用复杂效率工具的人。
- 关注本地隐私，不希望专注数据上传云端的人。
- 想用本地 AI 分析自己专注和护眼习惯的人。

典型场景：

1. 用户上午打开 Mac，App 随系统启动，菜单栏显示下一次护眼提醒倒计时。
2. 用户开始一段工作，点击菜单栏选择“开始专注”，进入 25 分钟番茄钟。
3. 使用电脑 20 分钟后，App 弹出半透明休息遮罩，提醒看向 6 米外 20 秒。
4. 如果番茄钟即将结束，眼休提醒自动合并进番茄休息，避免连续打扰。
5. 用户离开电脑 5 分钟后再回来，App 识别为推测休息，重置眼休倒计时，但不计入手动完成的眼休次数。
6. 晚上本地生成 Markdown 日志，用户可以交给本地 AI 分析最近的眼休跳过率、专注分布和疲劳时段。

## 4. 产品边界

### 4.1 v0.1 必做

- 菜单栏常驻。
- 20-20-20 眼睛放松提醒。
- 番茄钟：专注、短休、长休。
- 休息遮罩：完成、稍后、跳过。
- 智能空闲检测。
- 工作时段限制。
- 今日轻量统计。
- 本地 JSONL 事件日志。
- Markdown 月度摘要导出。
- 本地设置与崩溃恢复。

### 4.2 v0.1 不做

- 待办清单。
- 项目管理。
- 日历同步。
- 账号系统。
- 云同步。
- 团队协作。
- 网站或 App 屏蔽。
- 剪贴板历史。
- 截图工具。
- 复杂桌面宠物系统。
- 支付订阅。
- Apple Watch / iOS 同步。

这些功能不是永远不能做，而是不进入 v0.1。当前阶段必须保证产品边界克制。

## 5. 核心功能设计

### 5.1 眼睛放松提醒

默认规则：

- 每 20 分钟触发一次眼休提醒。
- 每次眼休持续 20 秒。
- 提示用户看向 6 米外。
- 支持完成、稍后 5 分钟、跳过。

可配置项：

- 眼休间隔：默认 20 分钟。
- 眼休时长：默认 20 秒。
- 稍后时长：默认 5 分钟，v0.1 可先作为内部常量。
- 是否启用全屏遮罩。
- 是否启用系统通知。

统计规则：

- 用户点击“完成”，计入 `eyeBreakCompleted`。
- 用户点击“跳过”，计入 `eyeBreakSkipped`。
- 因空闲、锁屏、睡眠推测出的休息，计入 `inferredRest`，不计入眼休完成次数。

### 5.2 番茄钟

默认规则：

- 专注：25 分钟。
- 短休：5 分钟。
- 长休：15 分钟。
- 每完成 4 个专注阶段，进入 1 次长休。

支持操作：

- 开始。
- 暂停。
- 恢复。
- 重置。
- 跳到下一阶段。
- 结束当前专注。

状态：

- `idle`：未开始。
- `focusing`：专注中。
- `shortBreak`：短休中。
- `longBreak`：长休中。
- `paused`：暂停中。

### 5.3 眼休与番茄钟合并规则

为了避免连续打扰，眼休和番茄钟不能各自独立弹窗，必须由顶层协调器统一判断。

v0.1 合并策略：

1. 眼休到期时，如果番茄专注剩余时间不超过 2 分钟，眼休推迟到番茄休息阶段。
2. 眼休到期且离番茄休息较远，显示 20 秒眼休；默认不暂停番茄钟。
3. 已进入短休或长休时，不再单独触发眼休。
4. 番茄休息持续达到 20 秒后，视为满足本轮眼休，并重新开始眼休间隔。
5. 眼休“稍后 5 分钟”只影响眼休状态，不改变番茄状态。
6. 从系统睡眠、屏幕锁定或长时间离开状态返回时，不立即补弹已经过期的遮罩。

内部策略：

```swift
struct InterruptionPolicy: Sendable {
    var mergeWindowSeconds: Int = 120
    var eyeBreakPausesFocus: Bool = false
    var pomodoroBreakSatisfiesEyeBreak: Bool = true
    var snoozeSeconds: Int = 300
}
```

v0.1 不把这些策略全部暴露给用户，避免设置复杂化。

### 5.4 菜单栏

菜单栏是主入口。

显示内容：

- 空闲时：眼休倒计时，例如 `👁 12:30`。
- 专注时：番茄倒计时，例如 `🍅 23:12`。
- 休息时：休息倒计时，例如 `☕ 04:30`。
- 暂停时：`⏸`。

左键交互：

- 打开 SwiftUI 小面板。

右键交互：

- 暂停提醒 1 小时。
- 今日不再提醒。
- 打开设置。
- 打开日志目录。
- 退出。

实现建议：

- 使用 `NSStatusItem + NSPopover`。
- `NSStatusItem` 负责菜单栏按钮、左键/右键事件分流和动态标题。
- `NSPopover` 内部使用 `NSHostingController<MenuBarPanelView>` 承载 SwiftUI。
- 不使用 `MenuBarExtra(.window)` 作为主实现，因为它对左键弹窗、右键菜单、动态控制的表达能力不足。

### 5.5 菜单栏小面板

建议宽度：280-320 px。

内容结构：

- 顶部：当前状态与倒计时。
- 中间：主按钮。
  - 未开始：开始专注。
  - 专注中：暂停。
  - 暂停中：继续。
  - 休息中：结束休息。
- 次级操作：
  - 立即眼休。
  - 稍后提醒。
  - 跳到下一阶段。
- 底部统计：
  - 今日专注次数。
  - 今日专注分钟数。
  - 今日眼休完成次数。
  - 今日跳过次数。
- 底部入口：
  - 设置。
  - 打开日志。

原则：

- 不放复杂图表。
- 不放任务列表。
- 不放大段说明文字。

### 5.6 休息遮罩

遮罩用于眼休、短休、长休。

体验原则：

- 半透明深色覆盖。
- 中央显示倒计时。
- 一句短提示，例如“看向 6 米外”。
- 按钮仅保留完成、稍后、跳过。
- 不默认强制锁屏。
- 不使用高压文案。

多屏策略：

- 每个 `NSScreen` 创建一个 `NSPanel`。
- 所有屏幕显示半透明遮罩。
- 只在鼠标所在屏幕显示倒计时和操作按钮。
- 显示器插拔、分辨率变化时重建遮罩窗口。

窗口行为：

```swift
panel.collectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary
]
```

窗口层级：

- 优先测试 `.statusBar` 或适当浮动层级。
- v0.1 不使用 `.screenSaver` 级别，避免过强侵入。

v0.1 不建议做点击穿透。遮罩出现时应该明确表达“现在休息”，用户可以选择完成、稍后或跳过。

### 5.7 智能空闲检测

空闲检测只能作为弱信号。

弱信号：

- 超过一定时间没有键盘或鼠标输入。
- 使用 `CGEventSource.secondsSinceLastEventType` 获取输入空闲时长。

强信号：

- 屏幕锁定。
- 屏幕休眠。
- 系统睡眠。
- 用户会话失活。

建议行为：

- 输入空闲超过 3 分钟：暂停弹出眼休遮罩。
- 用户返回且空闲时长超过阈值：记录 `inferredRest`，重置眼休计时。
- 屏幕锁定、系统睡眠、屏幕休眠：认定连续使用阶段结束。
- 从睡眠或锁屏返回后，不补弹历史过期提醒。

命名原则：

- 统计中使用“最长连续使用时段”，不使用“最长连续盯屏时长”，因为 App 无法确认用户是否真的在看屏幕。

### 5.8 工作时段

默认开启工作时段：

- 开始：09:00。
- 结束：18:00。

规则：

- 工作时段内正常提醒。
- 工作时段外默认不弹遮罩。
- 用户手动开始番茄钟时，不受工作时段限制。
- “今日不再提醒”跨日自动失效。

### 5.9 今日统计

v0.1 只做轻量统计。

统计项：

- 今日完成番茄数。
- 今日专注分钟数。
- 今日完成眼休次数。
- 今日跳过眼休次数。
- 今日推测休息次数。
- 今日最长连续使用时段。

统计来源：

- 全部从 JSONL 事件日志推导。
- 不单独维护第二份统计数据库。

## 6. 技术栈

### 6.1 最终技术选型

| 层级 | 技术 |
| --- | --- |
| 语言 | Swift 6 |
| 最低系统 | macOS 13 |
| 工程 | Xcode macOS App Target |
| 核心逻辑 | 本地 Swift Package：EyePomoCore |
| UI | SwiftUI |
| 菜单栏 | AppKit `NSStatusItem` |
| 弹窗 | AppKit `NSPopover` + SwiftUI |
| 遮罩 | AppKit `NSPanel` + SwiftUI |
| 通知 | UserNotifications |
| 启动项 | ServiceManagement `SMAppService.mainApp` |
| 空闲检测 | CoreGraphics `CGEventSource` |
| 系统状态 | NSWorkspace notifications |
| 偏好设置 | UserDefaults |
| 崩溃恢复 | 原子写入 `state.json` |
| 原始日志 | JSONL |
| AI 摘要 | Markdown 派生文件 |
| 测试 | Swift Testing + XCTest/XCUITest |
| 发布 | Developer ID + Hardened Runtime + Notarization |

### 6.2 不使用的技术

- 不使用 Electron：体积和资源占用不符合轻量目标。
- 不使用 SwiftData：项目没有复杂关系型数据需求，而且 SwiftData 的核心能力要求 macOS 14+，会破坏 macOS 13 兼容目标。
- 不使用 Core Data：当前数据是事件流和少量状态，JSONL 更简单。
- 不使用云数据库：产品定位是本地优先。

## 7. 工程结构

推荐工程：

```text
EyePomo.xcodeproj
  EyePomoApp/
    App/
      EyePomoApp.swift
      AppDelegate.swift
      StatusItemController.swift
      AppCoordinator.swift
    Features/
      MenuBar/
        MenuBarPanelView.swift
        StatusMenuBuilder.swift
      Overlay/
        OverlayWindowController.swift
        OverlayView.swift
      Settings/
        SettingsView.swift
      Stats/
        TodayStatsView.swift
    Infrastructure/
      NotificationClient.swift
      IdleMonitor.swift
      WorkspaceEventMonitor.swift
      LoginItemService.swift
      UserDefaultsPreferencesStore.swift
      AppStateStore.swift
      EventStore.swift
      MarkdownJournalExporter.swift
    Resources/
      Assets.xcassets
      Info.plist

  Packages/
    EyePomoCore/
      Sources/
        EyePomoCore/
          Models/
            Preferences.swift
            AppState.swift
            AppEvent.swift
            AppEffect.swift
            EventEnvelope.swift
            DailySummary.swift
          Reducers/
            AppReducer.swift
            PomodoroReducer.swift
            EyeBreakReducer.swift
          Policies/
            InterruptionPolicy.swift
            WorkHoursPolicy.swift
          Time/
            AppClock.swift
            Deadline.swift
          Stats/
            DailySummaryBuilder.swift
          Journal/
            MarkdownJournalRenderer.swift
      Tests/
        EyePomoCoreTests/
```

拆分原则：

- `EyePomoCore` 不导入 SwiftUI 或 AppKit。
- 状态机、统计、事件模型、Markdown 渲染尽量放到 Core。
- App Target 负责系统 API、窗口、菜单栏、通知、文件路径。
- 文件写入使用 actor 串行化，避免并发写坏日志。

## 8. 运行时架构

### 8.1 顶层结构

```text
AppDelegate
  ├─ StatusItemController
  │   ├─ NSStatusItem
  │   ├─ NSPopover
  │   └─ NSMenu
  ├─ AppCoordinator
  │   ├─ AppState
  │   ├─ Timer tick
  │   ├─ handle(AppEvent)
  │   └─ execute(AppEffect)
  ├─ OverlayWindowController
  ├─ NotificationClient
  ├─ IdleMonitor
  ├─ WorkspaceEventMonitor
  └─ EventStore actor
```

### 8.2 事件驱动模型

所有用户操作、时间变化、系统事件统一变成 `AppEvent`。

```swift
enum AppEvent: Sendable {
    case user(UserAction)
    case clock(ClockEvent)
    case presence(PresenceEvent)
    case system(SystemEvent)
    case notification(NotificationAction)
}
```

状态转换由 reducer 完成：

```swift
func reduce(
    state: inout AppState,
    event: AppEvent,
    now: AppInstant
) -> [AppEffect]
```

副作用统一由 `AppCoordinator` 执行：

```swift
enum AppEffect: Sendable {
    case showOverlay(OverlayRequest)
    case dismissOverlay
    case scheduleNotification(NotificationRequest)
    case cancelNotification(String)
    case appendEvent(EventEnvelope)
    case persistState
    case updateStatusItem
    case regenerateJournal(Date)
}
```

这样可以避免番茄钟、眼休、通知、遮罩各自独立决策导致冲突。

### 8.3 状态模型

```swift
struct AppState: Codable, Sendable {
    var schemaVersion: Int
    var pomodoro: PomodoroState
    var eyeBreak: EyeBreakState
    var presence: PresenceState
    var suppression: SuppressionState
    var presentation: PresentationState
}
```

子状态：

```swift
struct PomodoroState: Codable, Sendable {
    var phase: PomodoroPhase
    var runState: RunState
    var phaseStartedAt: AppInstantSnapshot?
    var remainingWhenPausedSeconds: Int?
    var completedFocusCount: Int
    var currentSessionID: UUID?
}

struct EyeBreakState: Codable, Sendable {
    var runState: RunState
    var nextDueAt: AppInstantSnapshot?
    var snoozedUntil: AppInstantSnapshot?
    var lastSatisfiedAt: AppInstantSnapshot?
}

struct PresenceState: Codable, Sendable {
    var isInputIdle: Bool
    var lastInputIdleSeconds: Int
    var isSessionActive: Bool
    var isScreenAwake: Bool
}

struct SuppressionState: Codable, Sendable {
    var pauseUntil: Date?
    var mutedForDate: String?
}

struct PresentationState: Codable, Sendable {
    var activeOverlay: OverlayKind?
}
```

说明：

- `Date` 只用于日志、跨日和用户可理解的墙上时间。
- 运行中的持续时间使用单调时钟语义，不用 `Date` 直接计算 25 分钟。
- `state.json` 中保存快照，不需要每秒写盘。

## 9. 计时设计

### 9.1 基本原则

不要使用 `remainingSeconds -= 1` 作为真相来源。

正确方式：

- 阶段开始时计算 deadline。
- UI 每秒刷新时，根据 `deadline - now` 计算剩余时间。
- 睡眠、App Nap、系统负载不会导致累计误差。

### 9.2 时钟选择

运行时长：

- 使用 `SuspendingClock` 语义。
- 系统睡眠期间不累计专注时间。
- 合盖睡眠不应被视为有效专注。

日志时间：

- 使用 `Date`。
- 记录真实发生时间。
- 日期归属使用 `Calendar + TimeZone`。

### 9.3 崩溃恢复

`state.json` 保存：

```json
{
  "schemaVersion": 1,
  "savedAt": "2026-06-23T10:30:00Z",
  "pomodoro": {
    "phase": "focus",
    "runState": "paused",
    "remainingWhenSavedSeconds": 780,
    "completedFocusCount": 2
  },
  "eyeBreak": {
    "runState": "active",
    "remainingWhenSavedSeconds": 430
  }
}
```

恢复策略：

- App 重启后默认恢复为“已暂停”，不自动判定历史阶段完成。
- 用户可手动继续。
- 避免重启后突然弹出过期遮罩。

写入策略：

- 开始、暂停、恢复、切换阶段时写入。
- 每隔约 30 秒 checkpoint。
- 使用临时文件 + 原子替换写入。
- 不每秒写盘。

## 10. 数据存储设计

### 10.1 存储原则

- JSONL 是唯一事实源。
- Markdown 是派生文件。
- 统计缓存是派生 JSON，可由 JSONL 重建。
- 今日、月度、年度统计从 JSONL 推导。
- AI 不直接修改原始事件日志。
- 所有数据默认保存在本地。

### 10.2 应用数据目录

不要硬编码 `~/Library/Application Support`，使用系统 API 获取：

```swift
FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
)
```

内部结构：

```text
Application Support/<bundle-id>/
  state.json
  Logs/
    events-2026-06.jsonl
  Journals/
    2026-06.md
  Summaries/
    month-2026-06.json
    year-2026.json
```

可选 AI 工作目录：

```text
用户选择的 EyePomo Workspace/
  journal/
    2026-06.md
  ai-insights/
    2026-06.md
```

v0.1 可以先只提供“打开日志目录”和“导出 Markdown”。后续如果启用 App Sandbox，再支持用户选择 AI Workspace，并持久化 security-scoped bookmark。

### 10.3 偏好设置

普通设置使用 UserDefaults：

- 眼休间隔。
- 眼休时长。
- 番茄专注时长。
- 短休时长。
- 长休时长。
- 长休频率。
- 遮罩透明度。
- 工作时段。
- 登录启动。
- 通知开关。

为了 AI 分析，月度 Markdown 中写入本月配置快照和每日统计表即可。

### 10.4 事件日志 JSONL

事件采用 envelope。

```swift
struct EventEnvelope: Codable, Sendable {
    let schemaVersion: Int
    let id: UUID
    let occurredAt: Date
    let timeZoneIdentifier: String
    let kind: EventKind
    let source: EventSource
}
```

建议使用强类型 payload：

```swift
enum EventKind: Codable, Sendable {
    case focusStarted(FocusPayload)
    case focusPaused(FocusPayload)
    case focusResumed(FocusPayload)
    case focusCompleted(FocusPayload)
    case pomodoroBreakStarted(BreakPayload)
    case pomodoroBreakCompleted(BreakPayload)
    case eyeBreakShown(EyeBreakPayload)
    case eyeBreakCompleted(EyeBreakPayload)
    case eyeBreakSkipped(SkipPayload)
    case eyeBreakSnoozed(SnoozePayload)
    case inferredRest(InferredRestPayload)
    case systemSleep(SystemPayload)
    case systemWake(SystemPayload)
    case settingsChanged(SettingsChangedPayload)
}
```

示例：

```jsonl
{"schemaVersion":1,"id":"4F87F32D-4E99-4FD9-B2F0-2E21A9371E01","occurredAt":"2026-06-23T02:30:00Z","timeZoneIdentifier":"Asia/Shanghai","kind":{"focusStarted":{"durationSeconds":1500,"sessionID":"A9AA4547-1EB3-47F4-8769-4E09DE4E9D44"}},"source":"user"}
{"schemaVersion":1,"id":"F6F7F3B0-65E5-4C01-A2EF-24D703657565","occurredAt":"2026-06-23T02:50:00Z","timeZoneIdentifier":"Asia/Shanghai","kind":{"eyeBreakCompleted":{"durationSeconds":20,"trigger":"scheduled"}},"source":"user"}
{"schemaVersion":1,"id":"9D2FB1B6-9675-4723-B31E-8621189E1FBA","occurredAt":"2026-06-23T03:12:00Z","timeZoneIdentifier":"Asia/Shanghai","kind":{"inferredRest":{"idleSeconds":420,"reason":"inputIdle"}},"source":"system"}
```

写入策略：

- `EventStore actor` 串行追加。
- 按月份分文件。
- 每条事件一行。
- 读取时允许忽略崩溃导致的不完整最后一行。

### 10.5 Markdown 日志

Markdown 是给人和本地 AI 读的派生摘要。
每个月维护一个 Markdown 文件，文件内包含本月每天的统计行，避免长期运行后产生大量每日文件。

生成时机：

- 事件发生后节流更新。
- 用户点击“打开/导出日志”时重新生成。
- 日切时更新当月版本。
- 任意时候都可以由 JSONL 重建。

示例：

```markdown
---
month: 2026-06
time_zone: Asia/Shanghai
focus_sessions_completed: 6
focus_minutes: 150
eye_breaks_completed: 14
eye_breaks_skipped: 2
inferred_rests: 3
longest_continuous_usage_minutes: 78
settings_snapshot:
  eye_break_interval_minutes: 20
  eye_break_duration_seconds: 20
  focus_minutes: 25
  short_break_minutes: 5
  long_break_minutes: 15
---

# 2026-06 专注与护眼记录

本月完成 6 个番茄钟，共专注 150 分钟。

眼休提醒触发 16 次，完成 14 次，跳过 2 次。跳过主要集中在 15:00 后。

## 每日统计

| 日期 | 番茄数 | 专注分钟 | 眼休完成 | 眼休跳过 | 推测休息 | 最长连续使用分钟 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2026-06-23 | 6 | 150 | 14 | 2 | 3 | 78 |

## 可供本地 AI 分析的问题

- 最近 7 天是否存在固定疲劳时段？
- 眼休跳过率是否升高？
- 番茄钟时长是否需要调整？
```

## 11. 通知设计

系统通知是辅助通道，不是唯一提醒方式。

使用场景：

- App 不在前台。
- 用户关闭遮罩。
- 通知权限允许。

通知操作：

- 开始休息。
- 稍后提醒。
- 跳过。

权限策略：

- 通知权限被拒绝时，App 仍可完整运行。
- 菜单栏倒计时和遮罩不依赖通知权限。
- 首次启动不强行弹权限，等用户开启提醒或第一次需要通知时再请求。

## 12. 启动项与应用形态

应用形态：

- 菜单栏 agent。
- 不显示 Dock 图标。
- `LSUIElement = true`。

启动项：

- 使用 `SMAppService.mainApp`。
- 设置页提供“登录时启动”开关。
- 如果系统要求用户在系统设置中确认，给出简短提示。

## 13. UI 设计规范

### 13.1 视觉方向

关键词：

- 安静。
- 清晰。
- 低压。
- 原生。
- 小体积。

不要做：

- 大面积营销式 hero。
- 复杂背景插画。
- 高饱和渐变。
- 大型任务看板。
- 过度可爱化的桌面宠物。

### 13.2 设置页

设置页分 4 组：

1. 护眼
   - 启用眼休提醒。
   - 间隔。
   - 时长。
   - 遮罩透明度。

2. 番茄钟
   - 专注时长。
   - 短休时长。
   - 长休时长。
   - 长休频率。

3. 时间与提醒
   - 工作时段。
   - 登录时启动。
   - 通知提醒。
   - 今日不再提醒状态。

4. 数据
   - 打开日志目录。
   - 重新生成 Markdown。
   - 导出 Markdown。
   - 清空本地数据。

### 13.3 文案

遮罩文案示例：

- “看向 6 米外。”
- “放松眼睛 20 秒。”
- “眨眨眼，慢慢呼吸。”
- “休息完成后再继续。”

避免：

- “你已经伤害眼睛了。”
- “必须休息。”
- “不要偷懒。”

## 14. 权限、隐私与安全

隐私原则：

- 不上传任何数据。
- 不接入第三方分析 SDK。
- 不需要账号。
- 不采集当前 App 名称，除非未来做例外应用功能。
- 不采集屏幕内容。

本地文件：

- 事件日志保存在 Application Support。
- Markdown 摘要可由用户导出。
- AI 分析目录由用户主动选择。
- AI 结果写入 `ai-insights/`，不覆盖原始事件。

安全注意：

- 文件写入使用原子替换。
- JSONL 追加由 actor 串行管理。
- 清空数据需要二次确认。
- 设置迁移带 `schemaVersion`。

## 15. 测试方案

### 15.1 Core 测试

使用 Swift Testing。

重点场景：

- 番茄结束与眼休同时到期。
- 眼休合并进短休。
- 眼休稍后不影响番茄状态。
- 专注中眼休到期但不暂停番茄。
- 睡眠超过原 deadline 后唤醒。
- 输入空闲但屏幕仍亮。
- 工作时段外不自动弹提醒。
- “今日不再提醒”跨日自动失效。
- 跨午夜统计。
- 时区变化。
- JSONL 最后一行损坏。
- state.json schema 迁移。

### 15.2 App/UI 测试

使用 XCTest / XCUITest。

重点场景：

- 菜单栏左键打开弹窗。
- 右键显示菜单。
- 设置修改后倒计时生效。
- 通知权限拒绝时 App 仍可运行。
- 遮罩出现后完成、稍后、跳过都能写事件。
- 多屏环境下遮罩窗口数量正确。
- 遮罩期间插拔显示器后窗口重建。
- 登录启动开关状态正确。

### 15.3 手动验收

需要真实 Mac 验证：

- 合盖睡眠再唤醒。
- 锁屏再解锁。
- 全屏 App / 多 Space 下遮罩显示。
- 外接显示器插拔。
- 低电量模式或长时间后台运行。
- 签名、公证后的启动项行为。

## 16. 发布方案

v0.1 暂不进入 Mac App Store，优先 Developer ID 分发。

原因：

- 早期迭代更快。
- 菜单栏、遮罩、启动项等体验需要灰度测试。
- App Store 审核会增加迭代成本。

发布步骤：

1. Xcode Archive。
2. Developer ID 签名。
3. 启用 Hardened Runtime。
4. Notarization。
5. 生成 `.dmg`。
6. 本地安装测试。
7. 小范围分发。

## 17. 开发里程碑

### Phase 1：基础可跑

目标：菜单栏可启动，核心计时可用。

- Xcode macOS App Target。
- `EyePomoCore` 本地 Swift Package。
- `NSStatusItem + NSPopover`。
- 番茄钟状态机。
- 眼休状态机。
- 基础设置。

验收：

- App 启动后出现在菜单栏。
- 可以开始、暂停、恢复番茄钟。
- 可以看到眼休倒计时。

### Phase 2：提醒体验

目标：完整休息提醒闭环。

- 多屏遮罩。
- 完成、稍后、跳过。
- 通知辅助。
- 眼休与番茄合并策略。
- 工作时段。

验收：

- 到点显示遮罩。
- 操作会改变状态并写事件。
- 番茄休息可满足眼休。

### Phase 3：本地数据与 AI 日志

目标：所有数据本地化，并可供 AI 分析。

- `EventStore actor`。
- JSONL 事件日志。
- 今日统计推导。
- Markdown 月度摘要。
- 打开日志目录。

验收：

- 事件可以完整重放出今日统计。
- 删除 Markdown 后可以从 JSONL 重建。
- AI 可直接读取 Markdown。

### Phase 4：系统行为与发布准备

目标：接近可分发。

- 空闲检测。
- 睡眠、唤醒、锁屏处理。
- 登录启动。
- 多屏测试。
- 签名、公证、dmg。

验收：

- 睡眠唤醒后不误弹过期提醒。
- 登录启动稳定。
- 公证包可以正常安装运行。

## 18. 主要风险与应对

### 风险 1：提醒过于打扰

应对：

- 默认不强制锁屏。
- 提供稍后和跳过。
- 眼休与番茄休息合并。
- 工作时段外不主动弹出。

### 风险 2：两个计时系统冲突

应对：

- 使用顶层 `AppCoordinator`。
- 所有副作用统一由 effect 执行。
- 状态机保持纯逻辑，可测试。

### 风险 3：睡眠唤醒导致计时错误

应对：

- 使用 deadline 推导剩余时间。
- 使用 `SuspendingClock` 语义。
- 监听系统睡眠和唤醒。
- 重启后默认暂停恢复。

### 风险 4：空闲检测误判休息

应对：

- 空闲只作为弱信号。
- 记录为 `inferredRest`。
- 不计入手动完成眼休。

### 风险 5：Markdown 与原始数据不一致

应对：

- JSONL 是唯一事实源。
- Markdown 永远可重建。
- AI 分析结果单独写入 `ai-insights/`。

## 19. v0.2 候选功能

以下功能可以进入后续版本，但不进入 v0.1：

- 用户自选 AI Workspace。
- 最近 7 天趋势分析。
- 每周 Markdown 总结。
- 例外应用列表，例如演示、视频会议时降低打扰。
- 更丰富的声音和轻量动画。
- 快捷键。
- 菜单栏图标主题。
- 可选桌面陪伴形象。
- 休息建议库。

## 20. 验收标准

v0.1 可以认为完成，当且仅当满足以下条件：

- App 作为菜单栏应用稳定启动，不显示 Dock 图标。
- 左键菜单栏打开小面板，右键打开菜单。
- 眼休提醒可以按默认 20-20-20 正常触发。
- 番茄钟可以完成专注、短休、长休闭环。
- 眼休和番茄休息不会连续重复打扰。
- 遮罩支持至少一个外接屏场景。
- 空闲超过阈值后不会继续强行弹提醒。
- 所有关键行为写入 JSONL。
- 今日统计可以从 JSONL 推导。
- Markdown 日志可以从 JSONL 重建。
- 通知权限被拒绝时 App 仍可使用。
- 睡眠唤醒后不补弹历史过期提醒。
- 登录启动开关可用。
- 可完成 Developer ID 签名和 notarization。

## 21. 最终决策摘要

最终方案：

- 用原生 macOS 技术实现，不使用 Electron。
- 用 `NSStatusItem + NSPopover` 做菜单栏主入口。
- 用 `NSPanel` 做多屏休息遮罩。
- 用 `AppCoordinator + reducer/effect` 统一协调状态和副作用。
- 用 deadline 和单调时钟语义管理计时。
- 用 UserDefaults 保存偏好。
- 用 `state.json` 做崩溃恢复。
- 用 JSONL 作为唯一原始事实源。
- 用 Markdown 作为给人和本地 AI 读取的派生摘要。
- v0.1 只做护眼、番茄、统计和本地日志，不扩展成完整效率工具。
