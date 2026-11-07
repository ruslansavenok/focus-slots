import Foundation

@main
enum SlotStateTests {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = ISO8601DateFormatter().date(from: "2026-11-07T10:00:00Z")!
        var state = SlotState(now: start, calendar: calendar)
        assert(state.completed == 0 && state.target == 4 && state.minutes == 45)
        assert(state.remaining(at: start) == 2700)
        state.start(now: start, calendar: calendar)
        assert(state.remaining(at: start.addingTimeInterval(0.1)) == 2700)
        assert(state.remaining(at: start.addingTimeInterval(60)) == 2640)
        assert(!state.reconcile(now: start.addingTimeInterval(2699), calendar: calendar))
        assert(state.reconcile(now: start.addingTimeInterval(2700), calendar: calendar))
        assert(state.completed == 1 && state.deadline == nil)
        assert(!state.reconcile(now: start.addingTimeInterval(2800), calendar: calendar))
        assert(state.completed == 1)
        state.start(now: start.addingTimeInterval(3000), calendar: calendar)
        state.stop()
        assert(!state.reconcile(now: start.addingTimeInterval(6000), calendar: calendar))
        assert(state.completed == 1)

        // Settings changes must not change a running slot's finish time.
        state.start(now: start.addingTimeInterval(7000), calendar: calendar)
        let originalDeadline = state.deadline
        state.minutes = 15
        assert(state.deadline == originalDeadline && state.activeSeconds == 2700)
        let data = try JSONEncoder().encode(state)
        var restored = try JSONDecoder().decode(SlotState.self, from: data)
        assert(restored.reconcile(now: originalDeadline!.addingTimeInterval(600), calendar: calendar))
        assert(restored.completed == 2 && restored.deadline == nil)
        assert(!restored.reconcile(now: originalDeadline!.addingTimeInterval(700), calendar: calendar))

        // Midnight resets progress; a slot still in progress finishes in the new day.
        let late = ISO8601DateFormatter().date(from: "2026-11-07T23:50:00Z")!
        state.stop()
        state.start(now: late, calendar: calendar)
        assert(!state.reconcile(now: late.addingTimeInterval(601), calendar: calendar))
        assert(state.completed == 0 && state.deadline != nil)
        assert(state.reconcile(now: late.addingTimeInterval(900), calendar: calendar))
        assert(state.completed == 1)

        // Relaunching days after a timer ended must not credit today's counter.
        var stale = SlotState(now: start, calendar: calendar)
        stale.start(now: start, calendar: calendar)
        assert(!stale.reconcile(now: start.addingTimeInterval(172800), calendar: calendar))
        assert(stale.completed == 0 && stale.deadline == nil)
        var fresh = SlotState(now: start, calendar: calendar)
        fresh.target = -5
        fresh.minutes = 900
        fresh.reconcile(now: start, calendar: calendar)
        assert(fresh.target == 1 && fresh.minutes == 240)
        assert(SlotState.clock(2700) == "45:00")
        assert(SlotState.clock(0) == "00:00")
        // Completing the target does not cap the counter or the next timer.
        var extra = SlotState(now: start, calendar: calendar)
        extra.completed = 4
        extra.start(now: start, calendar: calendar)
        assert(extra.deadline != nil && extra.remaining(at: start) == 2700)
        assert(extra.reconcile(now: start.addingTimeInterval(2700), calendar: calendar))
        assert(extra.completed == 5 && extra.target == 4)
        assert(extra.remaining(at: start.addingTimeInterval(2700)) == 2700)
        assert(extra.history[extra.day]?.completed == 5 && extra.history[extra.day]?.target == 4)
        extra.start(now: start.addingTimeInterval(3000), calendar: calendar)
        assert(extra.deadline != nil && extra.completed == 5)
        extra.stop()
        let reloadedExtra = try JSONDecoder().decode(SlotState.self, from: JSONEncoder().encode(extra))
        assert(reloadedExtra.history == extra.history && reloadedExtra.completed == 5)

        // Pre-history saved JSON must preserve its counter, settings, and timer.
        var legacy = SlotState(now: start, calendar: calendar)
        legacy.completed = 3
        legacy.target = 5
        legacy.minutes = 25
        legacy.start(now: start, calendar: calendar)
        var legacyJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        legacyJSON.removeValue(forKey: "history")
        var migrated = try JSONDecoder().decode(SlotState.self, from: JSONSerialization.data(withJSONObject: legacyJSON))
        assert(migrated.completed == 3 && migrated.target == 5 && migrated.minutes == 25)
        assert(migrated.deadline == legacy.deadline && migrated.history.isEmpty)
        migrated.reconcile(now: start.addingTimeInterval(1), calendar: calendar)
        assert(migrated.history[migrated.day]?.completed == 3 && migrated.history[migrated.day]?.target == 5)

        // Each archived day retains its own goal when today's settings change.
        var daily = SlotState(now: start, calendar: calendar)
        daily.completed = 3
        daily.reconcile(now: start, calendar: calendar)
        let yesterday = daily.day
        let tomorrow = start.addingTimeInterval(86400)
        daily.reconcile(now: tomorrow, calendar: calendar)
        assert(daily.completed == 0 && daily.history[yesterday]?.completed == 3)
        daily.target = 7
        daily.reconcile(now: tomorrow, calendar: calendar)
        assert(daily.history[yesterday]?.target == 4 && daily.history[daily.day]?.target == 7)
        assert(daily.historyEntries.first?.day == daily.day)

        // Expired closed-app timers credit their actual finish day only once.
        assert(stale.history[SlotState.dayKey(start, calendar: calendar)]?.completed == 1)
        stale.reconcile(now: start.addingTimeInterval(172900), calendar: calendar)
        assert(stale.history[SlotState.dayKey(start, calendar: calendar)]?.completed == 1)
        var overnight = SlotState(now: late, calendar: calendar)
        overnight.completed = 2
        overnight.minutes = 15
        overnight.start(now: late, calendar: calendar)
        assert(!overnight.reconcile(now: late.addingTimeInterval(172800), calendar: calendar))
        let finishDay = SlotState.dayKey(late.addingTimeInterval(900), calendar: calendar)
        assert(overnight.history[finishDay]?.completed == 1 && overnight.completed == 0)
        assert(overnight.history[SlotState.dayKey(late, calendar: calendar)]?.completed == 2)
        overnight.reconcile(now: late, calendar: calendar)
        assert(overnight.completed == 2, "Returning to a recorded local date erased its count")

        // Dates sort numerically, and earlier years remain distinguishable.
        let nov10 = ISO8601DateFormatter().date(from: "2026-11-10T10:00:00Z")!
        let newestKey = SlotState.dayKey(nov10, calendar: calendar)
        overnight.history[newestKey] = DailySlotProgress(day: newestKey, completed: 6, target: 4)
        assert(overnight.historyEntries.first?.day == newestKey)
        let sameYear = DailySlotProgress(day: SlotState.dayKey(start, calendar: calendar), completed: 3, target: 4)
        assert(sameYear.dateLabel(relativeTo: start, calendar: calendar) == "Nov 7")
        let earlierYear = DailySlotProgress(day: "1-2025-11-7", completed: 3, target: 4)
        assert(earlierYear.dateLabel(relativeTo: start, calendar: calendar) == "Nov 7, 2025")
        print("PASS: countdown, unlimited extra slots, history persistence, legacy migration, daily targets, midnight, stale completion history, date sorting and labels")
    }
}
