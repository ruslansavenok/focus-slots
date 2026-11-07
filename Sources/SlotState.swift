import Foundation

struct DailySlotProgress: Codable, Equatable, Identifiable {
    let day: String
    var completed: Int
    var target: Int
    var id: String { day }

    func date(calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 4 else { return nil }
        return calendar.date(from: DateComponents(era: parts[0], year: parts[1], month: parts[2], day: parts[3], hour: 12))
    }

    func dateLabel(relativeTo now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date = date(calendar: calendar) else { return day }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct SlotState: Codable, Equatable {
    var target = 4
    var minutes = 45
    var completed = 0
    var day: String
    var deadline: Date?
    var activeSeconds: TimeInterval?
    var history: [String: DailySlotProgress] = [:]

    init(now: Date, calendar: Calendar = .current) {
        day = Self.dayKey(now, calendar: calendar)
    }

    private enum CodingKeys: String, CodingKey {
        case target, minutes, completed, day, deadline, activeSeconds, history
    }

    // Older releases have no history field. Keep their counters and timer intact.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        target = try container.decode(Int.self, forKey: .target)
        minutes = try container.decode(Int.self, forKey: .minutes)
        completed = try container.decode(Int.self, forKey: .completed)
        day = try container.decode(String.self, forKey: .day)
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        activeSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .activeSeconds)
        history = try container.decodeIfPresent([String: DailySlotProgress].self, forKey: .history) ?? [:]
    }

    var historyEntries: [DailySlotProgress] {
        history.values.sorted {
            ($0.date() ?? .distantPast) > ($1.date() ?? .distantPast)
        }
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(parts.era ?? 1)-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private mutating func recordCurrentDay() {
        let entry = DailySlotProgress(day: day, completed: completed, target: target)
        if history[day] != entry { history[day] = entry }
    }

    /// Returns true exactly once when a slot completes on the current day.
    @discardableResult
    mutating func reconcile(now: Date, calendar: Calendar = .current) -> Bool {
        target = min(99, max(1, target))
        minutes = min(240, max(1, minutes))
        completed = max(0, completed)
        // Archive the saved day's result before any midnight reset, including
        // the one remaining saved day when upgrading from an older release.
        recordCurrentDay()
        let currentDay = Self.dayKey(now, calendar: calendar)
        if day != currentDay {
            day = currentDay
            // Returning to a previously recorded local date must not erase it.
            completed = history[currentDay]?.completed ?? 0
        }
        var finishedToday = false
        if let end = deadline, now >= end {
            let finishDay = Self.dayKey(end, calendar: calendar)
            finishedToday = finishDay == currentDay
            if finishedToday {
                completed += 1
            } else {
                // A timer that finished while the app was closed belongs in
                // that day's history, without crediting or alerting today.
                var entry = history[finishDay] ?? DailySlotProgress(day: finishDay, completed: 0, target: target)
                entry.completed += 1
                history[finishDay] = entry
            }
            deadline = nil
            activeSeconds = nil
        }
        recordCurrentDay()
        return finishedToday
    }

    mutating func start(now: Date, calendar: Calendar = .current) {
        reconcile(now: now, calendar: calendar)
        guard deadline == nil else { return }
        activeSeconds = TimeInterval(minutes * 60)
        deadline = now.addingTimeInterval(activeSeconds!)
    }

    mutating func stop() {
        deadline = nil
        activeSeconds = nil
    }

    func remaining(at now: Date) -> Int {
        guard let end = deadline else { return minutes * 60 }
        return max(0, Int(ceil(end.timeIntervalSince(now))))
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
