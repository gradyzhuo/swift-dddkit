//
//  KurrentProjector2.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2026/2/6.
//
import KurrentDB
import EventSourcing

public struct KurrentProjector<PresenterType: EventSourcingPresenter>: EventStorageProjector{
    public typealias StorageCoordinator = KurrentStorageCoordinator<PresenterType>
    
    public let coordinator: StorageCoordinator
    public let presenter: PresenterType
    
    public init(coordinator: StorageCoordinator, presenter: PresenterType) {
        self.coordinator = coordinator
        self.presenter = presenter
    }
    
    public init(client: KurrentDBClient, eventMapper: any EventTypeMapper, presenter: PresenterType){
        self.init(coordinator: .init(client: client, eventMapper: eventMapper), presenter: presenter)
    }

}
