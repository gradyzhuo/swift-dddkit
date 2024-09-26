import DDDCore

private struct EventSubscriber{
    let eventName: String
    let handle: (any DomainEvent) async throws -> Void
}

public class EventBus: DomainEventBus {
    private var eventSubscribers: [EventSubscriber]

    public func publish(event: some DomainEvent) async throws {
        for eventSubscriber in eventSubscribers {
            if eventSubscriber.eventName == event.eventType {
                try await eventSubscriber.handle(event)
            }
        }
    }

    public func subscribe<EventType: DomainEvent>(to eventType: EventType.Type, handler: @escaping (_ event: EventType) async throws -> Void) rethrows {
        let eventTypeString = "\(eventType)"
        let subscriber = EventSubscriber(eventName: eventTypeString){ event async throws in
            if let typedEvent = event as? EventType {
                try await handler(typedEvent)
            }
        }
        eventSubscribers.append(subscriber)
    }

    public init() {
        eventSubscribers = []
    }
}