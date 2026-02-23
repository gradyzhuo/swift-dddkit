public struct CustomMetadata: Codable, Sendable {
    public let className: String
    public let external: [String: String]?

    public init(className: String, external: [String: String]?) {
        self.className = className
        self.external = external
    }
}

extension CustomMetadata {
    public var operatorId: String?{
        get {
            guard let external else { return nil }
            return external["operatorId"] ?? external["userId"]
        }
    }
}

