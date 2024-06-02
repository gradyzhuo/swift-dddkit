//
//  DomainEventStoragePeer.swift
//
//
//  Created by 卓俊諺 on 2024/5/27.
//

import Foundation

public protocol DomainEventStoragePeer: AnyObject {
    var events: [any DomainEvent] { set get }
}
