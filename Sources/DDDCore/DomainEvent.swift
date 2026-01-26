import Foundation

public protocol DomainEvent: Codable, Identifiable, Sendable where ID == UUID {
    var eventType: String { get }
    var aggregateRootId: String { get }
    var occurred: Date { get }
}

extension DomainEvent {
    public var eventType: String {
        "\(Self.self)"
    }
}
