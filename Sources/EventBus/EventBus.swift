import DDDCore

public class EventBus: DomainEventBus {
    private var eventSubscribers: [String: (any DomainEvent) async throws -> Void]

    public func publish(event: some DomainEvent) async throws {
        let handler = eventSubscribers[event.eventType]
        try await handler?(event)
    }

    public func subscribe<EventType: DomainEvent>(to eventType: EventType.Type, handler: @escaping (_ event: EventType) async throws -> Void) rethrows {
        let eventTypeString = "\(eventType)"
        eventSubscribers[eventTypeString] = { event async throws in
            if let typedEvent = event as? EventType {
                try await handler(typedEvent)
            }
        }
    }

    public init() {
        eventSubscribers = [:]
    }
}
