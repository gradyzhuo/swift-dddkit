//
//  KurrentProjection.swift
//  KurrentSupport
//
//  Phase 1 — Persistent Subscription Runner.
//  See spec: docs/superpowers/specs/2026-04-28-kurrent-projection-runner-design.md
//

public enum KurrentProjection {

    public enum NackAction: Sendable, Equatable {
        case retry
        case skip
        case park
        case stop
    }

    public struct RunnerStopped: Error, Sendable {
        public let reason: String

        public init(reason: String) {
            self.reason = reason
        }
    }

    public protocol RetryPolicy: Sendable {
        func decide(error: any Error, retryCount: Int) -> NackAction
    }

    public struct MaxRetriesPolicy: RetryPolicy {
        public let max: Int

        public init(max: Int = 5) {
            self.max = max
        }

        public func decide(error: any Error, retryCount: Int) -> NackAction {
            retryCount >= max ? .skip : .retry
        }
    }
}
