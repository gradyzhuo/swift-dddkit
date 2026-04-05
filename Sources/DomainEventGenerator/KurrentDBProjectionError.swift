package enum KurrentDBProjectionError: Error {
    case missingIdFieldForPlainEvent(modelName: String, eventName: String)
    case emptyCustomHandlerBody(eventName: String)
}
