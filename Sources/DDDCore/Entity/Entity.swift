//
//  Entity.swift
//
//
//  Created by Grady Zhuo on 2024/5/26.
//

import Foundation

public protocol Entity<Id>: AnyObject, Codable {
    associatedtype Id: Identifiable

    var id: Id { get }
}
