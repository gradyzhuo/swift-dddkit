import Testing
import Foundation
import Yams
@testable import DomainEventGenerator

@Suite("KurrentDB Projection YAML Parsing")
struct KurrentDBProjectionParsingTests {

    @Test("plain string event decodes correctly")
    func plainStringEventDecodes() throws {
        let yaml = """
        MyModel:
          model: readModel
          category: Order
          idField: orderId
          events:
            - OrderCreated
        """
        let decoder = YAMLDecoder()
        let definitions = try decoder.decode([String: EventProjectionDefinition].self, from: yaml)
        let def = try #require(definitions["MyModel"])
        #expect(def.category == "Order")
        #expect(def.idField == "orderId")
        #expect(def.kurrentDBEvents.count == 1)
        guard case .plain(let name) = def.kurrentDBEvents[0] else {
            Issue.record("Expected .plain, got \(def.kurrentDBEvents[0])")
            return
        }
        #expect(name == "OrderCreated")
    }

    @Test("mapping event with custom body decodes correctly")
    func customHandlerEventDecodes() throws {
        let yaml = """
        MyModel:
          model: readModel
          category: Order
          events:
            - OrderReassigned: |
                linkTo("Target-" + event.body.newId, event);
        """
        let decoder = YAMLDecoder()
        let definitions = try decoder.decode([String: EventProjectionDefinition].self, from: yaml)
        let def = try #require(definitions["MyModel"])
        #expect(def.kurrentDBEvents.count == 1)
        guard case .custom(let name, let body) = def.kurrentDBEvents[0] else {
            Issue.record("Expected .custom, got \(def.kurrentDBEvents[0])")
            return
        }
        #expect(name == "OrderReassigned")
        #expect(body.contains("linkTo"))
    }

    @Test("mixed event list decodes correctly")
    func mixedEventListDecodes() throws {
        let yaml = """
        MyModel:
          model: readModel
          category: Order
          idField: orderId
          events:
            - OrderCreated
            - OrderReassigned: |
                linkTo("Target-" + event.body.newId, event);
        """
        let decoder = YAMLDecoder()
        let definitions = try decoder.decode([String: EventProjectionDefinition].self, from: yaml)
        let def = try #require(definitions["MyModel"])
        #expect(def.kurrentDBEvents.count == 2)
        guard case .plain(let firstName) = def.kurrentDBEvents[0] else {
            Issue.record("Expected first item to be .plain")
            return
        }
        #expect(firstName == "OrderCreated")
        guard case .custom(let secondName, _) = def.kurrentDBEvents[1] else {
            Issue.record("Expected second item to be .custom")
            return
        }
        #expect(secondName == "OrderReassigned")
    }

    @Test("events computed property returns names for ProjectorGenerator compatibility")
    func eventsPropertyReturnsNames() throws {
        let yaml = """
        MyModel:
          model: readModel
          category: Order
          idField: orderId
          events:
            - OrderCreated
            - OrderUpdated: |
                linkTo("T-" + event.body.x, event);
        """
        let decoder = YAMLDecoder()
        let definitions = try decoder.decode([String: EventProjectionDefinition].self, from: yaml)
        let def = try #require(definitions["MyModel"])
        #expect(def.events == ["OrderCreated", "OrderUpdated"])
    }

    @Test("definition without category has nil category")
    func noCategory() throws {
        let yaml = """
        MyModel:
          model: readModel
          events:
            - OrderCreated
        """
        let decoder = YAMLDecoder()
        let definitions = try decoder.decode([String: EventProjectionDefinition].self, from: yaml)
        let def = try #require(definitions["MyModel"])
        #expect(def.category == nil)
        #expect(def.idField == nil)
    }

    @Test("createdEvents mixed list decodes correctly")
    func createdEventsMixedList() throws {
        let yaml = """
        MyModel:
          model: readModel
          category: Order
          idField: orderId
          createdEvents:
            - OrderCreated
            - OrderImported: |
                linkTo("MyModel-" + event.body.importId, event);
        """
        let decoder = YAMLDecoder()
        let definitions = try decoder.decode([String: EventProjectionDefinition].self, from: yaml)
        let def = try #require(definitions["MyModel"])
        #expect(def.createdKurrentDBEvents.count == 2)
        guard case .plain = def.createdKurrentDBEvents[0] else {
            Issue.record("Expected first createdEvent to be .plain")
            return
        }
        guard case .custom = def.createdKurrentDBEvents[1] else {
            Issue.record("Expected second createdEvent to be .custom")
            return
        }
    }
}
