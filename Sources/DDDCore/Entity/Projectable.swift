public protocol Projectable {

    associatedtype ID: Hashable
    
    static var category: String { get }
    
    var id: ID { get }
}

extension Projectable {
    public static func getStreamName(id: ID) -> String {
        "\(category)-\(id)"
    }
}
