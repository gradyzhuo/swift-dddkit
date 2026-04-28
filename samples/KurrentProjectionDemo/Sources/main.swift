import Foundation
import DDDCore
import EventSourcing
import KurrentSupport
import KurrentDB
import ReadModelPersistence

// MARK: - Read Models (user-defined)

struct OrderSummary: ReadModel, Codable, Sendable {
    let id: String
    var customerId: String = ""
    var totalAmount: Double = 0
    var status: String = "pending"
}

struct OrderTimeline: ReadModel, Codable, Sendable {
    let id: String
    var entries: [String] = []
}

// MARK: - Projector Inputs

struct OrderSummaryInput: CQRSProjectorInput { let id: String }
struct OrderTimelineInput: CQRSProjectorInput { let id: String }

// MARK: - Projectors
//
// The protocols are generated from projection-model.yaml — one per ReadModel:
//   - OrderSummaryProjectorProtocol
//   - OrderTimelineProjectorProtocol
// Each conforming projector accumulates one read model from the same Order events.

struct OrderSummaryProjector: OrderSummaryProjectorProtocol, Sendable {
    typealias ReadModelType = OrderSummary
    typealias Input = OrderSummaryInput
    typealias StorageCoordinator = KurrentStorageCoordinator<OrderSummaryProjector>

    // Stream category — must match the `$ce-Order` system stream we subscribe to.
    static var categoryRule: StreamCategoryRule { .custom("Order") }

    let coordinator: KurrentStorageCoordinator<OrderSummaryProjector>

    func buildReadModel(input: Input) throws -> OrderSummary? {
        OrderSummary(id: input.id)
    }

    func when(readModel: inout OrderSummary, event: OrderCreated) throws {
        readModel.customerId = event.customerId
        readModel.totalAmount = event.totalAmount
        readModel.status = "active"
    }
    func when(readModel: inout OrderSummary, event: OrderAmountUpdated) throws {
        readModel.totalAmount = event.newAmount
    }
    func when(readModel: inout OrderSummary, event: OrderCancelled) throws {
        readModel.status = "cancelled"
    }
}

struct OrderTimelineProjector: OrderTimelineProjectorProtocol, Sendable {
    typealias ReadModelType = OrderTimeline
    typealias Input = OrderTimelineInput
    typealias StorageCoordinator = KurrentStorageCoordinator<OrderTimelineProjector>

    static var categoryRule: StreamCategoryRule { .custom("Order") }

    let coordinator: KurrentStorageCoordinator<OrderTimelineProjector>

    func buildReadModel(input: Input) throws -> OrderTimeline? {
        OrderTimeline(id: input.id)
    }

    func when(readModel: inout OrderTimeline, event: OrderCreated) throws {
        readModel.entries.append("created — customer=\(event.customerId), amount=\(event.totalAmount)")
    }
    func when(readModel: inout OrderTimeline, event: OrderAmountUpdated) throws {
        readModel.entries.append("amount updated → \(event.newAmount)")
    }
    func when(readModel: inout OrderTimeline, event: OrderCancelled) throws {
        readModel.entries.append("cancelled")
    }
}

// MARK: - Helper to extract orderId from a RecordedEvent (Order-{id} → {id})

func orderId(from record: RecordedEvent) -> String? {
    let name = record.streamIdentifier.name
    let prefix = "Order-"
    guard name.hasPrefix(prefix) else { return nil }
    return String(name.dropFirst(prefix.count))
}

// MARK: - Entry Point

// ── KurrentDB connection ────────────────────────────────────────────────────
// Defaults to local insecure single-node on :2113.
// For TLS / cluster mode, set KURRENT_CLUSTER=true (3-node cluster on :2111-:2113).
let kdbClient: KurrentDBClient = {
    if ProcessInfo.processInfo.environment["KURRENT_CLUSTER"] == "true" {
        let endpoints: [Endpoint] = [
            .init(host: "localhost", port: 2111),
            .init(host: "localhost", port: 2112),
            .init(host: "localhost", port: 2113),
        ]
        let settings = ClientSettings(
            clusterMode: .seeds(endpoints),
            secure: true,
            tlsVerifyCert: false
        )
        .authenticated(.credentials(username: "admin", password: "changeit"))
        return KurrentDBClient(settings: settings)
    } else {
        return KurrentDBClient(settings: .localhost())
    }
}()

let groupName = "kurrent-projection-demo"
let stream = "$ce-Order"

print("=== KurrentProjection Demo ===\n")

// 1. Create persistent subscription with resolveLink (idempotent — re-create errors are tolerated).
//    `resolveLink = true` is required so the runner's `extractInput` closure receives
//    the original aggregate stream name (e.g. "Order-abc") rather than the link
//    event living in "$ce-Order".
do {
    try await kdbClient.persistentSubscriptions(stream: stream, group: groupName).create { options in
        options.settings.resolveLink = true
    }
    print("✓ Persistent subscription created: \(stream) / \(groupName)")
} catch {
    // Subscription likely already exists from a previous run — fine for a demo.
    print("ℹ Subscription create skipped (probably already exists): \(error)")
}

// 2. Build the runner with TWO registered projectors fanning out from the same subscription.
let summaryStore = InMemoryReadModelStore<OrderSummary>()
let timelineStore = InMemoryReadModelStore<OrderTimeline>()

// Generated mappers — `OrderSummaryEventMapper` covers every event listed under
// OrderSummary in projection-model.yaml. Since both ReadModels list the same
// events, one mapper instance is enough for all coordinators below.
let mapper = OrderSummaryEventMapper()

let summaryProjector = OrderSummaryProjector(
    coordinator: KurrentStorageCoordinator<OrderSummaryProjector>(client: kdbClient, eventMapper: mapper)
)
let timelineProjector = OrderTimelineProjector(
    coordinator: KurrentStorageCoordinator<OrderTimelineProjector>(client: kdbClient, eventMapper: mapper)
)

let summaryStateful = StatefulEventSourcingProjector(projector: summaryProjector, store: summaryStore)
let timelineStateful = StatefulEventSourcingProjector(projector: timelineProjector, store: timelineStore)

let runner = KurrentProjection.PersistentSubscriptionRunner(
    client: kdbClient,
    stream: stream,
    groupName: groupName
)
.register(summaryStateful) { record in
    orderId(from: record).map { OrderSummaryInput(id: $0) }
}
.register(timelineStateful) { record in
    orderId(from: record).map { OrderTimelineInput(id: $0) }
}

print("✓ Runner configured with 2 projectors (OrderSummary + OrderTimeline)\n")

// 3. Run the runner in a background task, publish events, observe convergence,
//    then cancel for graceful shutdown.
try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask {
        do {
            try await runner.run()
        } catch is CancellationError {
            // Expected on graceful shutdown.
        } catch {
            print("Runner exited with error: \(error)")
        }
    }

    // Give the subscription a moment to connect before publishing.
    try await Task.sleep(for: .milliseconds(500))

    // Publish 3 events for one order on the aggregate stream "Order-{id}".
    let id = "order-demo-\(UUID().uuidString.prefix(6))"
    print("── Publishing events for \(id) ──")

    let events: [any DomainEvent] = [
        OrderCreated(orderId: id, customerId: "alice", totalAmount: 100),
        OrderAmountUpdated(orderId: id, newAmount: 150),
        OrderAmountUpdated(orderId: id, newAmount: 175),
    ]

    let appendCoordinator = KurrentStorageCoordinator<OrderSummaryProjector>(
        client: kdbClient, eventMapper: mapper
    )
    _ = try await appendCoordinator.append(
        events: events, byId: id, version: nil, external: nil
    )
    print("✓ Appended \(events.count) events\n")

    // Wait for both projectors to converge (both stores have the latest revision).
    print("── Waiting for projectors to catch up ──")
    let deadline = Date().addingTimeInterval(8.0)
    while Date() < deadline {
        let s = try await summaryStore.fetch(byId: id)
        let t = try await timelineStore.fetch(byId: id)
        if let s, let t,
           s.readModel.totalAmount == 175,
           t.readModel.entries.count == 3 {
            break
        }
        try await Task.sleep(for: .milliseconds(200))
    }

    // Read final state.
    let summary = try await summaryStore.fetch(byId: id)
    let timeline = try await timelineStore.fetch(byId: id)

    print("\n── Final read models ──")
    if let s = summary?.readModel {
        print("OrderSummary[\(s.id)]:")
        print("  customer:    \(s.customerId)")
        print("  totalAmount: \(s.totalAmount)")
        print("  status:      \(s.status)")
    } else {
        print("OrderSummary: not found (projector did not converge)")
    }
    if let t = timeline?.readModel {
        print("\nOrderTimeline[\(t.id)]:")
        for entry in t.entries {
            print("  • \(entry)")
        }
    } else {
        print("OrderTimeline: not found (projector did not converge)")
    }

    print("\n=== Done ===")

    // Cancel the runner — graceful shutdown.
    // run() observes Task.isCancelled between events and returns normally.
    group.cancelAll()
}
