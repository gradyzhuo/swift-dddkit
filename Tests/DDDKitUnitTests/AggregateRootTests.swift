import Testing
import Foundation
@testable import DDDCore

// MARK: - Fixtures

struct OrderCreated: DomainEvent {
    typealias Metadata = Never
    var id: UUID = .init()
    var occurred: Date = .now
    var aggregateRootId: String
    var metadata: Never? = nil
    var value: String
}

struct OrderEdited: DomainEvent {
    typealias Metadata = Never
    var id: UUID = .init()
    var occurred: Date = .now
    var aggregateRootId: String
    var metadata: Never? = nil
    var value: String
}

struct OrderDeleted: DeletedEvent {
    typealias Metadata = Never
    var id: UUID
    var occurred: Date
    var aggregateRootId: String
    var metadata: Never? = nil

    init(id: UUID = .init(), aggregateRootId: String, occurred: Date = .now) {
        self.id = id
        self.aggregateRootId = aggregateRootId
        self.occurred = occurred
    }
}

class Order: AggregateRoot {
    typealias DeletedEventType = OrderDeleted

    let id: String
    private(set) var value: String = ""
    private(set) var whenCallCount: Int = 0
    private(set) var invariantCallCount: Int = 0
    var metadata: AggregateRootMetadata = .init()

    init(id: String, value: String) throws {
        self.id = id
        try apply(event: OrderCreated(aggregateRootId: id, value: value))
    }

    required init?(events: [any DomainEvent]) throws {
        guard let first = events.first as? OrderCreated else { return nil }
        self.id = first.aggregateRootId
        try apply(events: events)
    }

    func when(happened event: some DomainEvent) throws {
        whenCallCount += 1
        switch event {
        case let e as OrderCreated: value = e.value
        case let e as OrderEdited:  value = e.value
        case is OrderDeleted:       metadata.delete()
        default: break
        }
    }

    func ensureInvariant() throws {
        invariantCallCount += 1
    }
}

// MARK: - AggregateRoot Tests

@Suite("AggregateRoot")
struct AggregateRootTests {

    @Test("apply 後 event 寫入 metadata.events")
    func applyAddsEventToMetadata() throws {
        let order = try Order(id: "order-1", value: "hello")
        #expect(order.events.count == 1)
        #expect(order.events.first is OrderCreated)
    }

    @Test("apply 呼叫 when(happened:)")
    func applyCallsWhen() throws {
        let order = try Order(id: "order-1", value: "hello")
        #expect(order.value == "hello")
        #expect(order.whenCallCount == 1)
    }

    @Test("apply 在 when 前後各呼叫一次 ensureInvariant")
    func applyCallsInvariantTwice() throws {
        let order = try Order(id: "order-1", value: "hello")
        // init apply 觸發：before + after = 2
        #expect(order.invariantCallCount == 2)
    }

    @Test("apply 多個 events 正確累積狀態")
    func applyMultipleEvents() throws {
        let order = try Order(id: "order-1", value: "hello")
        try order.apply(event: OrderEdited(aggregateRootId: "order-1", value: "world"))
        #expect(order.value == "world")
        #expect(order.events.count == 2)
    }

    @Test("deleted aggregate 無法再 apply")
    func applyOnDeletedThrows() throws {
        let order = try Order(id: "order-1", value: "hello")
        try order.markDelete()
        #expect(throws: (any Error).self) {
            try order.apply(event: OrderEdited(aggregateRootId: "order-1", value: "world"))
        }
    }

    @Test("markDelete 後 deleted 為 true")
    func markDeleteSetsDeleted() throws {
        let order = try Order(id: "order-1", value: "hello")
        #expect(order.deleted == false)
        try order.markDelete()
        #expect(order.deleted == true)
    }

    @Test("markDelete 產生 DeletedEvent 並寫入 metadata")
    func markDeleteAddsDeletedEvent() throws {
        let order = try Order(id: "order-1", value: "hello")
        try order.markDelete()
        #expect(order.events.last is OrderDeleted)
    }

    @Test("clearAllDomainEvents 清空 metadata.events")
    func clearEvents() throws {
        let order = try Order(id: "order-1", value: "hello")
        try order.apply(event: OrderEdited(aggregateRootId: "order-1", value: "world"))
        try order.clearAllDomainEvents()
        #expect(order.events.isEmpty)
    }

    @Test("update(version:) 更新 metadata.version")
    func updateVersion() throws {
        let order = try Order(id: "order-1", value: "hello")
        #expect(order.version == nil)
        order.update(version: 42)
        #expect(order.version == 42)
    }

    @Test("init?(events:) 從 events 重建狀態")
    func initFromEvents() throws {
        let events: [any DomainEvent] = [
            OrderCreated(aggregateRootId: "order-1", value: "hello"),
            OrderEdited(aggregateRootId: "order-1", value: "world"),
        ]
        let order = try Order(events: events)
        #expect(order?.id == "order-1")
        #expect(order?.value == "world")
    }

    @Test("init?(events:) 首個 event 型別不符時回傳 nil")
    func initFromEventsReturnNilWhenFirstEventWrong() throws {
        let events: [any DomainEvent] = [
            OrderEdited(aggregateRootId: "order-1", value: "world"),
        ]
        let order = try Order(events: events)
        #expect(order == nil)
    }
}

// MARK: - EventStreamNaming Tests

final class CustomCategoryOrder: AggregateRoot {
    typealias DeletedEventType = OrderDeleted
    let id: String
    var metadata: AggregateRootMetadata = .init()
    static var categoryRule: StreamCategoryRule { .custom("orders") }

    required init?(events: [any DomainEvent]) throws {
        guard let first = events.first as? OrderCreated else { return nil }
        self.id = first.aggregateRootId
        try apply(events: events)
    }

    func when(happened event: some DomainEvent) throws {}
}

@Suite("EventStreamNaming")
struct EventStreamNamingTests {

    @Test("category 預設從型別名稱推導")
    func categoryFromClassName() {
        #expect(Order.category == "Order")
    }

    @Test("getStreamName 回傳 {category}-{id}")
    func getStreamName() {
        #expect(Order.getStreamName(id: "order-1") == "Order-order-1")
    }

    @Test("custom category rule 使用自訂字串")
    func customCategoryRule() {
        #expect(CustomCategoryOrder.category == "orders")
        #expect(CustomCategoryOrder.getStreamName(id: "1") == "orders-1")
    }
}

// MARK: - DomainEvent Tests

@Suite("DomainEvent")
struct DomainEventTests {

    @Test("eventType 預設為 Swift 型別名稱")
    func eventTypeDefaultsToTypeName() {
        let event = OrderCreated(aggregateRootId: "1", value: "v")
        #expect(event.eventType == "OrderCreated")
    }
}
