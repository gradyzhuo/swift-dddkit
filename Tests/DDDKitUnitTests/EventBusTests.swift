import Testing
import Foundation
@testable import DDDCore
@testable import EventBus

// MARK: - Fixtures

struct UserRegistered: DomainEvent {
    typealias Metadata = Never
    var id: UUID = .init()
    var occurred: Date = .now
    var aggregateRootId: String
    var metadata: Never? = nil
    var username: String
}

struct UserDeactivated: DomainEvent {
    typealias Metadata = Never
    var id: UUID = .init()
    var occurred: Date = .now
    var aggregateRootId: String
    var metadata: Never? = nil
}

// MARK: - EventBus Tests

@Suite("EventBus")
struct EventBusTests {

    @Test("subscribe 後 publish 觸發正確 handler")
    func publishTriggersMatchingSubscriber() async throws {
        let bus = EventBus()
        var received: String? = nil

        await bus.subscribe(to: UserRegistered.self) { event in
            received = event.username
        }

        try await bus.publish(event: UserRegistered(aggregateRootId: "user-1", username: "grady"))
        #expect(received == "grady")
    }

    @Test("publish 不觸發不匹配的 event type")
    func publishDoesNotTriggerWrongSubscriber() async throws {
        let bus = EventBus()
        var triggered = false

        await bus.subscribe(to: UserDeactivated.self) { _ in
            triggered = true
        }

        try await bus.publish(event: UserRegistered(aggregateRootId: "user-1", username: "grady"))
        #expect(triggered == false)
    }

    @Test("同一 event type 多個 subscriber 全部觸發")
    func multipleSubscribersAllTriggered() async throws {
        let bus = EventBus()
        var count = 0

        await bus.subscribe(to: UserRegistered.self) { _ in count += 1 }
        await bus.subscribe(to: UserRegistered.self) { _ in count += 1 }

        try await bus.publish(event: UserRegistered(aggregateRootId: "user-1", username: "grady"))
        #expect(count == 2)
    }

    @Test("不同 event type 的 subscriber 互不干擾")
    func differentEventTypesDoNotCross() async throws {
        let bus = EventBus()
        var registeredCount = 0
        var deactivatedCount = 0

        await bus.subscribe(to: UserRegistered.self)   { _ in registeredCount += 1 }
        await bus.subscribe(to: UserDeactivated.self)  { _ in deactivatedCount += 1 }

        try await bus.publish(event: UserRegistered(aggregateRootId: "user-1", username: "grady"))

        #expect(registeredCount == 1)
        #expect(deactivatedCount == 0)
    }

    @Test("subscribe 前沒有 subscriber")
    func noSubscribersInitially() async throws {
        let bus = EventBus()
        #expect(bus.eventSubscribers.isEmpty)
    }

    @Test("subscribe 後 subscriber 數量增加")
    func subscriberCountIncreasesAfterSubscribe() async throws {
        let bus = EventBus()
        await bus.subscribe(to: UserRegistered.self) { _ in }
        await bus.subscribe(to: UserRegistered.self) { _ in }
        #expect(bus.eventSubscribers.count == 2)
    }
}
