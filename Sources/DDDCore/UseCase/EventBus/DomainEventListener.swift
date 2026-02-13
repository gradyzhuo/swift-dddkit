import Foundation

public protocol DomainEventListener {
    associatedtype EventType: DomainEvent

    func observed(event: EventType) async throws
}


extension DomainEventBus {
    public func register<Listener: DomainEventListener>(listener: Listener) async throws {
        try await subscribe(to: Listener.EventType.self) { event in
            try await listener.observed(event: event)
        }
    }
}
