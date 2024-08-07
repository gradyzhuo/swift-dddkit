public protocol DTO: Projectable {

    init?(event: any DomainEvent) throws

}

extension DTO {
    // public init?(events: [any DomainEvent]) throws {
    //     let sortedEvents = events.sorted {
    //         $0.occurred < $1.occurred
    //     }

    //     try self.init(events: sortedEvents)
    // }

    public func restore(event: some DomainEvent) throws {
        try ensureInvariant()
        try when(happened: event)
        try ensureInvariant()
    }

    // public func restore(events: [any DomainEvent]) throws {
    //     for event in events {
    //         try restore(event: event)
    //     }
    // }

    public func ensureInvariant() throws {}
}