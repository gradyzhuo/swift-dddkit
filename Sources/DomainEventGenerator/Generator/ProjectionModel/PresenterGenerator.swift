//
//  AggregateHelperGenerator.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/12.
//

import Foundation
import Yams

package struct PresenterGenerator {
    package let definitions: [String: EventProjectionDefinition]
    
    package init(projectionModelYamlFileURL: URL) throws {
        let yamlData = try Data(contentsOf: projectionModelYamlFileURL)

        let yamlDecoder = YAMLDecoder()
        var definitions: [String: EventProjectionDefinition]
        do{
            if yamlData.isEmpty {
                throw DomainEventGeneratorError.invalidYamlFile(url: projectionModelYamlFileURL, reason: "The yaml file is empty.")
            }
            
            definitions = try yamlDecoder.decode([String: EventProjectionDefinition].self, from: yamlData)
        }catch{
            definitions = [:]
        }
        
        self.definitions = definitions
    }
    
    
    package func render(accessLevel: AccessLevel) -> [String] {
        var lines: [String] = []
        
        for (modelName, definition) in definitions{
            
            let protocolName = "\(modelName)PresenterProtocol"

            var whereExpression = "ID == \(definition.idType.name)"
            
            //MARK: protocol definition generated
            ///
            /// package protocol TestReadModelPresenterProtocol: EventSourcingPresenter {
            ///      func when(event: EventA) throws
            ///      func when(event: EventB) throws
            /// }
            ///
            lines.append("\(accessLevel.rawValue) protocol \(protocolName): EventSourcingPresenter where \(whereExpression){")
            
            for eventName in definition.events{
                lines.append("   func when(event: \(eventName)) throws")
            }
            if let deletedEvent = definition.deletedEvent {
                lines.append("   func when(event: \(deletedEvent)) throws")
            }
            lines.append("}")
            lines.append("")
            
            
            //MARK: - preimplemented function
            // `init` begin
            lines.append("""
extension \(protocolName) {
    public func apply(events: [any DomainEvent]) throws {
        for event in events {
            switch event {
""")
            for eventName in definition.events{
                lines.append("""
            case let e as \(eventName):
            try when(event: e)
""")
            }
            
            lines.append("""
            default:
                return
            }
        }
    }
""")
            lines.append("}")
            lines.append("")
        }
        
        return lines
    }
}


enum PresenterGeneratorError: Error{
    case invalidCreatedEvent
}
