import Foundation
import DDDCore

extension ReadModel {
    public static var category: String {
        "\(Self.self)"
    }
}

public protocol EventSourcingPresenter {
    associatedtype ReadModelType: ReadModel
    
    init?(events: [any DomainEvent])
    func buildReadModel() throws -> PresenterOutput<ReadModelType>?
}
