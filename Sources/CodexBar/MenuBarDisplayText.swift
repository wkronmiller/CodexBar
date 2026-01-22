import CodexBarCore
import Foundation

enum MenuBarDisplayText {
    static func percentText(window: RateWindow?, showUsed: Bool) -> String? {
        guard let window else { return nil }
        let percent = showUsed ? window.usedPercent : window.remainingPercent
        let clamped = min(100, max(0, percent))
        return String(format: "%.0f%%", clamped)
    }

    /// Formats both primary and secondary windows as "X%/Y%" (e.g., "100%/0%").
    /// Falls back to single percent if only one window is available.
    static func dualPercentText(primary: RateWindow?, secondary: RateWindow?, showUsed: Bool) -> String? {
        guard let primary, let secondary else {
            return self.percentText(window: primary ?? secondary, showUsed: showUsed)
        }
        let p = showUsed ? primary.usedPercent : primary.remainingPercent
        let s = showUsed ? secondary.usedPercent : secondary.remainingPercent
        let pClamped = min(100, max(0, p))
        let sClamped = min(100, max(0, s))
        return String(format: "%.0f%%/%.0f%%", pClamped, sClamped)
    }

    static func paceText(provider: UsageProvider, window: RateWindow?, now: Date = .init()) -> String? {
        guard let window else { return nil }
        guard let pace = UsagePaceText.weeklyPace(provider: provider, window: window, now: now) else { return nil }
        let deltaValue = Int(abs(pace.deltaPercent).rounded())
        let sign = pace.deltaPercent >= 0 ? "+" : "-"
        return "\(sign)\(deltaValue)%"
    }

    static func displayText(
        mode: MenuBarDisplayMode,
        provider: UsageProvider,
        percentWindow: RateWindow?,
        paceWindow: RateWindow?,
        showUsed: Bool,
        now: Date = .init()) -> String?
    {
        switch mode {
        case .percent:
            return self.percentText(window: percentWindow, showUsed: showUsed)
        case .pace:
            return self.paceText(provider: provider, window: paceWindow, now: now)
        case .both:
            guard let percent = percentText(window: percentWindow, showUsed: showUsed) else { return nil }
            guard let pace = Self.paceText(provider: provider, window: paceWindow, now: now) else { return nil }
            return "\(percent) · \(pace)"
        }
    }

    /// Dual-window variant that shows both primary and secondary as "X%/Y%".
    static func displayTextDual(
        mode: MenuBarDisplayMode,
        provider: UsageProvider,
        primary: RateWindow?,
        secondary: RateWindow?,
        showUsed: Bool,
        now: Date = .init()) -> String?
    {
        switch mode {
        case .percent:
            return self.dualPercentText(primary: primary, secondary: secondary, showUsed: showUsed)
        case .pace:
            return self.paceText(provider: provider, window: secondary, now: now)
        case .both:
            guard let percent = self.dualPercentText(primary: primary, secondary: secondary, showUsed: showUsed)
            else { return nil }
            guard let pace = Self.paceText(provider: provider, window: secondary, now: now) else { return nil }
            return "\(percent) · \(pace)"
        }
    }
}
