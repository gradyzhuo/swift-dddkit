//
//  Presenter.swift
//
//
//  Created by Grady Zhuo on 2024/6/2.
//

import Foundation

public protocol Presenter<D, M> {
    associatedtype D: Output
    associatedtype M: ViewModel

    func buildViewModel(data: D)
}
