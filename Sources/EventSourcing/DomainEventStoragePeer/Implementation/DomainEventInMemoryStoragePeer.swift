//
//  DomainEventInMemoryStoragePeer.swift
//
//
//  Created by 卓俊諺 on 2024/5/27.
//

import Foundation

public class DomainEventInMemoryStoragePeer: DomainEventStoragePeer {
    public init(events: [any DomainEvent] = []) {
        self.events = events
    }

    public var events: [any DomainEvent] = []
}
