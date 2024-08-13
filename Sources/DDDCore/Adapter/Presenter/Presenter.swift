import Foundation

public protocol Presenter<I, O> {
    associatedtype I: PresenterInput
    associatedtype O: PresenterOutput

    func buildReadModel(input: I) async throws -> O
}