import DDDCore
import Foundation

public protocol EventStorageCoordinator<ProjectableType>: AnyObject {
    associatedtype ProjectableType: Projectable

    func fetchEvents(byId projectableId: ProjectableType.ID) async throws -> [any DomainEvent]?
    func append(events: [any DomainEvent], byId projectableId: ProjectableType.ID, version: UInt?) async throws -> UInt?
}
