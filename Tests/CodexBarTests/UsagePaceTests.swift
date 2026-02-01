import CodexBarCore
import Foundation
import Testing

@Suite
struct UsagePaceTests {
    @Test
    func weeklyPace_computesDeltaAndEta() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 50,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3600),
            resetDescription: nil)

        let pace = UsagePace.weekly(window: window, now: now)

        #expect(pace != nil)
        guard let pace else { return }
        #expect(abs(pace.expectedUsedPercent - 42.857) < 0.01)
        #expect(abs(pace.deltaPercent - 7.143) < 0.01)
        #expect(pace.stage == .ahead)
        #expect(pace.willLastToReset == false)
        #expect(pace.etaSeconds != nil)
        #expect(abs((pace.etaSeconds ?? 0) - (3 * 24 * 3600)) < 1)
    }

    @Test
    func weeklyPace_marksLastsToResetWhenUsageIsLow() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 5,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3600),
            resetDescription: nil)

        let pace = UsagePace.weekly(window: window, now: now)

        #expect(pace != nil)
        guard let pace else { return }
        #expect(pace.willLastToReset == true)
        #expect(pace.etaSeconds == nil)
        #expect(pace.stage == .farBehind)
    }

    @Test
    func paceForWindow_computesHourlyDelta() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 60,
            windowMinutes: 60,
            resetsAt: now.addingTimeInterval(30 * 60),
            resetDescription: nil)

        let pace = UsagePace.forWindow(window: window, now: now)

        #expect(pace != nil)
        guard let pace else { return }
        #expect(abs(pace.expectedUsedPercent - 50) < 0.01)
        #expect(abs(pace.deltaPercent - 10) < 0.01)
        #expect(pace.stage == .ahead)
        #expect(pace.willLastToReset == false)
        #expect(abs((pace.etaSeconds ?? 0) - (20 * 60)) < 1)
    }

    @Test
    func paceForWindow_supportsDailyWindow() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 10,
            windowMinutes: 1440,
            resetsAt: now.addingTimeInterval(18 * 60 * 60),
            resetDescription: nil)

        let pace = UsagePace.forWindow(window: window, now: now)

        #expect(pace != nil)
        guard let pace else { return }
        #expect(abs(pace.expectedUsedPercent - 25) < 0.01)
        #expect(abs(pace.deltaPercent + 15) < 0.01)
        #expect(pace.stage == .farBehind)
        #expect(pace.willLastToReset == true)
        #expect(pace.etaSeconds == nil)
    }

    @Test
    func weeklyPace_hidesWhenResetMissingOrOutsideWindow() {
        let now = Date(timeIntervalSince1970: 0)
        let missing = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: nil,
            resetDescription: nil)
        let tooFar = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(9 * 24 * 3600),
            resetDescription: nil)

        #expect(UsagePace.weekly(window: missing, now: now) == nil)
        #expect(UsagePace.weekly(window: tooFar, now: now) == nil)
    }

    @Test
    func weeklyPace_hidesWhenUsageExistsButNoElapsed() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 12,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(7 * 24 * 3600),
            resetDescription: nil)

        let pace = UsagePace.weekly(window: window, now: now)

        #expect(pace == nil)
    }
}
