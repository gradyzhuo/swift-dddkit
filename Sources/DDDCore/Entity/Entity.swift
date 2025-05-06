//
//  Entity.swift
//
//
//  Created by Grady Zhuo on 2024/5/26.
//

import Foundation

public protocol Entity: AnyObject, Sendable {
    associatedtype ID: Hashable
    
    var id: ID { get }
}
