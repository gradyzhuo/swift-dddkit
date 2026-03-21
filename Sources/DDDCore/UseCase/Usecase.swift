import Foundation

public protocol Usecase<Input, Output> {
    associatedtype Input: UseCaseInput
    associatedtype Output: UseCaseOutput

    func execute(input: Input) async throws -> Output
}
