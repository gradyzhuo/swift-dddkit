//
//  EventBus.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/4/23.
//
import DDDCore
import EventBus
import KurrentDB

extension EventBus{
    
    private func publish<Subscriber: EventSubscriber>(of subscriber: Subscriber, event: RecordedEvent) async throws{
        guard let event = try event.decode(to: Subscriber.Event.self) else {
            return
        }
        try await subscriber.handle(event)
    }
    
    public func postEvent(event: RecordedEvent) async throws {
        for subscriber in self.eventSubscribers {
            try await publish(of: subscriber, event: event)
        }
    }
}
