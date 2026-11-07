import Foundation

struct SlotState: Codable, Equatable {
    var target = 4
    var minutes = 45
    var completed = 0
    var day: String
    var deadline: Date?
    var activeSeconds: TimeInterval?

    init(now: Date, calendar: Calendar = .current) {
        day = Self.dayKey(now, calendar: calendar)
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return "\(parts.era ?? 1)-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// Returns true exactly once when a slot completes on the current day.
    @discardableResult
    mutating func reconcile(now: Date, calendar: Calendar = .current) -> Bool {
        target = min(99, max(1, target))
        minutes = min(240, max(1, minutes))
        completed = max(0, completed)
        let currentDay = Self.dayKey(now, calendar: calendar)
        if day != currentDay {
            day = currentDay
            completed = 0
        }
        guard let end = deadline, now >= end else { return false }
        // A timer that expired while the app was closed belongs to its finish day.
        let finishedToday = Self.dayKey(end, calendar: calendar) == currentDay
        if finishedToday { completed += 1 }
        deadline = nil
        activeSeconds = nil
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
