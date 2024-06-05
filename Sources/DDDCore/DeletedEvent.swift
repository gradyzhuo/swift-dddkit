import Foundation

public protocol DeletedEvent: DomainEvent {
    init(aggregateId: String)
}
