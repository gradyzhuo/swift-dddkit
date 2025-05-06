import Foundation

public protocol DomainEventListener {
    associatedtype EventType: DomainEvent

    func observed(event: EventType) async throws
}


extension DomainEventBus {
    public func register<Listener: DomainEventListener>(listener: Listener) throws {
        try subscribe(to: Listener.EventType.self) { event in
            try await listener.observed(event: event)
        }
    }
}
