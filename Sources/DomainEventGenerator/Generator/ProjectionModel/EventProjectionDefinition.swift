//
//  EventProjectionDefinition.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/12.
//

import Foundation

package struct EventProjectionDefinition: Codable {
    package var idType: PropertyDefinition.PropertyType
    package let model: ModelKind
    package let createdEvent: String
    package let deletedEvent: String?
    package var events: [String]
    
    
    package init(idType: PropertyDefinition.PropertyType, model: ModelKind, createdEvent: String, deletedEvent: String?, events: [String]) {
        self.idType = idType
        self.model = model
        self.createdEvent = createdEvent
        self.deletedEvent = deletedEvent
        self.events = events
    }
    
    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.idType = try container.decodeIfPresent(PropertyDefinition.PropertyType.self, forKey: .idType) ?? .string
        self.model = try container.decode(EventProjectionDefinition.ModelKind.self, forKey: .model)
        self.createdEvent = try container.decode(String.self, forKey: .createdEvent)
        self.deletedEvent = try container.decodeIfPresent(String.self, forKey: .deletedEvent)
        self.events = try container.decodeIfPresent([String].self, forKey: .events) ?? []
    }
}


extension EventProjectionDefinition{
    package enum ModelKind: String, Codable {
        case aggregateRoot
        case readModel
        
        var `protocol`: String {
            switch self {
            case .aggregateRoot:
                "AggregateRoot"
            case .readModel:
                "ReadModel"
            }
        }
    }
}
