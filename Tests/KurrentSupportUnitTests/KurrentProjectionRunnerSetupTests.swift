import Testing
import KurrentDB
@testable import KurrentSupport

@Suite("KurrentProjection.PersistentSubscriptionRunner — setup")
struct KurrentProjectionRunnerSetupTests {

    @Test("Can construct runner with default retry policy and logger")
    func constructWithDefaults() {
        let client = KurrentDBClient(settings: .localhost())
        let runner = KurrentProjection.PersistentSubscriptionRunner(
            client: client,
            stream: "$ce-Test",
            groupName: "test-group"
        )
        // Smoke check — runner exists and is Sendable.
        let _: any Sendable = runner
    }

    @Test("Can construct runner with explicit retry policy")
    func constructWithExplicitPolicy() {
        let client = KurrentDBClient(settings: .localhost())
        let runner = KurrentProjection.PersistentSubscriptionRunner(
            client: client,
            stream: "$ce-Test",
            groupName: "test-group",
            retryPolicy: KurrentProjection.MaxRetriesPolicy(max: 3)
        )
        let _: any Sendable = runner
    }

    @Test("register low-level overload is chainable and counts registrations")
    func lowLevelRegisterChains() {
        let client = KurrentDBClient(settings: .localhost())
        let runner = KurrentProjection.PersistentSubscriptionRunner(
            client: client,
            stream: "$ce-Test",
            groupName: "test-group"
        )
        let returned = runner
            .register(extractInput: { _ -> Int? in 1 }, execute: { _ in })
            .register(extractInput: { _ -> String? in nil }, execute: { _ in })

        #expect(returned === runner) // Same instance
        #expect(runner.registrationCount == 2)
    }
}
