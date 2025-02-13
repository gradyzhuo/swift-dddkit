//
//  EventProjectionDefinition.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/12.
//

import Foundation
import DDDCore

package struct EventProjectionDefinition: Codable {
    let idType: PropertyDefinition.PropertyType = .string
    let model: ModelKind
    let createdEvent: String
    let deletedEvent: String?
    let events: [String]
}


extension EventProjectionDefinition{
    enum ModelKind: String, Codable {
        case aggregateRoot
        case readModel
        
        var `protocol`: String {
            switch self {
            case .aggregateRoot:
                "\((any AggregateRoot).self)"
            case .readModel:
                "\((any ReadModel).self)"
            }
        }
    }
}
