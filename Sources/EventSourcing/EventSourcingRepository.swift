import DDDCore
import Foundation

public protocol EventSourcingRepository<AggregateRootType>: AnyObject {
    associatedtype AggregateRootType: AggregateRoot where AggregateRootType: DomainEventSource
    associatedtype EventStorageType: EventStorageCoordinator where EventStorageType.AggregateRootType == AggregateRootType
    typealias Id = AggregateRootType.Id

    var coordinator: EventStorageType { get }
}

extension EventSourcingRepository {
    public func find(byId id: Id) async throws -> AggregateRootType? {
        guard let events = try await coordinator.fetchEvents(byId: id) else {
            return nil
        }
        return try? .init(events: events)
    }

    public func save(aggregateRoot: AggregateRootType) async throws {
        var latestRevision: UInt64?
        for event in aggregateRoot.events {
            latestRevision = try await coordinator.append(event: event, byId: aggregateRoot.id)
        }
        aggregateRoot.revision
        try aggregateRoot.clearAllDomainEvents()
    }

    public func delete(byId _: Id) throws {
        // coordinators[id]?.events.removeAll()
    }
}
