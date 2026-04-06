//
//  DDDError.swift
//
//
//  Created by Grady Zhuo on 2024/6/11.
//

import Foundation

public struct DDDError: Error {
    public let code: Code
    public let message: String
    public let userInfos: [String: Sendable]

    public init(code: Code, message: String, userInfos: [String:Sendable]) {
        self.code = code
        self.message = message
        self.userInfos = userInfos
    }
}

extension DDDError {
    public enum Code: Int, Sendable {
        case undefined = 900
        case usecaseExecutionFailure = 101
        case aggregateNotFound = 201
        case projectorConstructionFailed = 301
        case aggregateOperationNotAllowed = 202
        case eventsNotFound = 401
    }
}

extension DDDError.Code {
    @available(*, deprecated, renamed: "projectorConstructionFailed")
    public static var presenterConstructionFailed: Self { .projectorConstructionFailed }
}

// MARK: - Define errors with enum-like.

extension DDDError {
    public static func executeUsecaseFailed(usecase: any Usecase, input: any UseCaseInput, userInfos: [String: Sendable]? = nil) -> Self {
        let errorCode = DDDError.Code.usecaseExecutionFailure
        let message = "[\(errorCode)] The error happened with executing usecase \(usecase) by input: \(input). "
        let useInfos = userInfos ?? [:]
        return .init(code: errorCode, message: message, userInfos: useInfos)
    }

    public static func aggregateNotFound(usecase: any Usecase, aggregateRootType: any AggregateRoot.Type, aggregateRootId: String) -> Self {
        aggregateNotFound(usecase: "\(usecase)", aggregateRootType: aggregateRootType, aggregateRootId: aggregateRootId)
    }
    
    public static func aggregateNotFound(usecase: String, aggregateRootType: any AggregateRoot.Type, aggregateRootId: String) -> Self {
        let errorCode = DDDError.Code.aggregateNotFound
        let message = "[\(errorCode)] The aggregateRoot (\(aggregateRootId)@\(aggregateRootType.self))  not found with executing usecase \(usecase)."
        return .init(code: errorCode, message: message, userInfos: [:])
    }
    
    public static func operationNotAllow(operation: String, reason: String, userInfos: [String: Sendable]? = nil) -> Self {
        let errorCode = DDDError.Code.aggregateOperationNotAllowed
        let message = "[\(errorCode)] `\(operation)` not allowed, because \(reason)."
        var userInfos = userInfos ?? [:]
        userInfos["operation"] = operation
        userInfos["reason"] = reason
        return .init(code: errorCode, message: message, userInfos: userInfos)
    }
    
    public static func eventsNotFoundInProjector(operation: String, projectorType: String, userInfos: [String: Sendable]? = nil) -> Self {
        let errorCode = DDDError.Code.eventsNotFound
        let reason = "events not found to build readModel in projector \(projectorType)"
        let message = "[\(errorCode)] `\(operation)` not allowed, because \(reason)."
        var userInfos = userInfos ?? [:]
        userInfos["operation"] = operation
        userInfos["reason"] = reason
        return .init(code: errorCode, message: message, userInfos: userInfos)
    }

    @available(*, deprecated, renamed: "eventsNotFoundInProjector(operation:projectorType:userInfos:)")
    public static func eventsNotFoundInPresenter(operation: String, presenterType: String, userInfos: [String: Sendable]? = nil) -> Self {
        eventsNotFoundInProjector(operation: operation, projectorType: presenterType, userInfos: userInfos)
    }

    public static func projectorOperationFailed(projectorType: String, id: String, reason: String, userInfos: [String: Sendable]? = nil) -> Self {
        let errorCode = DDDError.Code.projectorConstructionFailed
        let message = "[\(errorCode)] It's failed in \(projectorType):\(id), because \(reason)."
        var userInfos = userInfos ?? [:]
        userInfos["reason"] = reason
        return .init(code: errorCode, message: message, userInfos: userInfos)
    }

    @available(*, deprecated, renamed: "projectorOperationFailed(projectorType:id:reason:userInfos:)")
    public static func presenterOperationFailed(presenterType: String, id: String, reason: String, userInfos: [String: Sendable]? = nil) -> Self {
        projectorOperationFailed(projectorType: presenterType, id: id, reason: reason, userInfos: userInfos)
    }
}
