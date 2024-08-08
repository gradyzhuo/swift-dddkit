public protocol DTO: Projectable {}

extension DTO {

    public func restore(event: some DomainEvent) throws {
        try ensureInvariant()
        try when(happened: event)
        try ensureInvariant()
    }

    public func ensureInvariant() throws {}
}