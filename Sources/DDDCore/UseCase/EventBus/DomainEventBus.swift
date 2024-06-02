import Foundation

public protocol DomainEventBus {
    func publish<EventType: DomainEvent>(event: EventType) async throws
    func subscribe<EventType: DomainEvent>(to eventType: EventType.Type, handler: @escaping (_ event: EventType) async throws -> Void) rethrows
}

extension DomainEventBus {
    public func postAllEvent(fromAggregateRoot aggregateRoot: some AggregateRoot) async throws {
        for event in aggregateRoot.events {
            try await publish(event: event)
        }
    }

    public func register<Listener: DomainEventListener>(listener: Listener) throws {
        try subscribe(to: Listener.EventType.self) { event in
            try await listener.observed(event: event)
        }
    }
}
