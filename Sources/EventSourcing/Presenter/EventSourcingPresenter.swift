import Foundation
import DDDCore

public protocol EventSourcingPresenter: Projectable {
    associatedtype ReadModelType: ReadModel
    
    func apply(events: [any DomainEvent]) throws
    func buildReadModel() throws -> PresenterOutput<ReadModelType>?
}

extension EventSourcingPresenter {
    public static var category: String{
        return ReadModelType.category
    }
}

