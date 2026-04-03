// Sources/ReadModelPersistence/ReadModelStoreError.swift
public enum ReadModelStoreError: Error {
    case fetchFailed(id: String, cause: any Error & Sendable)
    case saveFailed(id: String, cause: any Error & Sendable)
    case deleteFailed(id: String, cause: any Error & Sendable)
}
