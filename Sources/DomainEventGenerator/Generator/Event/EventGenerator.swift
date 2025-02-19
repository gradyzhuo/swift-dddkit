//
//  EventGenerator.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/11.
//
import Foundation
import Yams

enum GenerationError: Error {
    case noCreatedEvent
}

package struct EventGenerator {
    package let events: [Event]
    
    package var eventNames: [String] {
        get {
            events.map{ $0.name }
        }
    }
    
//    package var createdEventName: String {
//        get throws {
//            let filteredVaildCreatedEventDefinition: [(String, EventDefinition)] = definitions.filter{
//                let deprecated = $0.value.deprecated ?? false
//                return !deprecated && $0.value.kind == .createdEvent
//            }
//            guard let createdEventTuple = filteredVaildCreatedEventDefinition.first else {
//                throw GenerationError.noCreatedEvent
//            }
//            return createdEventTuple.0
//        }
//    }
//    
//    package var deletedEventName: String? {
//        get throws {
//            let filteredVaildCreatedEventDefinition: [(String, EventDefinition)] = definitions.filter{
//                let deprecated = $0.value.deprecated ?? false
//                return !deprecated && $0.value.kind == .deletedEvent
//            }
//            return filteredVaildCreatedEventDefinition.first?.0
//        }
//    }
//    
    package init(events: [Event]){
        self.events = events
    }
    
    package init(events collection: EventDefinitionCollection){
        self.events = collection.events
    }
    
    package init(yamlFileURL: URL) throws {
        let yamlData = try Data(contentsOf: yamlFileURL)
        let yamlDecoder = YAMLDecoder()
        let collection = try yamlDecoder.decode(EventDefinitionCollection.self, from: yamlData)
        self.init(events: collection.events)
    }
    
    package init(yamlFilePath: String) throws {
        let url = URL(fileURLWithPath: yamlFilePath)
        try self.init(yamlFileURL: url)
    }
    
    package func render(accessLevel: AccessLevel) -> [String] {
        var lines: [String] = []

        for event in events {
            let eventGenerator = EventStructureGenerator(event: event)
            lines.append(contentsOf: eventGenerator.render(accessLevel: accessLevel))
            lines.append("")
            
            //extension
            let extensionGenerator = EventAggregateRootIdExtensionGenerator(event: event)
            lines.append(contentsOf: extensionGenerator.render(accessLevel: accessLevel))
            lines.append("")
            
            if let migration = event.definition.migration {
                let migrationGenerator = EventMigrationExtensionGenerator(eventName: event.name, definition: migration)
                lines.append(contentsOf: migrationGenerator.render(accessLevel: accessLevel))
            }
            lines.append("")
        }
        return lines
    }
}
