public protocol ReadModel: Projectable, Codable {
    init?(events: [any DomainEvent]) throws
}

extension ReadModel {

    public func restore(event: some DomainEvent) throws {
        try ensureInvariant()
        try when(happened: event)
        try ensureInvariant()
    }

    public func restore(events: [any DomainEvent]) throws {
        for event in events {
            try restore(event: event)
        }
    }

    public func ensureInvariant() throws {}
}
