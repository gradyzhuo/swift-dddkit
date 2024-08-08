public class AbstractReadModel: ReadModel {

    public required init?(events: [any DomainEvent]) throws {
        try self.restore(events: events)
    }

    public func when(happened event: some DomainEvent) throws {
        fatalError("need to override this function.")
    }
}