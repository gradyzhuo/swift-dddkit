import Foundation

public protocol DomainEvent: Codable, Identifiable{
    var eventType: String { get }
}

