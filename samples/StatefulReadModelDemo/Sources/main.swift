import Foundation
import DDDCore
import EventSourcing
import ReadModelPersistence

// MARK: - Domain Events

struct OrderCreated: DomainEvent {
    typealias Metadata = Never
    var id: UUID = .init()
    var occurred: Date = .now
    var metadata: Never? = nil
    let aggregateRootId: String
    let customerId: String
    let totalAmount: Double
}

struct OrderAmountUpdated: DomainEvent {
    typealias Metadata = Never
    var id: UUID = .init()
    var occurred: Date = .now
    var metadata: Never? = nil
    let aggregateRootId: String
    let newAmount: Double
}

struct OrderCancelled: DeletedEvent {
    typealias Metadata = Never
    var id: UUID = .init()
    var occurred: Date = .now
    var metadata: Never? = nil
    let aggregateRootId: String

    init(id: UUID, aggregateRootId: String, occurred: Date) {
        self.id = id
        self.aggregateRootId = aggregateRootId
        self.occurred = occurred
    }
}

// MARK: - Read Model

struct OrderSummary: ReadModel, Codable, Sendable {
    let id: String
    var customerId: String
    var totalAmount: Double
    var status: String
}

// MARK: - Projector Input

struct OrderProjectorInput: CQRSProjectorInput {
    let id: String
}

// MARK: - Projector

final class OrderProjector: StatefulEventSourcingProjector {
    typealias ReadModelType = OrderSummary
    typealias Input = OrderProjectorInput
    typealias StorageCoordinator = InMemoryStorageCoordinator

    static var categoryRule: StreamCategoryRule { .custom("Order") }

    let coordinator: InMemoryStorageCoordinator
    let store: InMemoryReadModelStore<OrderSummary>

    init(coordinator: InMemoryStorageCoordinator,
         store: InMemoryReadModelStore<OrderSummary>) {
        self.coordinator = coordinator
        self.store = store
    }

    // 第一次投影時建立初始 ReadModel（全量 replay 的起點）
    func buildReadModel(input: Input) throws -> OrderSummary? {
        OrderSummary(id: input.id, customerId: "", totalAmount: 0, status: "unknown")
    }

    // 折疊 events：全量與增量都走這裡，只需寫一次
    func apply(readModel: inout OrderSummary, events: [any DomainEvent]) throws {
        for event in events {
            switch event {
            case let e as OrderCreated:
                readModel.customerId = e.customerId
                readModel.totalAmount = e.totalAmount
                readModel.status = "active"
            case let e as OrderAmountUpdated:
                readModel.totalAmount = e.newAmount
            case is OrderCancelled:
                readModel.status = "cancelled"
            default:
                break
            }
        }
    }
}

// MARK: - Helper

func printModel(_ label: String, _ result: CQRSProjectorOutput<OrderSummary>?) {
    guard let m = result?.readModel else { print("\(label): nil\n"); return }
    print("""
    \(label):
      customerId:  \(m.customerId)
      totalAmount: \(m.totalAmount)
      status:      \(m.status)
    """)
}

// MARK: - Entry Point

@main
struct Demo {
    static func main() async throws {
        let coordinator = InMemoryStorageCoordinator()
        let store = InMemoryReadModelStore<OrderSummary>()
        let projector = OrderProjector(coordinator: coordinator, store: store)

        let orderId = "order-001"
        let input = OrderProjectorInput(id: orderId)

        print("=== Stateful ReadModel Demo ===\n")

        // Step 1: 建立訂單 → 全量 replay（store 無快照）
        print("── Step 1: OrderCreated")
        _ = try await coordinator.append(
            events: [OrderCreated(aggregateRootId: orderId,
                                  customerId: "customer-42",
                                  totalAmount: 1000)],
            byId: orderId, version: nil, external: nil)
        printModel("→ ReadModel (full replay)", try await projector.execute(input: input))

        // Step 2: 更新金額 → 增量 replay（只取上次快照後的 events）
        print("── Step 2: OrderAmountUpdated")
        _ = try await coordinator.append(
            events: [OrderAmountUpdated(aggregateRootId: orderId, newAmount: 1500)],
            byId: orderId, version: nil, external: nil)
        printModel("→ ReadModel (incremental)", try await projector.execute(input: input))

        // Step 3: 取消訂單 → 增量 replay
        print("── Step 3: OrderCancelled")
        _ = try await coordinator.append(
            events: [OrderCancelled(aggregateRootId: orderId)],
            byId: orderId, version: nil, external: nil)
        printModel("→ ReadModel (incremental)", try await projector.execute(input: input))

        print("=== Done ===")
    }
}
