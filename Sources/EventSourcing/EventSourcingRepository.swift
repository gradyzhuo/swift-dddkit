import DDDCore
import Foundation

public protocol EventSourcingRepository<StorageCoordinator>: Repository {
    associatedtype StorageCoordinator: EventStorageCoordinator<AggregateRootType>

    var coordinator: StorageCoordinator { get }
}

extension EventSourcingRepository {
    public func find(byId id: AggregateRootType.ID) async throws -> AggregateRootType? {
        return try await self.find(byId: id, hiddingDeleted: true)
    }
    
    public func find(byId id: AggregateRootType.ID, hiddingDeleted: Bool) async throws -> AggregateRootType? {
        let streamName = AggregateRootType.getStreamName(id: id)
        guard var events = try await coordinator.fetchEvents(byStreamName: streamName) else {
            return nil
        }

        guard !(hiddingDeleted && (events.contains { $0 is AggregateRootType.DeletedEventType })) else {
            return nil
        }

        let deletedEvent = events.first {
            $0 is AggregateRootType.DeletedEventType
        } as? AggregateRootType.DeletedEventType

        events.removeAll {
            $0 is AggregateRootType.DeletedEventType
        }

        let aggregateRoot = try AggregateRootType(events: events)

        if let deletedEvent {
            try aggregateRoot?.apply(event: deletedEvent)
        }

        try aggregateRoot?.clearAllDomainEvents()

        return aggregateRoot
    }

    public func save(aggregateRoot: AggregateRootType) async throws {
        let streamName = AggregateRootType.getStreamName(id: aggregateRoot.id)
        let latestRevision: UInt? = try await coordinator.append(events: aggregateRoot.events, byStreamName: streamName, version: aggregateRoot.version)
        aggregateRoot.metadata.version = latestRevision
        try aggregateRoot.clearAllDomainEvents()
    }

    public func delete(aggregateRoot: AggregateRootType) async throws {
        try aggregateRoot.markAsDelete()

        try await save(aggregateRoot: aggregateRoot)
    }
}
