public struct CustomMetadata: Codable {
    public let className: String
    public let external: [String: String]?

    public init(className: String, external: [String: String]?) {
        self.className = className
        self.external = external
    }
}

