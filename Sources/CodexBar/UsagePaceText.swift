import CodexBarCore
import Foundation

enum UsagePaceText {
    struct PaceDetail: Sendable {
        let leftLabel: String
        let rightLabel: String?
        let expectedUsedPercent: Double
        let stage: UsagePace.Stage
    }

    private static let minimumExpectedPercent: Double = 3

    static func paceSummary(provider: UsageProvider, window: RateWindow, now: Date = .init()) -> String? {
        guard let detail = paceDetail(provider: provider, window: window, now: now) else { return nil }
        if let rightLabel = detail.rightLabel {
            return "Pace: \(detail.leftLabel) · \(rightLabel)"
        }
        return "Pace: \(detail.leftLabel)"
    }

    static func paceDetail(provider: UsageProvider, window: RateWindow, now: Date = .init()) -> PaceDetail? {
        guard let pace = pace(provider: provider, window: window, now: now) else { return nil }
        return PaceDetail(
            leftLabel: Self.detailLeftLabel(for: pace),
            rightLabel: Self.detailRightLabel(for: pace, now: now),
            expectedUsedPercent: pace.expectedUsedPercent,
            stage: pace.stage)
    }

    private static func detailLeftLabel(for pace: UsagePace) -> String {
        let deltaValue = Int(abs(pace.deltaPercent).rounded())
        switch pace.stage {
        case .onTrack:
            return "On pace"
        case .slightlyAhead, .ahead, .farAhead:
            return "\(deltaValue)% in deficit"
        case .slightlyBehind, .behind, .farBehind:
            return "\(deltaValue)% in reserve"
        }
    }

    private static func detailRightLabel(for pace: UsagePace, now: Date) -> String? {
        if pace.willLastToReset { return "Lasts until reset" }
        guard let etaSeconds = pace.etaSeconds else { return nil }
        let etaText = Self.durationText(seconds: etaSeconds, now: now)
        if etaText == "now" { return "Runs out now" }
        return "Runs out in \(etaText)"
    }

    private static func durationText(seconds: TimeInterval, now: Date) -> String {
        let date = now.addingTimeInterval(seconds)
        let countdown = UsageFormatter.resetCountdownDescription(from: date, now: now)
        if countdown == "now" { return "now" }
        if countdown.hasPrefix("in ") { return String(countdown.dropFirst(3)) }
        return countdown
    }

    static func pace(provider: UsageProvider, window: RateWindow, now: Date) -> UsagePace? {
        guard self.supportsPace(provider: provider) else { return nil }
        guard window.remainingPercent > 0 else { return nil }
        guard let pace = UsagePace.forWindow(window: window, now: now) else { return nil }
        guard pace.expectedUsedPercent >= Self.minimumExpectedPercent else { return nil }
        return pace
    }

    private static func supportsPace(provider: UsageProvider) -> Bool {
        switch provider {
        case .codex, .claude, .opencode, .gemini:
            true
        default:
            false
        }
    }

    static func weeklySummary(provider: UsageProvider, window: RateWindow, now: Date = .init()) -> String? {
        self.paceSummary(provider: provider, window: window, now: now)
    }

    static func weeklyDetail(provider: UsageProvider, window: RateWindow, now: Date = .init()) -> PaceDetail? {
        self.paceDetail(provider: provider, window: window, now: now)
    }

    static func weeklyPace(provider: UsageProvider, window: RateWindow, now: Date) -> UsagePace? {
        self.pace(provider: provider, window: window, now: now)
    }
}
