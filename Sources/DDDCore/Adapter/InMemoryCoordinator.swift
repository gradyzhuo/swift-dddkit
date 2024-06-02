import Foundation

public struct InMemoryEventData<AggregateRootType: AggregateRoot> {
    let event: DomainEvent
    let aggregateRootId: AggregateRootType.Id
}

public actor InMemoryCoordinator<AggregateRootType: AggregateRoot>: EventStorageCoordinator {
    public func fetchEvents(byId id: AggregateRootType.Id) async throws -> [any DomainEvent]? {
        events.filter {
            $0.aggregateRootId == id
        }.map(\.event)
    }

    public func append(event: any DomainEvent, byId aggregateRootId: AggregateRootType.Id) async throws -> UInt64? {
        events.append(.init(event: event, aggregateRootId: aggregateRootId))
        return nil
    }

    public internal(set) var events: [InMemoryEventData<AggregateRootType>]

    public init() {
        events = []
    }

    // public func append(event: any DomainEvent) async throws {
    //     self.events.append(event)
    // }
}
