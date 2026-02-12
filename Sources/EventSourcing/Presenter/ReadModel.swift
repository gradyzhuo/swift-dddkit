//
//  ReadModel.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2026/2/9.
//

public protocol ReadModel: Codable {
    associatedtype ID: Hashable
    
    static var category: String { get }
    
    var id: ID { get }
}


extension ReadModel {
    public static var category: String {
        "\(Self.self)"
    }
}
