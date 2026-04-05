# KurrentDB Projection Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `projection-model.yaml` with `category`, `idField`, and mixed event-list syntax, and generate KurrentDB `.js` projection files via a new `generate kurrentdb-projection` CLI subcommand and SPM Command Plugin.

**Architecture:** `KurrentDBProjectionEventItem` enum decodes mixed YAML event lists (plain string OR `{name: |body}`). `KurrentDBProjectionGenerator` renders the JS boilerplate around the per-event handlers. A new `GenerateKurrentDBProjectionsPlugin` Command Plugin forwards arguments to the existing `generate` executable's new `kurrentdb-projection` subcommand.

**Tech Stack:** Swift 6, Yams (YAML decoding), ArgumentParser (CLI), PackagePlugin (Command Plugin), Swift Testing framework.

---

## File Map

| Action | File |
|--------|------|
| Create | `Sources/DomainEventGenerator/KurrentDBProjectionEventItem.swift` |
| Create | `Sources/DomainEventGenerator/KurrentDBProjectionError.swift` |
| Modify | `Sources/DomainEventGenerator/Generator/Model/EventProjectionDefinition.swift` |
| Create | `Sources/DomainEventGenerator/Generator/Model/KurrentDBProjectionGenerator.swift` |
| Create | `Sources/generate/KurrentDBProjection.swift` |
| Modify | `Sources/generate/GenerateCommand.swift` |
| Create | `Plugins/GenerateKurrentDBProjectionsPlugin/Plugin.swift` |
| Modify | `Package.swift` |
| Create | `Tests/DomainEventGeneratorTests/KurrentDBProjectionParsingTests.swift` |
| Create | `Tests/DomainEventGeneratorTests/KurrentDBProjectionGeneratorTests.swift` |

---

## Task 1: Test infrastructure + YAML parsing (TDD RED)

**Files:**
- Modify: `Package.swift`
- Create: `Tests/DomainEventGeneratorTests/KurrentDBProjectionParsingTests.swift`
- Create: `Sources/DomainEventGenerator/KurrentDBProjectionEventItem.swift` (stub only)
- Create: `Sources/DomainEventGenerator/KurrentDBProjectionError.swift`

- [ ] **Step 1: Add `DomainEventGeneratorTests` target to Package.swift**

In `Package.swift`, add a test target after `ReadModelPersistenceTests`:

```swift
.testTarget(
    name: "DomainEventGeneratorTests",
    dependencies: [
        "DomainEventGenerator",
        .product(name: "Yams", package: "yams"),
    ]),
```

- [ ] **Step 2: Create `KurrentDBProjectionError.swift`**

Create `Sources/DomainEventGenerator/KurrentDBProjectionError.swift`:

```swift
package enum KurrentDBProjectionError: Error {
    case missingIdFieldForPlainEvent(modelName: String, eventName: String)
    case emptyCustomHandlerBody(eventName: String)
}
```

- [ ] **Step 3: Create `KurrentDBProjectionEventItem.swift` stub**

Create `Sources/DomainEventGenerator/KurrentDBProjectionEventItem.swift`:

```swift
import Foundation

package enum KurrentDBProjectionEventItem {
    case plain(String)
    case custom(name: String, body: String)

    package var name: String {
        switch self {
        case .plain(let n): n
        case .custom(let n, _): n
        }
    }
}
```

Do NOT add `Codable` yet — that comes in Task 2.

- [ ] **Step 4: Write failing parsing tests**

Create `Tests/DomainEventGeneratorTests/KurrentDBProjectionParsingTests.swift`:

```swift
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

    @Test("definition without category has nil category and empty kurrentDBEvents")
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
```

- [ ] **Step 5: Verify tests fail to compile**

```bash
cd /Volumes/Development/swift-ddd-kit && swift test --filter DomainEventGeneratorTests 2>&1 | grep -E "error:|cannot find"
```

Expected: `error: value of type 'EventProjectionDefinition' has no member 'kurrentDBEvents'` and similar. This confirms TDD RED.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Development/swift-ddd-kit
git add Package.swift \
  Sources/DomainEventGenerator/KurrentDBProjectionEventItem.swift \
  Sources/DomainEventGenerator/KurrentDBProjectionError.swift \
  Tests/DomainEventGeneratorTests/KurrentDBProjectionParsingTests.swift
git commit -m "[ADD] TDD RED — KurrentDB projection YAML parsing tests"
```

---

## Task 2: Implement YAML decoding (TDD GREEN)

**Files:**
- Modify: `Sources/DomainEventGenerator/KurrentDBProjectionEventItem.swift`
- Modify: `Sources/DomainEventGenerator/Generator/Model/EventProjectionDefinition.swift`

- [ ] **Step 1: Add Codable conformance to `KurrentDBProjectionEventItem`**

Replace the contents of `Sources/DomainEventGenerator/KurrentDBProjectionEventItem.swift`:

```swift
import Foundation

package enum KurrentDBProjectionEventItem: Codable, Sendable {
    case plain(String)
    case custom(name: String, body: String)

    package var name: String {
        switch self {
        case .plain(let n): n
        case .custom(let n, _): n
        }
    }

    package init(from decoder: any Decoder) throws {
        // Plain string: - EventA
        if let container = try? decoder.singleValueContainer(),
           let name = try? container.decode(String.self) {
            self = .plain(name)
            return
        }
        // Mapping: - EventB: | ...body...
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Expected a string or a single-key mapping"))
        }
        let body = try container.decode(String.self, forKey: key)
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KurrentDBProjectionError.emptyCustomHandlerBody(eventName: key.stringValue)
        }
        self = .custom(name: key.stringValue, body: trimmed)
    }

    package func encode(to encoder: any Encoder) throws {
        switch self {
        case .plain(let name):
            var container = encoder.singleValueContainer()
            try container.encode(name)
        case .custom(let name, let body):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            try container.encode(body, forKey: DynamicCodingKey(name))
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { self.stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
```

- [ ] **Step 2: Update `EventProjectionDefinition`**

Replace `Sources/DomainEventGenerator/Generator/Model/EventProjectionDefinition.swift` entirely:

```swift
//
//  EventProjectionDefinition.swift
//  DDDKit
//
//  Created by Grady Zhuo on 2025/2/12.
//

import Foundation

package struct EventProjectionDefinition: Codable {
    package var idType: PropertyDefinition.PropertyType
    package let model: ModelKind
    package let deletedEvent: String?

    // KurrentDB projection fields
    package let category: String?
    package let idField: String?
    package let kurrentDBEvents: [KurrentDBProjectionEventItem]
    package let createdKurrentDBEvents: [KurrentDBProjectionEventItem]

    // Computed for backward compat with ProjectorGenerator
    package var events: [String] { kurrentDBEvents.map(\.name) }
    package var createdEvents: [String] { createdKurrentDBEvents.map(\.name) }

    package init(
        idType: PropertyDefinition.PropertyType = .string,
        model: ModelKind,
        category: String? = nil,
        idField: String? = nil,
        kurrentDBEvents: [KurrentDBProjectionEventItem] = [],
        createdKurrentDBEvents: [KurrentDBProjectionEventItem] = [],
        deletedEvent: String? = nil
    ) {
        self.idType = idType
        self.model = model
        self.category = category
        self.idField = idField
        self.kurrentDBEvents = kurrentDBEvents
        self.createdKurrentDBEvents = createdKurrentDBEvents
        self.deletedEvent = deletedEvent
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idType = try container.decodeIfPresent(PropertyDefinition.PropertyType.self, forKey: .idType) ?? .string
        let model = try container.decode(EventProjectionDefinition.ModelKind.self, forKey: .model)
        let deletedEvent = try container.decodeIfPresent(String.self, forKey: .deletedEvent)
        let category = try container.decodeIfPresent(String.self, forKey: .category)
        let idField = try container.decodeIfPresent(String.self, forKey: .idField)

        // createdEvents: accepts String, [String], or [{name: body}] mixed list
        let createdKurrentDBEvents: [KurrentDBProjectionEventItem]
        if let single = try container.decodeIfPresent(String.self, forKey: .createdEvents) {
            createdKurrentDBEvents = [.plain(single)]
        } else {
            createdKurrentDBEvents = try container.decodeIfPresent(
                [KurrentDBProjectionEventItem].self, forKey: .createdEvents) ?? []
        }

        let kurrentDBEvents = try container.decodeIfPresent(
            [KurrentDBProjectionEventItem].self, forKey: .events) ?? []

        self.init(
            idType: idType,
            model: model,
            category: category,
            idField: idField,
            kurrentDBEvents: kurrentDBEvents,
            createdKurrentDBEvents: createdKurrentDBEvents,
            deletedEvent: deletedEvent
        )
    }

    private enum CodingKeys: String, CodingKey {
        case idType, model, deletedEvent, events, createdEvents, category, idField
    }
}

extension EventProjectionDefinition {
    package enum ModelKind: String, Codable {
        case aggregateRoot
        case readModel

        var `protocol`: String {
            switch self {
            case .aggregateRoot: "AggregateRoot"
            case .readModel: "ReadModel"
            }
        }
    }
}
```

- [ ] **Step 3: Build to catch any compilation errors**

```bash
cd /Volumes/Development/swift-ddd-kit && swift build --target DomainEventGenerator 2>&1
```

Expected: `Build complete!`

If `ProjectorGenerator.swift` fails because `definition.events` or `definition.createdEvents` changed type, it should still work since they are now computed `[String]` properties — same type as before.

- [ ] **Step 4: Run parsing tests**

```bash
cd /Volumes/Development/swift-ddd-kit && swift test --filter DomainEventGeneratorTests 2>&1
```

Expected: all 6 parsing tests PASS.

- [ ] **Step 5: Run existing tests to confirm no regression**

```bash
cd /Volumes/Development/swift-ddd-kit && swift test --filter DDDKitUnitTests 2>&1 | tail -3
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Development/swift-ddd-kit
git add Sources/DomainEventGenerator/KurrentDBProjectionEventItem.swift \
  Sources/DomainEventGenerator/Generator/Model/EventProjectionDefinition.swift
git commit -m "[ADD] KurrentDBProjectionEventItem + updated EventProjectionDefinition with category/idField/mixed events"
```

---

## Task 3: KurrentDB JS generator (TDD)

**Files:**
- Create: `Tests/DomainEventGeneratorTests/KurrentDBProjectionGeneratorTests.swift`
- Create: `Sources/DomainEventGenerator/Generator/Model/KurrentDBProjectionGenerator.swift`

- [ ] **Step 1: Write failing generator tests**

Create `Tests/DomainEventGeneratorTests/KurrentDBProjectionGeneratorTests.swift`:

```swift
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

    @Test("plain event without idField throws missingIdField error")
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

    @Test("createdEvents appear before events in generated JS")
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
        let createdRange = js.range(of: "OrderCreated")
        let updatedRange = js.range(of: "OrderUpdated")
        let created = try #require(createdRange)
        let updated = try #require(updatedRange)
        #expect(created.lowerBound < updated.lowerBound)
    }

    @Test("output includes isJson guard")
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
}
```

- [ ] **Step 2: Run to confirm TDD RED**

```bash
cd /Volumes/Development/swift-ddd-kit && swift test --filter KurrentDBProjectionGeneratorTests 2>&1 | grep -E "error:|cannot find"
```

Expected: `error: cannot find type 'KurrentDBProjectionGenerator' in scope`

- [ ] **Step 3: Implement `KurrentDBProjectionGenerator`**

Create `Sources/DomainEventGenerator/Generator/Model/KurrentDBProjectionGenerator.swift`:

```swift
//
//  KurrentDBProjectionGenerator.swift
//  DDDKit
//

import Foundation
import Yams

package struct KurrentDBProjectionGenerator {
    package let name: String
    package let definition: EventProjectionDefinition

    package init(name: String, definition: EventProjectionDefinition) {
        self.name = name
        self.definition = definition
    }

    /// Returns nil when `definition.category` is absent (definition is not a KurrentDB projection).
    /// Throws `KurrentDBProjectionError` for invalid configurations.
    package func render() throws -> String? {
        guard let category = definition.category else { return nil }

        var lines: [String] = []
        lines.append(#"fromStreams(["$ce-\#(category)"])"#)
        lines.append(".when({")
        lines.append("    $init: function(){ return {} },")

        let allItems = definition.createdKurrentDBEvents + definition.kurrentDBEvents
        for item in allItems {
            try lines.append(contentsOf: renderHandler(item: item))
        }

        lines.append("});")
        return lines.joined(separator: "\n")
    }

    private func renderHandler(item: KurrentDBProjectionEventItem) throws -> [String] {
        var lines: [String] = []
        lines.append("    \(item.name): function(state, event) {")
        lines.append("        if (event.isJson) {")

        switch item {
        case .plain(let eventName):
            guard let idField = definition.idField else {
                throw KurrentDBProjectionError.missingIdFieldForPlainEvent(
                    modelName: name, eventName: eventName)
            }
            lines.append(#"            linkTo("\#(name)-" + event.body["\#(idField)"], event);"#)

        case .custom(_, let body):
            let bodyLines = body.components(separatedBy: "\n")
            for bodyLine in bodyLines where !bodyLine.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("            \(bodyLine)")
            }
        }

        lines.append("        }")
        lines.append("    },")
        return lines
    }
}

package struct KurrentDBProjectionFileGenerator {
    package let definitions: [String: EventProjectionDefinition]

    package init(projectionModelYamlFileURL: URL) throws {
        let yamlData = try Data(contentsOf: projectionModelYamlFileURL)
        guard !yamlData.isEmpty else {
            throw DomainEventGeneratorError.invalidYamlFile(
                url: projectionModelYamlFileURL, reason: "The yaml file is empty.")
        }
        let yamlDecoder = YAMLDecoder()
        self.definitions = try yamlDecoder.decode([String: EventProjectionDefinition].self, from: yamlData)
    }

    package func writeFiles(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, definition) in definitions {
            let generator = KurrentDBProjectionGenerator(name: name, definition: definition)
            guard let js = try generator.render() else { continue }
            let outputURL = directory.appendingPathComponent("\(name)Projection.js")
            try js.write(to: outputURL, atomically: true, encoding: .utf8)
        }
    }
}
```

- [ ] **Step 4: Run generator tests**

```bash
cd /Volumes/Development/swift-ddd-kit && swift test --filter DomainEventGeneratorTests 2>&1
```

Expected: all tests PASS (both parsing and generator suites).

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Development/swift-ddd-kit
git add Sources/DomainEventGenerator/Generator/Model/KurrentDBProjectionGenerator.swift \
  Tests/DomainEventGeneratorTests/KurrentDBProjectionGeneratorTests.swift
git commit -m "[ADD] KurrentDBProjectionGenerator — JS generation with TDD green"
```

---

## Task 4: CLI subcommand

**Files:**
- Create: `Sources/generate/KurrentDBProjection.swift`
- Modify: `Sources/generate/GenerateCommand.swift`

- [ ] **Step 1: Create the subcommand**

Create `Sources/generate/KurrentDBProjection.swift`:

```swift
//
//  KurrentDBProjection.swift
//  DDDKit
//

import Foundation
import ArgumentParser
import DomainEventGenerator

struct GenerateKurrentDBProjectionCommand: ParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "kurrentdb-projection",
        abstract: "Generate KurrentDB .js projection files from projection-model.yaml.")

    @Argument(help: "The path of the projection-model.yaml file.",
              completion: .file(extensions: ["yaml", "yml"]))
    var input: String

    @Option(name: .shortAndLong,
            help: "The output directory for generated .js files. Default: projections/")
    var output: String = "projections"

    func run() throws {
        let inputURL = URL(filePath: input)
        let outputURL = URL(filePath: output)
        let fileGenerator = try KurrentDBProjectionFileGenerator(projectionModelYamlFileURL: inputURL)
        try fileGenerator.writeFiles(to: outputURL)
    }
}
```

- [ ] **Step 2: Register the subcommand in `GenerateCommand.swift`**

In `Sources/generate/GenerateCommand.swift`, update `GenerateCommand.configuration`:

```swift
@main
struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate swift files.",
        subcommands: [
            GenerateEventCommand.self,
            GenerateEventMapperCommand.self,
            GenerateModelCommand.self,
            GenerateKurrentDBProjectionCommand.self,   // ← add this
        ])
}
```

- [ ] **Step 3: Build the generate executable**

```bash
cd /Volumes/Development/swift-ddd-kit && swift build --target generate 2>&1
```

Expected: `Build complete!`

- [ ] **Step 4: Smoke test the CLI with a temp YAML**

```bash
cat > /tmp/test-projection-model.yaml << 'EOF'
OC_GetQuotationIdByQuotingCaseId:
  model: readModel
  category: Quotation
  idField: quotingCaseId
  createdEvents:
    - QuotationCreated
  events:
    - QuotationUpdated
    - QuotationReassigned: |
        linkTo("OC_GetQuotationIdByQuotingCaseId-" + event.body.newCaseId, event);
EOF

mkdir -p /tmp/test-projections
cd /Volumes/Development/swift-ddd-kit && \
  swift run generate kurrentdb-projection /tmp/test-projection-model.yaml --output /tmp/test-projections
cat /tmp/test-projections/OC_GetQuotationIdByQuotingCaseIdProjection.js
```

Expected output:
```js
fromStreams(["$ce-Quotation"])
.when({
    $init: function(){ return {} },
    QuotationCreated: function(state, event) {
        if (event.isJson) {
            linkTo("OC_GetQuotationIdByQuotingCaseId-" + event.body["quotingCaseId"], event);
        }
    },
    QuotationUpdated: function(state, event) {
        if (event.isJson) {
            linkTo("OC_GetQuotationIdByQuotingCaseId-" + event.body["quotingCaseId"], event);
        }
    },
    QuotationReassigned: function(state, event) {
        if (event.isJson) {
            linkTo("OC_GetQuotationIdByQuotingCaseId-" + event.body.newCaseId, event);
        }
    },
});
```

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Development/swift-ddd-kit
git add Sources/generate/KurrentDBProjection.swift Sources/generate/GenerateCommand.swift
git commit -m "[ADD] generate kurrentdb-projection subcommand"
```

---

## Task 5: Command Plugin + Package.swift

**Files:**
- Create: `Plugins/GenerateKurrentDBProjectionsPlugin/Plugin.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Create the Command Plugin**

Create `Plugins/GenerateKurrentDBProjectionsPlugin/Plugin.swift`:

```swift
//
//  Plugin.swift
//  GenerateKurrentDBProjectionsPlugin
//

import Foundation
import PackagePlugin

enum GenerateKurrentDBProjectionsPluginError: Error {
    case generationFailure(executable: String, arguments: [String], stdErr: String?)
}

@main
struct GenerateKurrentDBProjectionsPlugin {

    func performCommand(
        arguments: [String],
        tool: (String) throws -> PluginContext.Tool
    ) throws {
        let executableURL = try tool("generate").url

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            let stdErr = try? errorPipe.fileHandleForReading.readToEnd()
                .flatMap { String(decoding: $0, as: UTF8.self) }
            throw GenerateKurrentDBProjectionsPluginError.generationFailure(
                executable: executableURL.path,
                arguments: arguments,
                stdErr: stdErr)
        }
        process.waitUntilExit()

        guard process.terminationReason == .exit, process.terminationStatus == 0 else {
            let stdErr = try? errorPipe.fileHandleForReading.readToEnd()
                .flatMap { String(decoding: $0, as: UTF8.self) }
            throw GenerateKurrentDBProjectionsPluginError.generationFailure(
                executable: executableURL.path,
                arguments: arguments,
                stdErr: stdErr)
        }
    }
}

extension GenerateKurrentDBProjectionsPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        try self.performCommand(arguments: arguments, tool: context.tool)
    }
}
```

- [ ] **Step 2: Add plugin and test target to `Package.swift`**

In `Package.swift`, add the plugin product to `products`:

```swift
.plugin(name: "GenerateKurrentDBProjectionsPlugin", targets: [
    "GenerateKurrentDBProjectionsPlugin"
]),
```

Add the plugin target to `targets` (after the `PresenterCommandPlugin` entry):

```swift
.plugin(
    name: "GenerateKurrentDBProjectionsPlugin",
    capability: .command(
        intent: .custom(
            verb: "generate-kurrentdb-projections",
            description: "Generate KurrentDB .js projection files from projection-model.yaml"),
        permissions: [
            PluginPermission.writeToPackageDirectory(
                reason: "Writes generated KurrentDB projection .js files to the projections/ directory.")
        ]),
    dependencies: [
        "generate",
    ]),
```

- [ ] **Step 3: Build to verify Package.swift is valid**

```bash
cd /Volumes/Development/swift-ddd-kit && swift package dump-package > /dev/null && echo "Package.swift valid"
```

Expected: `Package.swift valid`

- [ ] **Step 4: Verify plugin is discoverable**

```bash
cd /Volumes/Development/swift-ddd-kit && swift package plugin --list 2>&1 | grep kurrentdb
```

Expected: `generate-kurrentdb-projections` appears in the list.

- [ ] **Step 5: End-to-end test via plugin**

```bash
cd /Volumes/Development/swift-ddd-kit && \
  swift package generate-kurrentdb-projections \
    kurrentdb-projection /tmp/test-projection-model.yaml \
    --output /tmp/test-projections-plugin
cat /tmp/test-projections-plugin/OC_GetQuotationIdByQuotingCaseIdProjection.js
```

Expected: same JS output as Task 4 Step 4.

- [ ] **Step 6: Run full test suite**

```bash
cd /Volumes/Development/swift-ddd-kit && swift test 2>&1 | tail -10
```

Expected: all tests pass (DomainEventGeneratorTests + DDDKitUnitTests + ReadModelPersistenceTests).

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Development/swift-ddd-kit
git add Plugins/GenerateKurrentDBProjectionsPlugin/Plugin.swift Package.swift
git commit -m "[ADD] GenerateKurrentDBProjectionsPlugin — SPM Command Plugin for KurrentDB projection generation"
```

---

## Self-Review

**Spec coverage:**
- ✅ `category` + `idField` YAML fields — Task 2
- ✅ Plain string event → standard `linkTo` — Tasks 2, 3
- ✅ `EventName: |` custom body → embedded in wrapper — Tasks 2, 3
- ✅ Mixed list in `events` and `createdEvents` — Tasks 1, 2, 3
- ✅ No `category` → skip, no output — Task 3
- ✅ Plain event + no `idField` → error — Task 3
- ✅ Empty `|` body → error — Task 2 (decoded in `KurrentDBProjectionEventItem.init`)
- ✅ Output directory created if absent — Task 3 (`createDirectory(withIntermediateDirectories: true)`)
- ✅ Existing `.js` overwritten — Task 3 (`write(atomically: true)` overwrites)
- ✅ `generate kurrentdb-projection` subcommand — Task 4
- ✅ `GenerateKurrentDBProjectionsPlugin` Command Plugin — Task 5
- ✅ All new logic tested before implementation (TDD) — Tasks 1, 3

**Placeholder scan:** None found.

**Type consistency:**
- `KurrentDBProjectionEventItem` — defined Task 1, used Tasks 2, 3, 4 consistently
- `KurrentDBProjectionGenerator(name:definition:)` — defined Task 3, matches usage in Task 4
- `KurrentDBProjectionFileGenerator` — defined Task 3, used in Task 4 CLI
- `definition.kurrentDBEvents` / `definition.createdKurrentDBEvents` — defined Task 2, used Task 3
