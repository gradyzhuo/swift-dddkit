//
//  EventDefinition.swift
//  
//
//  Created by 卓俊諺 on 2025/2/11.
//
import Foundation
import DDDCore

package struct EventDefinition: Codable {
    var migration: MigrationDefinition?
    var kind: EventKind = .domainEvent
    var aggregateRootId: AggregateRootIdDefinition
    var properties: [PropertyDefinition]?
    var deprecated: Bool?
    
    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.migration = try container.decodeIfPresent(MigrationDefinition.self, forKey: .migration)
        let kind = try container.decodeIfPresent(EventDefinition.EventKind.self, forKey: .kind)
        self.kind = kind ?? .domainEvent
        self.aggregateRootId = try container.decode(EventDefinition.AggregateRootIdDefinition.self, forKey: .aggregateRootId)
        self.properties = try container.decodeIfPresent([PropertyDefinition].self, forKey: .properties)
        self.deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
    }
}

extension EventDefinition{
    enum EventKind: String, Codable{
        case createdEvent
        case domainEvent
        case deletedEvent
        
        var `protocol`: String{
            switch self {
            case .createdEvent:
                "\((any DomainEvent).self)"
            case .deletedEvent:
                "\((any DeletedEvent).self)"
            case .domainEvent:
                "\((any DomainEvent).self)"
            }
        }
    }
}

extension EventDefinition {
    package struct AggregateRootIdDefinition: Codable {
        let alias: String
    }
}
