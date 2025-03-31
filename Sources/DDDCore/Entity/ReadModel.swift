public protocol ReadModel: Projectable, Codable {
    init?(events: [any DomainEvent]) throws
}

extension ReadModel {

    public func restore(event: some DomainEvent) throws {
        try when(happened: event)
    }

    public func restore(events: [any DomainEvent]) throws {
        for event in events {
            try restore(event: event)
        }
    }
}
