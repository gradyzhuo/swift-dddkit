import Foundation

public protocol PresenterOutput {
    associatedtype ReadModelType: ReadModel

    var readModel: ReadModelType { get }
    var message: String? { get }
}
