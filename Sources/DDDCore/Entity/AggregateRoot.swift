import Foundation

public protocol AggregateRoot: Entity {
    associatedtype EventType: DomainEvent

    var events: [EventType] { get }
}
