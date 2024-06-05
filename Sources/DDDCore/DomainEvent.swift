import Foundation

public protocol DomainEvent: Codable{
    var aggregateId: String { get }
    var eventType: String { get }
    var occurred: Date { get }
}
