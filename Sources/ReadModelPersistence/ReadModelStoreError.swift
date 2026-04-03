// Sources/ReadModelPersistence/ReadModelStoreError.swift
public enum ReadModelStoreError: Error {
    case fetchFailed(id: String, cause: any Error)
    case saveFailed(id: String, cause: any Error)
    case deleteFailed(id: String, cause: any Error)
}
