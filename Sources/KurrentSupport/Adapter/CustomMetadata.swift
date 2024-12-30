public struct CustomMetadata: Codable {
    public let className: String

    public init(className: String) {
        self.className = className
    }
}