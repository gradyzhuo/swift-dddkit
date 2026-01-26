import Foundation

@available(*, deprecated, message: "Using EvnetSourcingPresenter insteads.")
public protocol Presenter<I, O> {
    associatedtype I: PresenterInput
    associatedtype O: PresenterOutput

    func buildReadModel(input: I) async throws -> O
}
