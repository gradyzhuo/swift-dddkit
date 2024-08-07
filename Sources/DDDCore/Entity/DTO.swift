public protocol DTO: Projectable {

    init?(other events: [any DomainEvent]) throws

}

extension DTO {
    public init?(events: [any DomainEvent]) throws {
        let sortedEvents = events.sorted {
            $0.occurred < $1.occurred
        }

        try self.init(other: sortedEvents)
    }

    public func apply(event: some DomainEvent) throws {
        try ensureInvariant()
        try when(happened: event)
        try ensureInvariant()
    }

    public func apply(events: [any DomainEvent]) throws {
        for event in events {
            try apply(event: event)
        }
    }

    public func ensureInvariant() throws {}
}