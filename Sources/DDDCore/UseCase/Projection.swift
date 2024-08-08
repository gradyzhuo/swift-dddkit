
public protocol Projection: AnyObject {
    associatedtype ProjectableType: ReadModel

    func find(byStreamName streamName: String) async throws -> ProjectableType?
}