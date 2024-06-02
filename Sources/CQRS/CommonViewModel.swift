//
//  CommonViewModel.swift
//
//
//  Created by Grady Zhuo on 2024/6/2.
//

import DDDCore
import Foundation

public protocol CommonViewModel: ViewModel {
    var id: String { get }
    var message: String { get }
    var exitCode: ExitCode { get }
}
