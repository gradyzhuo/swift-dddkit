public protocol Projectable: Entity {
    func when(happened event: some DomainEvent) throws
    func ensureInvariant() throws
}