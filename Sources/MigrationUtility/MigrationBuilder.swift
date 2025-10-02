//
//  MigrationBuilder.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/9/14.
//
import Foundation
import DDDCore
import EventSourcing
import KurrentSupport

public actor MigrationBuilder<MigrationType: Migration>: Sendable{

    private var createdHandler: MigrationType.CreatedHandler?
    private var handlers: [any MigrationHandler]
    
    public init() {
        self.handlers = []
    }
    
    @discardableResult
    public func `init`(action: @escaping @Sendable (_ event: MigrationType.CreatedEvent, _ userInfo: MigrationType.UserInfoType?) throws -> MigrationType.AggregateRootType ) rethrows ->Self {
        self.createdHandler = action
        return self
    }
    
    @discardableResult
    public func when<T: DomainEvent>(eventType: T.Type, action: @escaping @Sendable (_ aggregateRoot: MigrationType.AggregateRootType, _ event: T, _ userInfo: MigrationType.UserInfoType?) throws -> Void ) rethrows ->Self{
        let handler = EventTypeHandler<T, MigrationType.AggregateRootType, MigrationType.UserInfoType>(action: action)
        self.handlers.append(handler)
        return self
    }
    
    @discardableResult
    public func `else`(action: @escaping @Sendable (_ aggregateRoot: MigrationType.AggregateRootType, _ event: any DomainEvent, _ userInfo: MigrationType.UserInfoType?) throws -> Void ) rethrows ->Self{
        let handler = EventTypeHandler<AnyDomainEvent, MigrationType.AggregateRootType, MigrationType.UserInfoType>(action: action)
        self.handlers.append(handler)
        return self
    }
    
    public func build(eventMapper: MigrationType.EventMapper, userInfo: MigrationType.UserInfoType) -> MigrationType{
        return MigrationType(eventMapper: eventMapper, handlers: handlers, createdHandler: createdHandler, userInfo: userInfo)
    }
}
