//
//  KurrentProjector2.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2026/2/6.
//
import KurrentDB
import EventSourcing

struct KurrentProjector<PresenterType: EventSourcingPresenter> {
    typealias PresenterType = PresenterType
    typealias StorageCoordinator = EventStorageCoordinator
    
    let coordinator: KurrentStorageCoordinator
    
    init(client: KurrentDBClient, category: String, eventMapper: any EventTypeMapper, coordinator: KurrentStorageCoordinator, id: String){
        self.coordinator = coordinator
        self.coordinator.fetchEvents(byId: id)
    }
}
