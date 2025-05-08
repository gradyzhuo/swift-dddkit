//
//  EventBus.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/4/23.
//
import DDDCore
import KurrentDB

extension DomainEventBus where Subscriber: EventSubscriber{
    
    private func publish(of subscriber: Subscriber, event: RecordedEvent) async throws{
        do{
            guard let event = try event.decode(to: Subscriber.Event.self) else {
                return
            }
            try await subscriber.handle(event)
        }catch{
            logger.debug("event handler failed, error: \(error).")
        }
    }
    
    public func postEvent(event: RecordedEvent) async throws {
        for subscriber in self.eventSubscribers {
            try await publish(of: subscriber, event: event)
        }
    }
    
    public func postEvent(event: ReadEvent) async throws {
        try await self.postEvent(event: event.record)
    }

}
