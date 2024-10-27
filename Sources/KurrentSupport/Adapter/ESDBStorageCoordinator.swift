import DDDCore
import EventSourcing
import EventStoreDB
import Foundation

public class KurrentStorageCoordinator<ProjectableType: Projectable>: EventStorageCoordinator {
    let eventMapper: any EventTypeMapper
    let client: EventStoreDBClient

    public init(client: EventStoreDBClient, eventMapper: any EventTypeMapper) {
        self.eventMapper = eventMapper
        self.client = client
    }

    public func append(events: [any DDDCore.DomainEvent], byId id: ProjectableType.ID, version: UInt?) async throws -> UInt? {
        let streamName = ProjectableType.getStreamName(id: id)
        let events = try events.map {
            try EventData(id: $0.id, eventType: $0.eventType, payload: $0)
        }

        let response = try await client.appendStream(to: .init(name: streamName), events: events) { options in
            guard let version else {
                return options.revision(expected: .any)
            }
            return options.revision(expected: .revision(UInt64(version)))
        }

        return response.current.revision.flatMap {
            .init($0)
        }
    }

    public func fetchEvents(byId id: ProjectableType.ID) async throws -> (events: [any DomainEvent], latestRevision: UInt64)? {
        let streamName = ProjectableType.getStreamName(id: id)
        do{
            let responses = try client.readStream(to: .init(name: streamName), cursor: .start) { options in
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
            
            let sortedEventWrappers = eventWrappers.sorted(using: KeyPathComparator(\.revision, order: .reverse))
            guard let latestRevision = sortedEventWrappers.first?.revision else {
                return nil
            }
            
            let events = sortedEventWrappers.map(\.event)
            return (events: events, latestRevision: latestRevision)
            
        }catch ClientError.streamNotFound(let message){
            print("KurrentError streamNotFound: \(message)")
            return nil
        }catch {
            throw error
        }
    }
}
