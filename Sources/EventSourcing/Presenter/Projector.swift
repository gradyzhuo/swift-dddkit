import DDDCore
import Logging

public protocol EventStorageProjector<StorageCoordinator> {
    associatedtype PresenterType: EventSourcingPresenter
    associatedtype StorageCoordinator: EventStorageCoordinator<PresenterType>
    
    var coordinator: StorageCoordinator { get }
    var presenter: PresenterType { get }
}

extension EventStorageProjector {

    private var logger: Logger {
        get{
            return .init(label: "<\(Self.self)>")
        }
    }
    
    public func find(byId id: PresenterType.ID) async throws -> PresenterType.ReadModelType? {
        guard let fetechedResult = try await coordinator.fetchEvents(byId: id) else {
            return nil
        }
        
        guard fetechedResult.events.count > 0 else {
            throw DDDError.eventsNotFoundInPresenter(operation: "buildReadModel", presenterType: "\(Self.self)")
        }
        
        try presenter.apply(events: fetechedResult.events)
        
        guard let output = try presenter.buildReadModel() else {
            return nil
        }
        
        if let message = output.message {
            logger.debug(.init(stringLiteral: message))
        }
        
        return output.readModel
    }
}



