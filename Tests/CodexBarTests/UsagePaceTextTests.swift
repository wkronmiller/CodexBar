import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@Suite
struct UsagePaceTextTests {
    @Test
    func paceDetail_providesLeftRightLabels() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 50,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3600),
            resetDescription: nil)

        let detail = UsagePaceText.paceDetail(provider: .codex, window: window, now: now)

        #expect(detail?.leftLabel == "7% in deficit")
        #expect(detail?.rightLabel == "Runs out in 3d")
    }

    @Test
    func paceDetail_reportsLastsUntilReset() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3600),
            resetDescription: nil)

        let detail = UsagePaceText.paceDetail(provider: .codex, window: window, now: now)

        #expect(detail?.leftLabel == "33% in reserve")
        #expect(detail?.rightLabel == "Lasts until reset")
    }

    @Test
    func paceSummary_formatsSingleLineText() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 50,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3600),
            resetDescription: nil)

        let summary = UsagePaceText.paceSummary(provider: .codex, window: window, now: now)

        #expect(summary == "Pace: 7% in deficit · Runs out in 3d")
    }

    @Test
    func paceDetail_hidesWhenResetIsMissing() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: nil,
            resetDescription: nil)

        let detail = UsagePaceText.paceDetail(provider: .codex, window: window, now: now)

        #expect(detail == nil)
    }

    @Test
    func paceDetail_hidesWhenResetIsInPastOrTooFar() {
        let now = Date(timeIntervalSince1970: 0)
        let pastWindow = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(-60),
            resetDescription: nil)
        let farFutureWindow = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(9 * 24 * 3600),
            resetDescription: nil)

        #expect(UsagePaceText.paceDetail(provider: .codex, window: pastWindow, now: now) == nil)
        #expect(UsagePaceText.paceDetail(provider: .codex, window: farFutureWindow, now: now) == nil)
    }

    @Test
    func paceDetail_hidesWhenNoElapsedButUsageExists() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 5,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(7 * 24 * 3600),
            resetDescription: nil)

        let detail = UsagePaceText.paceDetail(provider: .codex, window: window, now: now)

        #expect(detail == nil)
    }

    @Test
    func paceDetail_hidesWhenTooEarlyInWindow() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 40,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval((7 * 24 * 3600) - (60 * 60)),
            resetDescription: nil)

        let detail = UsagePaceText.paceDetail(provider: .codex, window: window, now: now)

        #expect(detail == nil)
    }

    @Test
    func paceDetail_hidesWhenUsageIsDepleted() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 100,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(2 * 24 * 3600),
            resetDescription: nil)

        let detail = UsagePaceText.paceDetail(provider: .codex, window: window, now: now)

        #expect(detail == nil)
    }

    @Test
    func paceDetail_supportsHourlyWindow() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 60,
            windowMinutes: 60,
            resetsAt: now.addingTimeInterval(30 * 60),
            resetDescription: nil)

        let detail = UsagePaceText.paceDetail(provider: .codex, window: window, now: now)

        #expect(detail?.leftLabel == "10% in deficit")
        #expect(detail?.rightLabel == "Runs out in 20m")
    }

    @Test
    func paceSummary_supportsDailyWindow() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 10,
            windowMinutes: 1440,
            resetsAt: now.addingTimeInterval(18 * 60 * 60),
            resetDescription: nil)

        let summary = UsagePaceText.paceSummary(provider: .gemini, window: window, now: now)

        #expect(summary == "Pace: 15% in reserve · Lasts until reset")
    }
}
