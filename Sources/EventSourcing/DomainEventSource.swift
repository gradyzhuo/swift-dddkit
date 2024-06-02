import DDDCore
import Foundation

public protocol DomainEventSource {
    associatedtype Storage: DomainEventStoragePeer

    var eventStorage: Storage { get }
    var revision: UInt64? { set get }

    func apply(event: some DomainEvent) throws

    init?(events: [any DomainEvent]) throws
}

extension DomainEventSource {
    public var events: [DomainEvent] {
        eventStorage.events
    }

    public func add(event: some DomainEvent) throws {
        eventStorage.events.append(event)
        try apply(event: event)
    }

    public func clearAllDomainEvents() throws {
        eventStorage.events.removeAll()
    }
}
