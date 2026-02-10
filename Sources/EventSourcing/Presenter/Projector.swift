import DDDCore
import Logging

public protocol EventStorageProjector<StorageCoordinator> {
    associatedtype PresenterType: EventSourcingPresenter
    associatedtype StorageCoordinator: EventStorageCoordinator<PresenterType>
    associatedtype Options
    
    var coordinator: StorageCoordinator { get }
}

extension EventStorageProjector {

    private var logger: Logger {
        get{
            return .init(label: "<\(Self.self)>")
        }
    }
    
    public func find(byId id: PresenterType.ID, options: Options) async throws -> PresenterType.ReadModelType? {
        guard let fetechedResult = try await coordinator.fetchEvents(byId: id) else {
            return nil
        }
        
        guard fetechedResult.events.count > 0 else {
            throw DDDError.eventsNotFoundInPresenter(operation: "buildReadModel", presenterType: "\(Self.self)")
        }
        
        guard let presenter = PresenterType(events: fetechedResult.events) else {
            throw DDDError.presenterOperationFailed(presenterType: "\(PresenterType.self)", id: "\(id)", reason: "construction failed.")
        }
        
        
        
        guard let output = try presenter.buildReadModel() else {
            return nil
        }
        
        if let message = output.message {
            logger.debug(.init(stringLiteral: message))
        }
        
        return output.readModel
    }
}



