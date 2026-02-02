//
//  AggregateRootMetadata.swift
//
//
//  Created by Grady Zhuo on 2024/6/4.
//

import Foundation

public struct AggregateRootMetadata {
    var events: [any DomainEvent] = []

    public package(set) var deleted: Bool
    public package(set) var version: UInt64?

    public init() {
        deleted = false
        version = nil
    }
    
    public mutating func delete() {
        self.deleted = true
    }
    
    public mutating func update(version: UInt64){
        self.version = version
    }
}
