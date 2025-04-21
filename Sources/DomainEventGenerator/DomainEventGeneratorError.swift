//
//  DomainEventGeneratorError.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/4/21.
//
import Foundation

public enum DomainEventGeneratorError: Error {
    case invalidYamlFile(url: URL, reason: String)
}
