import DDDCore
import Foundation

public protocol EventSourcingProjector<StorageCoordinator>: Projector {
    associatedtype StorageCoordinator: EventStorageCoordinator<ProjectableType>

    var coordinator: StorageCoordinator { get }
}

extension EventSourcingProjector {

    public func find(byId id: ProjectableType.ID) async throws -> ProjectableType? {
        guard let events = try await coordinator.fetchEvents(byId: id) else {
            return nil
        }

        let projectable = try ProjectableType(events: events)
        return projectable
    }
}