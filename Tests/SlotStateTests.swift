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
        print("PASS: countdown, single completion, stop, persistence, settings, midnight, stale timer, bounds, formatting")
    }
}
