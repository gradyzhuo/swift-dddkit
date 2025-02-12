//
//  EventDefinition.swift
//  
//
//  Created by 卓俊諺 on 2025/2/11.
//
import Foundation

package struct EventDefinition: Codable {
    var migration: MigrationDefinition?
    var aggregateRootId: AggregateRootIdDefinition
    var properties: [PropertyDefinition]?
    var deprecated: Bool?
}

extension EventDefinition {
    package struct AggregateRootIdDefinition: Codable {
        let alias: String
    }
}
