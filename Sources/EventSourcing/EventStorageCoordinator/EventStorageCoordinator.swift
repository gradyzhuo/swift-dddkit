import DDDCore
import Foundation

public protocol EventStorageCoordinator<ProjectableType>: AnyObject {
    associatedtype ProjectableType: Projectable

    func fetchEvents(byId id: ProjectableType.ID) async throws -> [any DomainEvent]?
    func append(events: [any DomainEvent], byId id: ProjectableType.ID, version: UInt?) async throws -> UInt?
}
