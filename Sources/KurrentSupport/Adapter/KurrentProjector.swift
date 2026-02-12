//
//  KurrentProjector2.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2026/2/6.
//
import KurrentDB
import EventSourcing

public protocol KurrentProjector: EventStorageProjector where StorageCoordinator == KurrentStorageCoordinator<PresenterType>{
    
}
