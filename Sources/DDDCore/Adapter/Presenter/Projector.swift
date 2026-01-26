@available(*, deprecated, message: "Using EvnetSourcingProjector insteads.")
public protocol Projector: AnyObject {
    associatedtype ProjectableType: ReadModel

    func find(byId id: ProjectableType.ID) async throws -> ProjectableType?
    
}
