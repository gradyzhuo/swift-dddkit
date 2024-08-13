import Foundation

public protocol PresenterOutput: Sendable, Codable {
    var readModel: (any ReadModel)? { get }
    var message: String? { get }
}