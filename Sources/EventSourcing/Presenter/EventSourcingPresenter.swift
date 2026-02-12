import Foundation
import DDDCore

extension ReadModel {
    public static var category: String {
        "\(Self.self)"
    }
}

public protocol EventSourcingPresenter: Projectable {
    associatedtype ReadModelType: ReadModel
    
    func apply(events: [any DomainEvent]) throws
    func buildReadModel() throws -> PresenterOutput<ReadModelType>?
}

