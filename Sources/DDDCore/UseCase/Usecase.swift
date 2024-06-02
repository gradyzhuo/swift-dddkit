import Foundation

public protocol Usecase<I, O> {
    associatedtype I: Input
    associatedtype O: Output

    func execute(input: I) async throws -> O
}
