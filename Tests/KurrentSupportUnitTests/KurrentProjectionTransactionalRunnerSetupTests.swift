import Testing
import KurrentDB
import EventSourcing
@testable import KurrentSupport

@Suite("KurrentProjection.TransactionalSubscriptionRunner — setup")
struct KurrentProjectionTransactionalRunnerSetupTests {

    /// Stub provider for unit testing — no real backend.
    struct StubProvider: TransactionProvider {
        struct StubTx: Sendable {}
        func withTransaction<Result: Sendable>(_ body: (StubTx) async throws -> Result) async throws -> Result {
            try await body(StubTx())
        }
    }

    @Test("Can construct runner with a provider and default retry policy")
    func constructWithDefaults() {
        let client = KurrentDBClient(settings: .localhost())
        let runner = KurrentProjection.TransactionalSubscriptionRunner(
            client: client,
            transactionProvider: StubProvider(),
            stream: "$ce-Test",
            groupName: "test-group"
        )
        let _: any Sendable = runner
    }

    @Test("Can construct runner with explicit retry policy")
    func constructWithExplicitPolicy() {
        let client = KurrentDBClient(settings: .localhost())
        let runner = KurrentProjection.TransactionalSubscriptionRunner(
            client: client,
            transactionProvider: StubProvider(),
            stream: "$ce-Test",
            groupName: "test-group",
            retryPolicy: KurrentProjection.MaxRetriesPolicy(max: 3)
        )
        let _: any Sendable = runner
    }
}
