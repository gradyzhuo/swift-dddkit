import Foundation

public protocol EventStorageCoordinator<AggregateRootType>: AnyObject {
    associatedtype AggregateRootType: AggregateRoot

    func fetchEvents(byId id: AggregateRootType.Id) async throws -> [any DomainEvent]?
    func append(event: any DomainEvent, byId aggregateRootId: AggregateRootType.Id) async throws -> UInt64?
}
