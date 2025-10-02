//
//  AggregateRoot+Migration.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/9/17.
//

import DDDCore
import EventSourcing


extension AggregateRoot{
    public static func fromMigrated(createdEvent event: CreatedEventType) throws -> Self? {
        var aggregateRoot = try Self.init(events: [event])
        try aggregateRoot?.apply(event: event)
        return aggregateRoot
    }
}
