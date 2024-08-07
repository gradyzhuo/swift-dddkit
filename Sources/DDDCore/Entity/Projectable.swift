public protocol Projectable {
    
    func when(happened event: some DomainEvent) throws
    func ensureInvariant() throws
}