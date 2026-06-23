import EyePomoCore
import SwiftUI

/// GitHub-style yearly contribution heatmap.
///
/// Renders one full year as 53 week columns × 7 weekday rows. Each cell is
/// shaded by Pomodoro count using a 5-step ramp. Cells with no events stay
/// on the empty surface color. No external chart dependency: pure SwiftUI
/// grid built from `RoundedRectangle`, matching the existing hand-drawn
/// chart style in `SettingsView`.
struct YearHeatmapView: View {
    let year: Int
    /// `[dayKey: DailySummary]` for the year. Missing days render as empty cells.
    let summaries: [String: DailySummary]
    let reduceTransparency: Bool
    /// Locale used for month + weekday abbreviations.
    var locale: Locale = .current

    private var cells: [HeatmapCell] { Self.cells(forYear: year) }
    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                let totalWeeks = Self.totalWeekColumns(forYear: year)
                let gap: CGFloat = 3
                let cellSide = max(7, (proxy.size.width - CGFloat(totalWeeks - 1) * gap) / CGFloat(totalWeeks))
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        monthLabels(cellSide: cellSide, gap: gap)
                        HStack(alignment: .top, spacing: gap) {
                            weekdayLabels(cellSide: cellSide)
                            weekColumns(cellSide: cellSide, gap: gap)
                        }
                    }
                    .frame(minWidth: proxy.size.width)
                }
            }
            .frame(height: 150)

            legend
        }
    }

    private func weekColumns(cellSide: CGFloat, gap: CGFloat) -> some View {
        let grouped = Self.groupByWeek(cells: cells)
        return HStack(alignment: .top, spacing: gap) {
            ForEach(grouped) { week in
                VStack(spacing: gap) {
                    ForEach(0..<7) { row in
                        if let cell = week.cells[row] {
                            cellView(for: cell, side: cellSide)
                        } else {
                            Color.clear.frame(width: cellSide, height: cellSide)
                        }
                    }
                }
            }
        }
    }

    private func cellView(for cell: HeatmapCell, side: CGFloat) -> some View {
        let count = summaries[cell.dayKey]?.focusSessionsCompleted ?? 0
        let level = HeatmapLevel.level(for: count)
        let date = Self.isoFormatter.date(from: cell.dayKey)
        let isToday = cell.dayKey == Self.todayKey
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color(for: level))
            .frame(width: side, height: side)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Color.white.opacity(isToday ? 0.8 : 0), lineWidth: 1)
            )
            .help(tooltipText(dayKey: cell.dayKey, date: date, count: count))
    }

    private func monthLabels(cellSide: CGFloat, gap: CGFloat) -> some View {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMM"
        let grouped = Self.groupByWeek(cells: cells)
        return HStack(alignment: .bottom, spacing: gap) {
            ForEach(grouped) { week in
                Text(monthLabel(for: week, formatter: formatter))
                    .font(.system(size: 9))
                    .foregroundStyle(SettingsStyle.tertiaryText)
                    .frame(width: cellSide, height: 12, alignment: .leading)
            }
        }
        .frame(height: 12, alignment: .bottom)
    }

    private func monthLabel(for week: Self.HeatmapWeek, formatter: DateFormatter) -> String {
        guard let dayKey = week.cells.compactMap({ $0?.dayKey }).first(where: { $0.hasSuffix("-01") }),
              let date = Self.isoFormatter.date(from: dayKey) else {
            return ""
        }
        return formatter.string(from: date)
    }

    private func weekdayLabels(cellSide: CGFloat) -> some View {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEEE"
        let labels = [2, 4]
        return VStack(spacing: 3) {
            ForEach(0..<7) { row in
                Text(labels.contains(row) ? formatter.string(from: Self.referenceWeekday(row)) : "")
                    .font(.system(size: 9))
                    .foregroundStyle(SettingsStyle.tertiaryText)
                    .frame(width: 12, height: cellSide, alignment: .center)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text(lessMoreText.less)
                .font(.system(size: 9.5))
                .foregroundStyle(SettingsStyle.tertiaryText)
            ForEach(HeatmapLevel.allCases, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color(for: level))
                    .frame(width: 10, height: 10)
            }
            Text(lessMoreText.more)
                .font(.system(size: 9.5))
                .foregroundStyle(SettingsStyle.tertiaryText)
        }
    }

    private func color(for level: HeatmapLevel) -> Color {
        let base = EyePomoTheme.teal
        switch level {
        case .empty:
            return reduceTransparency
                ? Color(red: 50 / 255, green: 50 / 255, blue: 52 / 255)
                : Color.white.opacity(0.06)
        case .low:
            return base.opacity(0.30)
        case .medium:
            return base.opacity(0.55)
        case .high:
            return base.opacity(0.80)
        case .max:
            return base
        }
    }

    private func tooltipText(dayKey: String, date: Date?, count: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        let dateText = date.map { formatter.string(from: $0) } ?? dayKey
        let countText: String
        if isChineseLocale {
            countText = count == 0 ? "没有番茄" : "\(count) 个番茄"
        } else {
            countText = count == 0 ? "No pomodoros" : "\(count) pomodoro\(count == 1 ? "" : "s")"
        }
        return "\(countText) · \(dateText)"
    }

    private var lessMoreText: (less: String, more: String) {
        isChineseLocale ? ("少", "多") : ("Less", "More")
    }

    private var isChineseLocale: Bool {
        locale.identifier.hasPrefix("zh")
    }

    private static var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Calendar math

    private struct HeatmapCell: Identifiable {
        var id: String { dayKey }
        let dayKey: String
        let weekdayRow: Int
    }

    private struct HeatmapWeek: Identifiable {
        let id: Int
        let cells: [HeatmapCell?]
    }

    private static func cells(forYear year: Int) -> [HeatmapCell] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return []
        }
        guard let nextYearStart = calendar.date(byAdding: .year, value: 1, to: yearStart) else {
            return []
        }

        let formatter = isoFormatter
        var cells: [HeatmapCell] = []
        var current = yearStart
        while current < nextYearStart {
            let weekday = calendar.component(.weekday, from: current)
            // Calendar.weekday: 1 = Sunday ... 7 = Saturday. We want Sunday at row 0.
            let row = weekday - 1
            cells.append(HeatmapCell(dayKey: formatter.string(from: current), weekdayRow: row))
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? nextYearStart
        }
        return cells
    }

    private static func totalWeekColumns(forYear year: Int) -> Int {
        let cells = Self.cells(forYear: year)
        return groupByWeek(cells: cells).count
    }

    private static func groupByWeek(cells: [HeatmapCell]) -> [HeatmapWeek] {
        guard !cells.isEmpty else { return [] }
        var weeks: [HeatmapWeek] = []
        var current: [HeatmapCell?] = Array(repeating: nil, count: 7)
        let firstWeekday = cells[0].weekdayRow
        var nextIndex = firstWeekday
        var weekIndex = 0

        for cell in cells {
            if nextIndex > 6 {
                weeks.append(HeatmapWeek(id: weekIndex, cells: current))
                weekIndex += 1
                current = Array(repeating: nil, count: 7)
                nextIndex = 0
            }
            current[nextIndex] = cell
            nextIndex += 1
        }
        if current.contains(where: { $0 != nil }) {
            weeks.append(HeatmapWeek(id: weekIndex, cells: current))
        }
        return weeks
    }

    private static func referenceWeekday(_ row: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let base = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        // Jan 1 2024 is a Monday (weekday 2). Move back to Sunday Dec 31 2023.
        let sunday = calendar.date(byAdding: .day, value: -1, to: base)!
        return calendar.date(byAdding: .day, value: row, to: sunday)!
    }
}

private enum HeatmapLevel: Int, CaseIterable {
    case empty, low, medium, high, max

    static func level(for count: Int) -> HeatmapLevel {
        switch count {
        case 0: return .empty
        case 1...2: return .low
        case 3...4: return .medium
        case 5...7: return .high
        default: return .max
        }
    }
}
