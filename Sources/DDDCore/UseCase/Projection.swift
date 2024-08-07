
public protocol Projection: AnyObject {
    associatedtype ProjectableType: Projectable

    func find(byStreamName streamName: String) async throws -> ProjectableType?
}