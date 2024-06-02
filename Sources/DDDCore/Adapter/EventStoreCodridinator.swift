// import Foundation
// import EventStoreDB
//
// public protocol EventTypeMapper {
//    func mapping(eventType: String, payload: Data) -> DomainEvent?
//
//    init()
// }
//
// public class KurrentStorageCoordinator<AggregateRootType: AggregateRoot, Mapper: EventTypeMapper>: EventStorageCoordinator {
//
//    func makeStreamName(id: AggregateRootType.Id) -> String {
//        return "\(self.streamPrefix)-\(id)"
//    }
//    // public var events: [any DomainEvent] {
//    //     get async throws {
//        //     let client = try EventStoreDB.Client()
//        //     let responses = try client.read(streamName: streamName, cursor: .start)
//        //     let events: [ReadEvent?] = await responses.map{
//        //         return switch $0.content {
//        //             case .event(let readEvent):
//        //                 readEvent.recordedEvent.eventType
//        //                 let decoder = JSONDecoder()
//        //                 decoder.decode(type: Decodable.Type, from: data)
//        //             default:
//        //                 nil
//        //         }
//        //     }
//        // return []
//    //     }
//    // }
//    var latestRevision: UInt64?
//    let mapper: Mapper
//    let streamPrefix: String
//
//    public init(mapper: Mapper, streamPrefix: String){
//        self.mapper = mapper
//        self.streamPrefix = streamPrefix
//    }
//
//    public func append(event: any DomainEvent, byId aggregateRootId: AggregateRootType.Id) async throws -> UInt64? {
//        let streamName = makeStreamName(id: aggregateRootId)
//        let client = try EventStoreDB.Client()
//        let events:[EventData] = [
//            try .init(eventType: event.eventType, payload: event)
//        ]
//        let response = try await client.appendTo(streamName: streamName, events: events){ option in
//            if let latestRevision {
//                return option.expectedRevision(.revision(latestRevision))
//            }
//            return option
//        }
//
//        return response.current.revision
//
//        // latestRevision = response.current.revision
//    }
//
//    public func fetchEvents(byId id: AggregateRootType.Id) async throws -> [any DomainEvent]? {
//        let client = try EventStoreDB.Client()
//        let streamName = makeStreamName(id: id)
//        let responses = try client.read(streamName: streamName, cursor: .start)
//
//        return await responses.reduce(into: nil) {
//            guard case let .event(readEvent) = $1.content else {
//                return
//            }
//
//            guard let event = self.mapper.mapping(eventType: readEvent.recordedEvent.eventType, payload: readEvent.recordedEvent.data) else {
//                return
//            }
//
//            if $0 == nil {
//                $0 = .init()
//            }
//            $0?.append(event)
//        }
//    }
// }
