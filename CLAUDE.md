# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build the package
swift build

# Run all tests (requires KurrentDB running on localhost)
swift test

# Run a specific test target
swift test --filter EventSourcingTests

# Run a specific test function
swift test --filter EventSourcingTests/testProjector

# Build a specific target
swift build --target DDDKit

# Run the code generator CLI
swift run generate event --input Sources/MyTarget/event.yaml --config Sources/MyTarget/event-generator-config.yaml
swift run generate projection --input Sources/MyTarget/projection-model.yaml
```

`DDDCoreTests` requires a local KurrentDB instance (connects to `localhost`). `EventSourcingTests` uses an in-memory `TestCoordinator` and can run without KurrentDB.

## Architecture Overview

DDDKit is a Domain-Driven Design + Event Sourcing framework for Swift 6, targeting macOS 15+ and iOS 16+. It uses KurrentDB as the event store.

### Layer Structure

```
DDDKit (umbrella re-export)
├── DDDCore          — Core DDD protocols: Entity, DomainEvent, AggregateRoot, DomainEventBus
├── EventSourcing    — Abstract event sourcing patterns: EventStorageCoordinator, EventSourcingRepository, EventSourcingProjector, ReadModel, CQRSProjectorInput/Output
├── KurrentSupport   — KurrentDB adapter: KurrentStorageCoordinator, EventTypeMapper, DomainEventBus+KurrentDB
├── EventBus         — In-memory event bus (EventBus class)
├── MigrationUtility — Event schema migration framework
├── DomainEventGenerator — YAML→Swift code generation library
└── TestUtility      — Helpers for integration tests against KurrentDB
```

### Key Protocols

**`AggregateRoot`** (DDDCore) — Full event-sourced state machine. Requires:
- `DeletedEventType` associated type
- `when(happened:)` to mutate state from events
- `metadata: AggregateRootMetadata` — holds uncommitted events, soft-delete flag, and version
- `ensureInvariant()` — validation hook (default is no-op)
- Stream naming is defined directly on `AggregateRoot` via `categoryRule`/`category`/`getStreamName(id:)` extensions

**`DomainEvent`** (DDDCore) — Base event type. Must be `Codable + Identifiable<UUID>`. The `eventType` property defaults to the Swift type name.

**`EventStorageCoordinator`** (EventSourcing) — Storage abstraction with no generic constraint. Interface is purely `id: String`-based: `fetchEvents(byId:)`, `append(events:byId:version:external:)`, `purge(byId:)`. Non-KurrentDB backends implement this without any stream naming dependency.

**`EventSourcingRepository`** (EventSourcing) — Builds on coordinator: `find(byId:)`, `save(aggregateRoot:external:)`, `delete(byId:external:)`, `purge(byId:)`. Default implementations handle event replay and soft-delete logic.

**`KurrentStorageCoordinator<T: AggregateRoot>`** (KurrentSupport) — Concrete coordinator wrapping a KurrentDB client. Stream names use `{T.category}-{id}`. Events are stored with `CustomMetadata` containing the Swift type name and optional external key-value pairs.

**`EventTypeMapper`** (KurrentSupport) — Converts a raw `RecordedEvent` from KurrentDB into a typed `DomainEvent`. Implementations switch on `eventData.eventType`.

**`EventSourcingProjector`** (EventSourcing) — CQRS read side. Requires `StorageCoordinator: EventStorageCoordinator`, `Input: CQRSProjectorInput`, and `ReadModelType: ReadModel`. The `execute(input:)` default fetches events and folds them into a `ReadModel` via `apply(readModel:events:)`.

**`ReadModel`** (EventSourcing) — `Codable` type with an `id` for read-optimized projections.

**`DomainEventBus`** (DDDCore/EventBus) — Publish events and subscribe by event type. `EventBus` is the in-memory implementation.

### Code Generation (Plugins)

Two build-tool plugins auto-generate Swift source at build time:

- **`DomainEventGeneratorPlugin`** — Reads `event.yaml` + `event-generator-config.yaml` in the target, invokes `generate event`, outputs `generated-event.swift`.
- **`ProjectionModelGeneratorPlugin`** — Reads `projection-model.yaml`, invokes `generate projection`.

The `generate` executable (`Sources/generate/`) is the shared CLI. `DomainEventGenerator` contains the YAML parsing and Swift code emission logic.

### Event Sourcing Flow

1. Define events conforming to `DomainEvent` (or generate from `event.yaml`)
2. Implement `AggregateRoot` with `when(happened:)` handlers
3. Implement `EventTypeMapper` to deserialize KurrentDB `RecordedEvent` back to typed structs
4. Implement `EventSourcingRepository` backed by `KurrentStorageCoordinator`
5. `repository.save(aggregateRoot:)` — appends uncommitted events from `metadata` to KurrentDB
6. `repository.find(byId:)` — replays all events from KurrentDB through `when(happened:)` to reconstruct state

### Migration

`MigrationUtility` provides the `Migration` protocol for evolving event schemas. Accepts an old `EventTypeMapper` and an array of `MigrationHandler`s. Supports custom `createdHandler` for reconstructing aggregates from migrated event streams.
