public protocol ReadModel: Projectable {

    init?(other events: [any DomainEvent]) throws

}

extension ReadModel {
    public init?(events: [any DomainEvent]) throws {
        let sortedEvents = events.sorted {
            $0.occurred < $1.occurred
        }

        try self.init(other: sortedEvents)
    }

    public func apply(event: some DomainEvent) throws {
        try ensureInvariant()
        try when(happened: event)
    }

    public func apply(events: [any DomainEvent]) throws {
        for event in events {
            try apply(event: event)
        }
    }

    public func ensureInvariant() throws {}
}

extension ReadModel {
    public static var category: String {
        "\(Self.self)"
    }

    public static func getStreamName(id: ID) -> String {
        "\(category)-\(id)"
    }
}