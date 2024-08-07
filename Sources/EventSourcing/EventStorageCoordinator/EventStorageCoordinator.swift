import DDDCore
import Foundation

public protocol EventStorageCoordinator<ProjectableType>: AnyObject {
    associatedtype ProjectableType: Projectable

    func fetchEvents(byStreamName streamName: String) async throws -> [any DomainEvent]?
    func append(events: [any DomainEvent], byStreamName streamName: String, version: UInt?) async throws -> UInt?
}
