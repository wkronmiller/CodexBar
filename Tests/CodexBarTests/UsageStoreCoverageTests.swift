import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@MainActor
@Suite
struct UsageStoreCoverageTests {
    @Test
    func providerWithHighestUsageAndIconStyle() throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreCoverageTests-highest")
        let store = Self.makeUsageStore(settings: settings)
        let metadata = ProviderRegistry.shared.metadata

        try settings.setProviderEnabled(provider: .codex, metadata: #require(metadata[.codex]), enabled: true)
        try settings.setProviderEnabled(provider: .factory, metadata: #require(metadata[.factory]), enabled: true)
        try settings.setProviderEnabled(provider: .claude, metadata: #require(metadata[.claude]), enabled: true)

        let now = Date()
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 50, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
                secondary: nil,
                updatedAt: now),
            provider: .codex)
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 10, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
                secondary: RateWindow(usedPercent: 70, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
                updatedAt: now),
            provider: .factory)
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 100, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
                secondary: nil,
                updatedAt: now),
            provider: .claude)

        let highest = store.providerWithHighestUsage()
        #expect(highest?.provider == .factory)
        #expect(highest?.usedPercent == 70)
        #expect(store.iconStyle == .combined)

        try settings.setProviderEnabled(provider: .factory, metadata: #require(metadata[.factory]), enabled: false)
        try settings.setProviderEnabled(provider: .claude, metadata: #require(metadata[.claude]), enabled: false)
        #expect(store.iconStyle == store.style(for: .codex))

        store._setErrorForTesting("error", provider: .codex)
        #expect(store.isStale)
    }

    @Test
    func sourceLabelAddsOpenAIWeb() {
        let settings = Self.makeSettingsStore(suite: "UsageStoreCoverageTests-source")
        settings.debugDisableKeychainAccess = false
        settings.codexUsageDataSource = .oauth
        settings.codexCookieSource = .manual

        let store = Self.makeUsageStore(settings: settings)
        store.openAIDashboard = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            updatedAt: Date())
        store.openAIDashboardRequiresLogin = false

        let label = store.sourceLabel(for: .codex)
        #expect(label.contains("openai-web"))
    }

    @Test
    func openAIDashboardMergesSparkMetricIntoExistingCodexSnapshot() async throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreCoverageTests-openai-spark-merge")
        let store = Self.makeUsageStore(settings: settings)
        let now = Date()

        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 14, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                secondary: RateWindow(usedPercent: 8, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
                tertiary: nil,
                updatedAt: now),
            provider: .codex)

        let dashboard = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            primaryLimit: nil,
            secondaryLimit: nil,
            tertiaryLimit: RateWindow(usedPercent: 65, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            creditsRemaining: nil,
            accountPlan: nil,
            updatedAt: now)

        await store._applyOpenAIDashboardForTesting(dashboard, targetEmail: nil)

        let snapshot = try #require(store.snapshot(for: .codex))
        #expect(snapshot.primary?.usedPercent == 14)
        #expect(snapshot.secondary?.usedPercent == 8)
        #expect(snapshot.tertiary?.usedPercent == 65)

        let updatedDashboard = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            primaryLimit: nil,
            secondaryLimit: nil,
            tertiaryLimit: RateWindow(usedPercent: 40, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            creditsRemaining: nil,
            accountPlan: nil,
            updatedAt: now.addingTimeInterval(60))

        await store._applyOpenAIDashboardForTesting(updatedDashboard, targetEmail: nil)

        let refreshed = try #require(store.snapshot(for: .codex))
        #expect(refreshed.tertiary?.usedPercent == 40)

        let dashboardWithoutSpark = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            primaryLimit: nil,
            secondaryLimit: nil,
            tertiaryLimit: nil,
            creditsRemaining: nil,
            accountPlan: nil,
            updatedAt: now.addingTimeInterval(120))

        await store._applyOpenAIDashboardForTesting(dashboardWithoutSpark, targetEmail: nil)

        let cleared = try #require(store.snapshot(for: .codex))
        #expect(cleared.tertiary == nil)
    }

    @Test
    func openAIDashboardDoesNotOverridePrimarySourceSparkMetric() async throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreCoverageTests-openai-spark-precedence")
        let store = Self.makeUsageStore(settings: settings)
        let now = Date()

        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 14, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                secondary: RateWindow(usedPercent: 8, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
                tertiary: RateWindow(usedPercent: 22, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
                updatedAt: now),
            provider: .codex)

        let dashboard = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            primaryLimit: nil,
            secondaryLimit: nil,
            tertiaryLimit: RateWindow(usedPercent: 75, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            creditsRemaining: nil,
            accountPlan: nil,
            updatedAt: now.addingTimeInterval(60))

        await store._applyOpenAIDashboardForTesting(dashboard, targetEmail: nil)

        let merged = try #require(store.snapshot(for: .codex))
        #expect(merged.tertiary?.usedPercent == 22)

        let dashboardWithoutSpark = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            creditEvents: [],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            primaryLimit: nil,
            secondaryLimit: nil,
            tertiaryLimit: nil,
            creditsRemaining: nil,
            accountPlan: nil,
            updatedAt: now.addingTimeInterval(120))

        await store._applyOpenAIDashboardForTesting(dashboardWithoutSpark, targetEmail: nil)

        let stillPrimary = try #require(store.snapshot(for: .codex))
        #expect(stillPrimary.tertiary?.usedPercent == 22)
    }

    @Test
    func providerWithHighestUsagePrefersKimiRateLimitWindow() throws {
        let settings = Self.makeSettingsStore(suite: "UsageStoreCoverageTests-kimi-highest")
        let store = Self.makeUsageStore(settings: settings)
        let metadata = ProviderRegistry.shared.metadata

        try settings.setProviderEnabled(provider: .codex, metadata: #require(metadata[.codex]), enabled: true)
        try settings.setProviderEnabled(provider: .kimi, metadata: #require(metadata[.kimi]), enabled: true)

        let now = Date()
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 60, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
                secondary: nil,
                updatedAt: now),
            provider: .codex)
        store._setSnapshotForTesting(
            UsageSnapshot(
                primary: RateWindow(usedPercent: 10, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
                secondary: RateWindow(usedPercent: 80, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                updatedAt: now),
            provider: .kimi)

        let highest = store.providerWithHighestUsage()
        #expect(highest?.provider == .kimi)
        #expect(highest?.usedPercent == 80)
    }

    @Test
    func providerAvailabilityAndSubscriptionDetection() {
        let zaiStore = InMemoryZaiTokenStore(value: "zai-token")
        let syntheticStore = InMemorySyntheticTokenStore(value: "synthetic-token")
        let settings = Self.makeSettingsStore(
            suite: "UsageStoreCoverageTests-availability",
            zaiTokenStore: zaiStore,
            syntheticTokenStore: syntheticStore)
        let store = Self.makeUsageStore(settings: settings)

        #expect(store.isProviderAvailable(.zai))
        #expect(store.isProviderAvailable(.synthetic))

        let identity = ProviderIdentitySnapshot(
            providerID: .claude,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: "Pro")
        store._setSnapshotForTesting(
            UsageSnapshot(primary: nil, secondary: nil, updatedAt: Date(), identity: identity),
            provider: .claude)
        #expect(store.isClaudeSubscription())
        #expect(UsageStore.isSubscriptionPlan("Team"))
        #expect(!UsageStore.isSubscriptionPlan("api"))
    }

    @Test
    func statusIndicatorsAndFailureGate() {
        #expect(!ProviderStatusIndicator.none.hasIssue)
        #expect(ProviderStatusIndicator.maintenance.hasIssue)
        #expect(ProviderStatusIndicator.unknown.label == "Status unknown")

        var gate = ConsecutiveFailureGate()
        let first = gate.shouldSurfaceError(onFailureWithPriorData: true)
        #expect(!first)
        let second = gate.shouldSurfaceError(onFailureWithPriorData: true)
        #expect(second)
        gate.recordSuccess()
        let third = gate.shouldSurfaceError(onFailureWithPriorData: false)
        #expect(third)
        gate.reset()
        #expect(gate.streak == 0)
    }

    private static func makeSettingsStore(
        suite: String,
        zaiTokenStore: any ZaiTokenStoring = NoopZaiTokenStore(),
        syntheticTokenStore: any SyntheticTokenStoring = NoopSyntheticTokenStore())
        -> SettingsStore
    {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let configStore = testConfigStore(suiteName: suite)

        return SettingsStore(
            userDefaults: defaults,
            configStore: configStore,
            zaiTokenStore: zaiTokenStore,
            syntheticTokenStore: syntheticTokenStore,
            codexCookieStore: InMemoryCookieHeaderStore(),
            claudeCookieStore: InMemoryCookieHeaderStore(),
            cursorCookieStore: InMemoryCookieHeaderStore(),
            opencodeCookieStore: InMemoryCookieHeaderStore(),
            factoryCookieStore: InMemoryCookieHeaderStore(),
            minimaxCookieStore: InMemoryMiniMaxCookieStore(),
            minimaxAPITokenStore: InMemoryMiniMaxAPITokenStore(),
            kimiTokenStore: InMemoryKimiTokenStore(),
            kimiK2TokenStore: InMemoryKimiK2TokenStore(),
            augmentCookieStore: InMemoryCookieHeaderStore(),
            ampCookieStore: InMemoryCookieHeaderStore(),
            copilotTokenStore: InMemoryCopilotTokenStore(),
            tokenAccountStore: InMemoryTokenAccountStore())
    }

    private static func makeUsageStore(settings: SettingsStore) -> UsageStore {
        UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings)
    }
}

private final class InMemoryZaiTokenStore: ZaiTokenStoring, @unchecked Sendable {
    var value: String?

    init(value: String? = nil) {
        self.value = value
    }

    func loadToken() throws -> String? {
        self.value
    }

    func storeToken(_ token: String?) throws {
        self.value = token
    }
}

private final class InMemorySyntheticTokenStore: SyntheticTokenStoring, @unchecked Sendable {
    var value: String?

    init(value: String? = nil) {
        self.value = value
    }

    func loadToken() throws -> String? {
        self.value
    }

    func storeToken(_ token: String?) throws {
        self.value = token
    }
}
