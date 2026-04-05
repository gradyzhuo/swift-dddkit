import Testing
import Foundation
@testable import DomainEventGenerator

@Suite("KurrentDBProjectionGenerator")
struct KurrentDBProjectionGeneratorTests {

    @Test("definition without category returns nil")
    func noCategoryReturnsNil() throws {
        let definition = EventProjectionDefinition(
            model: .readModel,
            kurrentDBEvents: [.plain("OrderCreated")]
        )
        let generator = KurrentDBProjectionGenerator(name: "MyModel", definition: definition)
        let result = try generator.render()
        #expect(result == nil)
    }

    @Test("standard routing generates correct fromStreams and linkTo")
    func standardRoutingGeneratesJS() throws {
        let definition = EventProjectionDefinition(
            model: .readModel,
            category: "Quotation",
            idField: "quotingCaseId",
            kurrentDBEvents: [.plain("QuotationCreated"), .plain("QuotationUpdated")]
        )
        let generator = KurrentDBProjectionGenerator(name: "OC_GetQuotation", definition: definition)
        let js = try #require(try generator.render())
        #expect(js.contains(#"fromStreams(["$ce-Quotation"])"#))
        #expect(js.contains("QuotationCreated: function(state, event)"))
        #expect(js.contains("QuotationUpdated: function(state, event)"))
        #expect(js.contains(#"linkTo("OC_GetQuotation-" + event.body["quotingCaseId"], event)"#))
    }

    @Test("custom handler body is embedded verbatim inside wrapper")
    func customHandlerEmbeddedVerbatim() throws {
        let body = #"linkTo("OtherTarget-" + event.body.otherId, event);"#
        let definition = EventProjectionDefinition(
            model: .readModel,
            category: "Quotation",
            kurrentDBEvents: [.custom(name: "QuotationReassigned", body: body)]
        )
        let generator = KurrentDBProjectionGenerator(name: "OC_GetQuotation", definition: definition)
        let js = try #require(try generator.render())
        #expect(js.contains("QuotationReassigned: function(state, event)"))
        #expect(js.contains(body))
    }

    @Test("mixed list generates both standard and custom handlers")
    func mixedListGeneratesBoth() throws {
        let definition = EventProjectionDefinition(
            model: .readModel,
            category: "Order",
            idField: "orderId",
            kurrentDBEvents: [
                .plain("OrderCreated"),
                .custom(name: "OrderReassigned",
                        body: #"linkTo("T-" + event.body.newId, event);"#)
            ]
        )
        let generator = KurrentDBProjectionGenerator(name: "MyModel", definition: definition)
        let js = try #require(try generator.render())
        #expect(js.contains(#"linkTo("MyModel-" + event.body["orderId"], event)"#))
        #expect(js.contains(#"linkTo("T-" + event.body.newId, event);"#))
    }

    @Test("plain event without idField throws missingIdFieldForPlainEvent")
    func plainEventWithoutIdFieldThrows() throws {
        let definition = EventProjectionDefinition(
            model: .readModel,
            category: "Order",
            kurrentDBEvents: [.plain("OrderCreated")]
        )
        let generator = KurrentDBProjectionGenerator(name: "MyModel", definition: definition)
        #expect(throws: KurrentDBProjectionError.self) {
            _ = try generator.render()
        }
    }

    @Test("createdKurrentDBEvents appear before kurrentDBEvents in generated JS")
    func createdEventsAppearFirst() throws {
        let definition = EventProjectionDefinition(
            model: .readModel,
            category: "Order",
            idField: "orderId",
            kurrentDBEvents: [.plain("OrderUpdated")],
            createdKurrentDBEvents: [.plain("OrderCreated")]
        )
        let generator = KurrentDBProjectionGenerator(name: "MyModel", definition: definition)
        let js = try #require(try generator.render())
        let createdRange = try #require(js.range(of: "OrderCreated"))
        let updatedRange = try #require(js.range(of: "OrderUpdated"))
        #expect(createdRange.lowerBound < updatedRange.lowerBound)
    }

    @Test("output includes isJson guard for every handler")
    func outputIncludesIsJsonGuard() throws {
        let definition = EventProjectionDefinition(
            model: .readModel,
            category: "Order",
            idField: "orderId",
            kurrentDBEvents: [.plain("OrderCreated")]
        )
        let generator = KurrentDBProjectionGenerator(name: "MyModel", definition: definition)
        let js = try #require(try generator.render())
        #expect(js.contains("event.isJson"))
    }

    @Test("output contains $init handler")
    func outputContainsInitHandler() throws {
        let definition = EventProjectionDefinition(
            model: .readModel,
            category: "Order",
            idField: "orderId",
            kurrentDBEvents: [.plain("OrderCreated")]
        )
        let generator = KurrentDBProjectionGenerator(name: "MyModel", definition: definition)
        let js = try #require(try generator.render())
        #expect(js.contains("$init: function()"))
    }
}
