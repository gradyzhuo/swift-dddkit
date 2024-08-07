import DDDCore
import Foundation

public protocol EventSourcingProjection<StorageCoordinator>: Projection {
    associatedtype StorageCoordinator: EventStorageCoordinator<ProjectableType>

    var coordinator: StorageCoordinator { get }
}

extension EventSourcingProjection {

    public func find(byStreamName streamName: String) async throws -> ProjectableType? {
        guard let events = try await coordinator.fetchEvents(byStreamName: streamName) else {
            return nil
        }

        let projectable = try ProjectableType(events: events)
        return projectable
    }
}