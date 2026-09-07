# Notification Definition Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** swift-ddd-kit gains the Notification Definition framework: a `NotificationDefinition` runtime product, two generators (`variables.yaml` → variables protocol; `notification.yaml` → per-event input struct + recipients + render), two build-tool plugins, and a CI-enforced in-repo demo proving the whole codegen chain compiles and renders.

**Architecture:** Everything mirrors the repo's existing generator stack: parsing + rendering live under `Sources/DomainEventGenerator/Generator/Notification/`, CLI subcommands in `Sources/generate/`, build-tool plugins shaped like `ModelGeneratorPlugin`, Swift Testing render/parsing tests in `Tests/DomainEventGeneratorTests`. The runtime types live in a new small `NotificationDefinition` target the generated code depends on; the variables generator deliberately does NOT depend on it.

**Tech Stack:** Yams, swift-argument-parser, PackagePlugin (BuildToolPlugin), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-07-notification-definition-design.md` — schemas, generated shapes, validation rules, and wire contract are FROZEN there; every exact string below derives from it.

## Global Constraints

- Branch `feature/notification-definition` (already holds the spec commit). Commits authored by the repo's configured identity (`Grady Zhuo <gradyzhuo@gmail.com>` — already set; do NOT override). Commit style: lowercase conventional (`feat:`/`fix:`/`test:`/`docs:`) matching `git log`. End with trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **Push the branch and open a PR at the end; NEVER create a tag** — the owner merges and tags himself.
- Swift Testing only; new test suites MUST be added to BOTH CI filter lines in `.github/workflows/swift-build-testing.yml` (:27 and :52) or CI never runs them.
- Placeholder grammar v1: `%[A-Za-z0-9_]+%`. Generated method names = variable names lowerCamelCased (first character lowercased; rest untouched). Deterministic output: variables/events render sorted by name; a variable's `inputs` keep YAML order.
- Type field schemas (closed): `mail` → `subject`, `content`; `inApp` → `title`, `content`. Exactly these fields; missing or extra = parse error.
- Frozen runtime shapes (spec §5):

```swift
public enum NotificationType: String, Codable, Sendable, CaseIterable { case mail, inApp }

public struct RenderedNotification: Equatable, Sendable {
    public let type: NotificationType
    public let fields: [String: String]
    public init(type: NotificationType, fields: [String: String])
}

public enum PlaceholderSubstitutionError: Error, Equatable {
    case missingValue(placeholder: String)
}

public enum PlaceholderSubstitution {
    /// Replaces every %token% occurrence via `values[token]`. A token with no
    /// value throws `.missingValue`. Text without tokens passes through.
    public static func substitute(_ template: String, values: [String: String]) throws -> String
}
```

- Generated-code contracts (spec §3–4) the golden tests must pin:
  - Variables protocol: `\(access) protocol \(protocolName): Sendable {` with one `func \(lowerCamel(name))(\(inputs...)) async throws -> String` per variable (sorted by name), plus a generated dispatch table type `\(access) enum \(protocolName)Placeholders` mapping `placeholder` string → an async closure invocation helper used by generated render functions:
    ```swift
    \(access) static func value(of placeholder: String, input: ..., variables: ...) -> ... // exact shape chosen in Task 2, must be consumed by Task 3's render
    ```
    (Task 2 fixes this helper's exact shape; Task 3 consumes whatever Task 2 committed — the two tasks share this seam, defined precisely in Task 2's step 1.)
  - Per-event: `\(access) struct \(event)NotificationInput: Decodable` (stored `let` properties = union of referenced variables' input names ∪ recipients fields, all `String`, sorted by name), and `\(access) enum \(event)Notification` with `static func recipients(input:) -> [String]` and `static func render(input:, variables: some \(protocolName)) async throws -> [RenderedNotification]` resolving each distinct variable once.

## File Structure

```
Sources/NotificationDefinition/NotificationDefinition.swift        — runtime types + substitution engine (T1)
Sources/DomainEventGenerator/Generator/Notification/
  VariablesDefinition.swift                                        — variables.yaml parsing (T2)
  VariablesProtocolGenerator.swift                                 — protocol + dispatch table rendering (T2)
  NotificationDefinitionFile.swift                                 — notification.yaml parsing + type schemas (T3)
  NotificationGenerator.swift                                      — input struct/recipients/render rendering (T3)
Sources/generate/Variables.swift                                   — `generate variables` subcommand (T4)
Sources/generate/Notification.swift                                — `generate notification` subcommand (T4)
Plugins/VariablesGeneratorPlugin/Plugin.swift                      (T5)
Plugins/NotificationGeneratorPlugin/Plugin.swift                   (T5)
Sources/NotificationDefinitionDemo/                                — demo target: yamls + config + plugins (T5)
Tests/NotificationDefinitionTests/PlaceholderSubstitutionTests.swift   (T1)
Tests/DomainEventGeneratorTests/VariablesParsingTests.swift            (T2)
Tests/DomainEventGeneratorTests/VariablesProtocolGeneratorTests.swift  (T2)
Tests/DomainEventGeneratorTests/NotificationParsingTests.swift         (T3)
Tests/DomainEventGeneratorTests/NotificationGeneratorTests.swift       (T3)
Tests/NotificationDefinitionDemoTests/DemoRenderTests.swift            (T5)
Package.swift / .github/workflows/swift-build-testing.yml / README.md
```

---

### Task 1: `NotificationDefinition` runtime target (TDD)

**Files:**
- Create: `Sources/NotificationDefinition/NotificationDefinition.swift`
- Modify: `Package.swift` (product + target + test target), `.github/workflows/swift-build-testing.yml` (add `NotificationDefinitionTests` to both filter lines)
- Test: `Tests/NotificationDefinitionTests/PlaceholderSubstitutionTests.swift`

**Interfaces:** Produces exactly the frozen runtime shapes from Global Constraints. Substitution semantics: single pass, longest-token irrelevant (tokens are delimiter-bounded); `%%` or `%not a token!%` (chars outside `[A-Za-z0-9_]`) are left verbatim; the same token may appear multiple times; values may themselves contain `%` (must NOT be re-substituted — replace on the ORIGINAL template's matches only).

- [ ] **Step 1: Write the failing tests**

```swift
import Testing

@testable import NotificationDefinition

@Suite("PlaceholderSubstitution")
struct PlaceholderSubstitutionTests {

    @Test func substitutesSingleToken() throws {
        let out = try PlaceholderSubstitution.substitute(
            "你已被加入案件「%QuotingCaseGroupName%」", values: ["QuotingCaseGroupName": "6666"])
        #expect(out == "你已被加入案件「6666」")
    }

    @Test func substitutesRepeatedAndAdjacentTokens() throws {
        let out = try PlaceholderSubstitution.substitute(
            "%A%%B%-%A%", values: ["A": "x", "B": "y"])
        #expect(out == "xy-x")
    }

    @Test func missingValueThrows() {
        #expect(throws: PlaceholderSubstitutionError.missingValue(placeholder: "Gone")) {
            _ = try PlaceholderSubstitution.substitute("hi %Gone%", values: [:])
        }
    }

    @Test func nonTokenPercentSignsPassThrough() throws {
        let out = try PlaceholderSubstitution.substitute(
            "50%% off %A% 100% sure", values: ["A": "v"])
        #expect(out == "50%% off v 100% sure")
    }

    @Test func valuesContainingPercentAreNotReSubstituted() throws {
        let out = try PlaceholderSubstitution.substitute(
            "%A% %B%", values: ["A": "%B%", "B": "z"])
        #expect(out == "%B% z")
    }

    @Test func textWithoutTokensPassesThrough() throws {
        #expect(try PlaceholderSubstitution.substitute("plain", values: [:]) == "plain")
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter PlaceholderSubstitutionTests` → build FAILURE (module missing).
- [ ] **Step 3: Implement** — the frozen shapes + a regex-driven substitute (`%[A-Za-z0-9_]+%`, single left-to-right pass over the original template building the output — do not use naive repeated `replacingOccurrences`, which re-substitutes values). Package.swift: `.library(name: "NotificationDefinition", targets: ["NotificationDefinition"])`, `.target(name: "NotificationDefinition")` (zero deps), test target; CI filter lines gain `NotificationDefinitionTests`.
- [ ] **Step 4: Verify** — filter PASS 6 tests; `swift build` complete.
- [ ] **Step 5: Commit** — `feat: NotificationDefinition runtime — notification types and placeholder substitution engine` (+ trailer), explicit paths.

---

### Task 2: variables.yaml parsing + protocol generator (TDD)

**Files:**
- Create: `Sources/DomainEventGenerator/Generator/Notification/VariablesDefinition.swift`, `VariablesProtocolGenerator.swift`
- Test: `Tests/DomainEventGeneratorTests/VariablesParsingTests.swift`, `VariablesProtocolGeneratorTests.swift`
- Modify: `.github/workflows/swift-build-testing.yml` ONLY if `DomainEventGeneratorTests` is absent from the filter (it is absent — add it to both lines; flag in the report that this also turns on the three pre-existing suites in CI).

**Interfaces:**
- `struct VariableDefinition: Equatable { let name: String; let placeholder: String; let inputs: [(name: String, type: String)] }`
- `enum VariablesParser { static func parse(yaml: String) throws -> [VariableDefinition] }` — throws typed `VariablesParseError` cases: `missingPlaceholder(variable:)`, `duplicatePlaceholder(placeholder:)`, `malformedInput(variable:)` (an inputs entry with ≠1 key), `unsupportedInputType(variable:input:type:)` (anything but `String`).
- `struct VariablesProtocolGenerator { init(protocolName: String, variables: [VariableDefinition]); func render(accessLevel: AccessLevel) -> [String] }` — emits (sorted by variable name):
  1. the protocol (Global Constraints shape);
  2. the dispatch-table seam consumed by Task 3's generated render. **Fix its exact shape now**: a generated extension
     ```swift
     \(access) extension \(protocolName) {
         func __value(of placeholder: String, inputs: [String: String]) async throws -> String
     }
     ```
     switching on the placeholder string, pulling each method's arguments from `inputs[<inputName>]!` (generator guarantees presence via the input-struct contract; use `guard let` + a generated `PlaceholderSubstitutionError.missingValue`-style fatal? No — throw `VariablesRuntimeError.missingInput(placeholder:input:)`, a small generated enum), default case throws `VariablesRuntimeError.unknownPlaceholder(_)`. This keeps Task 3's render generic: it builds `inputs: [String: String]` from the typed input struct and calls `__value(of:inputs:)` per distinct placeholder.

- [ ] **Step 1: Write failing parsing tests** — full code: happy path (2 variables, ordered inputs preserved), each error case above (5-7 tests, mirror `KurrentDBProjectionParsingTests` style).
- [ ] **Step 2: Write failing generator tests** — string-contains assertions in `EventFilterGeneratorTests` style: protocol line, both method signatures with exact parameter order, `Sendable`, access-level variants (`internal`/`public`), `__value(of:inputs:)` switch with both placeholders + default throw, `VariablesRuntimeError` enum emitted once.
- [ ] **Step 3: Verify failure** — `swift test --filter "VariablesParsingTests|VariablesProtocolGeneratorTests"` → build FAILURE.
- [ ] **Step 4: Implement both files.** Parsing: Yams `Node`-level walking (mirror how `KurrentDBProjectionParsingTests`' subject parses — read it first) so single-key-map lists and mapping order are handled explicitly.
- [ ] **Step 5: Verify** — new filters PASS; then `swift test --filter DomainEventGeneratorTests` — the three pre-existing suites must also still pass (they now enter CI).
- [ ] **Step 6: Commit** — `feat: variables.yaml parser and variables-protocol generator` (+ CI filter change, trailer).

---

### Task 3: notification.yaml parsing + notification generator (TDD)

**Files:**
- Create: `Sources/DomainEventGenerator/Generator/Notification/NotificationDefinitionFile.swift`, `NotificationGenerator.swift`
- Test: `Tests/DomainEventGeneratorTests/NotificationParsingTests.swift`, `NotificationGeneratorTests.swift`

**Interfaces:**
- Parsing types: `struct EventNotificationDefinition { let eventName: String; let recipients: [String]; let notifications: [NotificationEntry] }`, `struct NotificationEntry { let type: String; let fields: [(name: String, template: String)] }` with the closed type schema validated: `NotificationParseError` cases `unknownType(event:type:)`, `missingField(event:type:field:)`, `extraField(event:type:field:)`, `emptyRecipients(event:)`, `emptyNotifications(event:)`.
- `enum PlaceholderExtractor { static func placeholders(in template: String) -> [String] }` — regex `%([A-Za-z0-9_]+)%`, order of first appearance, deduplicated.
- `struct NotificationGenerator { init(protocolName: String, events: [EventNotificationDefinition], variables: [VariableDefinition]); func render(accessLevel: AccessLevel) throws -> [String] }` — cross-validation THROWS `NotificationGenerateError.undefinedPlaceholder(event:placeholder:)` when a template token has no variable whose `placeholder` matches; emits per event (sorted by name):
  - the input struct (Decodable, `let` String properties = union of matched variables' input names ∪ recipients, sorted);
  - the enum with `recipients(input:)` (returns the recipients fields' values in yaml order) and `render(input:variables:)` — builds `inputs: [String: String]` from the struct's properties, resolves each DISTINCT placeholder once via `variables.__value(of:inputs:)`, substitutes with `PlaceholderSubstitution.substitute`, returns `[RenderedNotification]` in yaml `notifications` order with `NotificationType(rawValue: "<type>")!` and the per-type field dictionary.
  - Generated file imports `NotificationDefinition`. Unused-variable warning: `render` also returns (as a generator-time stderr warning, not generated code) variables defined but never referenced — print via the CLI layer, so the generator exposes `var unreferencedVariables: [String]`.

- [ ] **Step 1: Failing parsing tests** — happy path (the spec §4 sample verbatim, both types), each error case (6-8 tests).
- [ ] **Step 2: Failing generator tests** — string-contains: input struct with exactly the union properties; recipients body; render resolves `QuotingCaseGroupName` once despite appearing in 3 templates (assert the generated code declares each placeholder's resolution `let` exactly once); undefinedPlaceholder throws; `import NotificationDefinition` present; access-level variants.
- [ ] **Step 3: Verify failure**, **Step 4: implement**, **Step 5: filters PASS + full `DomainEventGeneratorTests` green.**
- [ ] **Step 6: Commit** — `feat: notification.yaml parser and per-event notification generator`.

---

### Task 4: `generate variables` / `generate notification` CLI subcommands

**Files:**
- Create: `Sources/generate/Variables.swift`, `Sources/generate/Notification.swift`
- Modify: `Sources/generate/GenerateCommand.swift` (register both subcommands; add `struct NotificationGeneratorConfiguration: Codable { let accessModifier: AccessLevel; let variablesProtocolName: String }`)

**Interfaces (mirror `Sources/generate/ProjectionModel.swift`'s option style exactly — read it first):**
- `generate variables <variables.yaml> --generator-configuration <notification-generator-config.yaml> [--output <file>]` → writes the Task 2 render.
- `generate notification <notification.yaml> --variables <variables.yaml> --generator-configuration <config> [--output <file>]` → writes the Task 3 render; prints `warning: unreferenced variable <name>` lines to stderr.
- Both default output to stdout when `--output` omitted (matching existing commands' behavior — verify against `ProjectionModel.swift` and mirror whichever convention it actually implements).

- [ ] **Step 1: Implement both subcommands** (thin: read files, parse, render, write).
- [ ] **Step 2: Verify by hand** — run both against fixture yamls (write them under `/tmp`), pipe output to `swiftc -parse -` sanity? Simpler: `swift run generate variables /tmp/variables.yaml --generator-configuration /tmp/config.yaml | head`, assert exit 0 and expected first lines; error case exits non-zero with the typed message. (The compile-level proof comes from Task 5's demo target.)
- [ ] **Step 3: Commit** — `feat: generate variables/notification CLI subcommands`.

---

### Task 5: plugins + CI-enforced demo + README + PR

**Files:**
- Create: `Plugins/VariablesGeneratorPlugin/Plugin.swift`, `Plugins/NotificationGeneratorPlugin/Plugin.swift` (mirror `Plugins/ModelGeneratorPlugin/Plugin.swift`: locate the yaml(s) + `notification-generator-config.yaml` in target resources, invoke the `generate` tool with the Task 4 arguments, output under pluginWorkDirectory/generated)
- Create: `Sources/NotificationDefinitionDemo/` — `variables.yaml` + `notification.yaml` (the spec §3–4 samples verbatim), `notification-generator-config.yaml` (`accessModifier: public`, `variablesProtocolName: DemoNotificationVariables`), one hand-written file conforming the generated protocol with canned values
- Create: `Tests/NotificationDefinitionDemoTests/DemoRenderTests.swift` — renders `CollaboratorAdded` through the GENERATED code with the stub variables and asserts: two `RenderedNotification`s in yaml order; mail fields substituted exactly; recipients == [input.collaboratorId]; a missing-input decode fails.
- Modify: `Package.swift` — two `.plugin` products + plugin targets; demo target (resources: the three yamls; plugins: both; deps: `NotificationDefinition`); demo test target. CI filter lines gain `NotificationDefinitionDemoTests`.
- Modify: `README.md` — new "Notification Definition" section: the two yaml schemas (point to the spec), plugin wiring snippet, the consuming-target dependency note (`NotificationDefinition` product required by generated code).

**Interfaces:** the demo IS the end-to-end proof: if codegen output doesn't compile or misbehaves, `swift build`/CI fails.

- [ ] **Step 1: Plugins + demo target + config**; `swift build` until the generated demo compiles.
- [ ] **Step 2: Demo tests (TDD-ish: write them before wiring the stub impl)** — `swift test --filter NotificationDefinitionDemoTests` → PASS.
- [ ] **Step 3: Full offline verification** — `swift test --filter '(DDDKitUnitTests|EventSourcingTests|ContextForwarderTests|ContextReceiverTests|ContextReceiverWebSocketTests|NotificationDefinitionTests|DomainEventGeneratorTests|NotificationDefinitionDemoTests)'` — everything green (this is the new CI line).
- [ ] **Step 4: README + commit** — `feat: notification/variables generator plugins with CI-enforced demo target` then `docs: README section for the notification definition framework`.
- [ ] **Step 5: Push + PR (NO TAG)** — `git push -u origin feature/notification-definition`; `gh pr create` against main titled `feat: Notification Definition framework — yaml-driven notification codegen`, body summarizing the spec (link the spec file), noting the CI-filter addition also enables the pre-existing `DomainEventGeneratorTests` in CI, and that the owner tags the release himself.

---

## Out of Scope (later plans)

- OC sidecar adoption (plan 2, OpportunityContext repo) and NotificationContext adoption (plan 3) — see spec §7–9.
- Template-variable system rewrite, mail attachments, new notification types, localization (spec §11).
