//
//  AggregateHelperGenerator.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/12.
//

import Foundation
import Yams

package struct ProjectionModelGenerator {
    let definitions: [String: EventProjectionDefinition]
    
    package init(definitions: [String: EventProjectionDefinition]){
        self.definitions = definitions
    }
    
    package init(yamlFileURL: URL) throws {
        let yamlData = try Data(contentsOf: yamlFileURL)
        let yamlDecoder = YAMLDecoder()
        let definitions = try yamlDecoder.decode([String: EventProjectionDefinition].self, from: yamlData)
        self.init(definitions: definitions)
    }
    
    package init(yamlFilePath: String) throws {
        let url = URL(fileURLWithPath: yamlFilePath)
        try self.init(yamlFileURL: url)
    }
    
    package func render(accessLevel: AccessLevel) -> [String] {
        var lines: [String] = []
        
        for (modelName, definition) in definitions{
            let protocolName = "\(modelName.capitalized)\(definition.model.protocol)Protocol"
            lines.append("\(accessLevel.rawValue) protocol \(protocolName) {")
            for eventName in definition.events{
                lines.append("   func when(event: \(eventName)) throws")
            }
            lines.append("}")
            lines.append("")
            
            //created
            lines.append("extension \(protocolName) where Self: \(definition.model.protocol) {")
            lines.append("    typealias ID = \(definition.idType.name)")
            lines.append("    typealias CreatedEventType = \(definition.createdEvent)")
            if let deletedEvent = definition.deletedEvent{
                lines.append("    typealias DeletedEventType = \(deletedEvent)")
            }
            lines.append("}")
            lines.append("")
            
            //whens
            lines.append("""
extension \(protocolName) where Self: \(definition.model.protocol){
    \(accessLevel) func when(happened event: some DomainEvent) throws{
        switch event {
""")
            
            for eventName in definition.events{
                lines.append("""
            case let event as \(eventName):
            try when(event: event)
""")
            }
            lines.append("""
            default:
            break
""")
            lines.append("        }")
            lines.append("    }")
            lines.append("}")
            lines.append("")
        }
        
        return lines
    }
}
