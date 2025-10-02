//
//  MigrationError.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/6/6.
//
import DDDCore

public enum MigrationError: Error{
    case apply(error: any Error, event: any DomainEvent)
    case event(error: any Error, event: any DomainEvent)
}
