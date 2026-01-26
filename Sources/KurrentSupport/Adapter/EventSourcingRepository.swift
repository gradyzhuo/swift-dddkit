//
//  EventSourcingRepository.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/25.
//
import Foundation
import DDDCore
import EventSourcing

extension EventSourcingRepository {
    public func save(aggregateRoot: inout AggregateRootType, userId: String) async throws {
        try await self.save(aggregateRoot: &aggregateRoot, external: ["userId": userId])
    }
}

