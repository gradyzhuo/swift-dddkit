//
//  CqrsPresenter.swift
//
//
//  Created by Grady Zhuo on 2024/6/2.
//

import DDDCore
import Foundation

public protocol CqrsPresenter: Presenter where D: CqrsOutput, M: CqrsCommandViewModel {}
