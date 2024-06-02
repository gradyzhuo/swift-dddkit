//
//  CqrsOutput.swift
//
//
//  Created by Grady Zhuo on 2024/6/2.
//

import DDDCore
import Foundation

public protocol CqrsOutput: Output {
    var id: String { get }
    var message: String { get }
    var exitCode: ExitCode { get }
}
