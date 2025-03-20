import DDDCore
import EventSourcing
import EventStoreDB
import Foundation
import Logging

public class KurrentStorageCoordinator<ProjectableType: Projectable>: EventStorageCoordinator {
    let eventMapper: any EventTypeMapper
    let client: EventStoreDBClient

    public init(client: EventStoreDBClient, eventMapper: any EventTypeMapper) {
        self.eventMapper = eventMapper
        self.client = client
    }

    public func append(events: [any DDDCore.DomainEvent], byId id: ProjectableType.ID, version: UInt64?, external: [String:String]?) async throws -> UInt64? {
        let streamName = ProjectableType.getStreamName(id: id)
        let events = try events.map {
            let customMetadata = CustomMetadata(
                className: "\(type(of: $0))",
                external: external
            )
            let encoder = JSONEncoder()
            return try EventData(id: $0.id, eventType: $0.eventType, payload: $0, customMetadata: encoder.encode(customMetadata))
        }

        let response = try await client.appendStream(to: .init(name: streamName), events: events) { options in
            guard let version else {
                return options.revision(expected: .any)
            }
            return options.revision(expected: .revision(UInt64(version)))
        }

        return response.currentRevision.flatMap {
            .init($0)
        }
    }

    public func fetchEvents(byId id: ProjectableType.ID) async throws -> (events: [any DomainEvent], latestRevision: UInt64)? {
        let logger = Logger(label: "KurrentStorageCoordinator")
        let streamName = ProjectableType.getStreamName(id: id)
        do{
            let responses = try await client.readStream(to: .init(name: streamName), cursor: .start) { options in
                options.set(resolveLinks: true)
            }

            let eventWrappers: [(event: any DomainEvent, revision: UInt64)] = try await responses.reduce(into: .init()) {
                guard case let .event(readEvent) = $1.content else {
                    return
                }
                
                guard let event = try self.eventMapper.mapping(eventData: readEvent.recordedEvent) else {
                    return
                }
                
                $0.append((event: event, revision: readEvent.recordedEvent.revision))
            }
            
            guard let latestRevision = eventWrappers.last?.revision else {
                return nil
            }
            
            let events = eventWrappers.map(\.event)
            let sortedEvents = events.sorted {
                $0.occurred < $1.occurred
            }
            
            return (events: sortedEvents, latestRevision: latestRevision)
        }catch EventStoreError.resourceNotFound(let reason){
            logger.warning("Skip an error happened in esdb, with reason: \(reason)")
            return nil
        }catch{
            logger.error("The error happened when fetching events: \(error)")
            throw error
        }
    }
}
