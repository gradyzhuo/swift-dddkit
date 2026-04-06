# PostgresJSONReadModelStore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增 `PostgresJSONReadModelStore` — 基於 PostgreSQL + JSONB 的 `ReadModelStore` 具體實作，放在新的 `ReadModelPersistencePostgres` 模組。

**Architecture:** 單一 `read_model_snapshots` table 以 JSONB 存所有 ReadModel 類型，用 `(id, type)` 複合主鍵區分。`PostgresJSONReadModelStore<Model>` 直接依賴 `PostgresClient`，錯誤統一包裝成 `ReadModelStoreError` 並保留原始 cause。開發流程遵循 TDD：先寫 failing tests，再寫最少實作讓測試通過。

**Tech Stack:** Swift 6, PostgresNIO 1.21+, Swift Testing, PostgreSQL 17 (Docker)

**Prerequisites:** PostgreSQL 執行於 `localhost:5432`，帳號 `ddd`，密碼 `ddd`，資料庫 `ddd`

---

## File Map

| Action | Path | 職責 |
|---|---|---|
| Create | `Sources/ReadModelPersistence/ReadModelStoreError.swift` | 所有 store backend 共用的 error 型別 |
| Modify | `Package.swift` | 新增 postgres-nio 依賴、新 target、新 test target |
| Create | `Sources/ReadModelPersistencePostgres/ReadModelPersistencePostgres.swift` | Barrel file |
| Create | `Sources/ReadModelPersistencePostgres/PostgresJSONReadModelStore.swift` | Store 核心實作 |
| Create | `Tests/ReadModelPersistencePostgresIntegrationTests/PostgresJSONReadModelStoreTests.swift` | 整合測試（真實 PostgreSQL） |

---

### Task 1: 新增 `ReadModelStoreError`

**Files:**
- Create: `Sources/ReadModelPersistence/ReadModelStoreError.swift`

- [ ] **Step 1: 建立 error 型別**

```swift
// Sources/ReadModelPersistence/ReadModelStoreError.swift
public enum ReadModelStoreError: Error {
    case fetchFailed(id: String, cause: any Error)
    case saveFailed(id: String, cause: any Error)
    case deleteFailed(id: String, cause: any Error)
}
```

- [ ] **Step 2: 編譯確認**

```bash
swift build --target ReadModelPersistence
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/ReadModelPersistence/ReadModelStoreError.swift
git commit -m "[ADD] ReadModelStoreError — shared error type for ReadModelStore backends"
```

---

### Task 2: 更新 Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: 新增 postgres-nio 依賴**

在 `dependencies` 陣列加入：
```swift
.package(url: "https://github.com/vapor/postgres-nio.git", from: "1.21.0"),
```

- [ ] **Step 2: 新增 product**

在 `products` 陣列加入：
```swift
.library(name: "ReadModelPersistencePostgres", targets: ["ReadModelPersistencePostgres"]),
```

- [ ] **Step 3: 新增 target 與 test target**

在 `targets` 陣列（`MigrationUtility` 之前）加入：
```swift
.target(
    name: "ReadModelPersistencePostgres",
    dependencies: [
        "ReadModelPersistence",
        .product(name: "PostgresNIO", package: "postgres-nio"),
    ]),
.testTarget(
    name: "ReadModelPersistencePostgresIntegrationTests",
    dependencies: [
        "ReadModelPersistencePostgres",
        "ReadModelPersistence",
        .product(name: "PostgresNIO", package: "postgres-nio"),
    ]),
```

- [ ] **Step 4: Resolve 依賴**

```bash
swift package resolve
```

Expected: 成功下載 postgres-nio，無 error

- [ ] **Step 5: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "[ADD] ReadModelPersistencePostgres target + postgres-nio dependency"
```

---

### Task 3: 寫 failing 整合測試（TDD RED）

**Files:**
- Create: `Tests/ReadModelPersistencePostgresIntegrationTests/PostgresJSONReadModelStoreTests.swift`
- Create: `Sources/ReadModelPersistencePostgres/ReadModelPersistencePostgres.swift`

- [ ] **Step 1: 建立目錄**

```bash
mkdir -p Tests/ReadModelPersistencePostgresIntegrationTests
mkdir -p Sources/ReadModelPersistencePostgres
```

- [ ] **Step 2: 建立 barrel file 讓模組可編譯**

```swift
// Sources/ReadModelPersistencePostgres/ReadModelPersistencePostgres.swift
import ReadModelPersistence
import PostgresNIO
```

- [ ] **Step 3: 寫 failing 測試**

```swift
// Tests/ReadModelPersistencePostgresIntegrationTests/PostgresJSONReadModelStoreTests.swift
import Testing
import Foundation
import PostgresNIO
@testable import ReadModelPersistence
@testable import ReadModelPersistencePostgres

// MARK: - Test Fixtures

private struct TestModel: ReadModel, Sendable {
    typealias ID = String
    let id: String
    var value: String
}

// MARK: - Test Helper

private func withStore<T>(
    _ body: (PostgresJSONReadModelStore<TestModel>) async throws -> T
) async throws -> T {
    let client = PostgresClient(
        configuration: .init(
            host: "localhost",
            port: 5432,
            username: "ddd",
            password: "ddd",
            database: "ddd",
            tls: .disable
        )
    )
    let task = Task { await client.run() }
    defer { task.cancel() }

    try await client.query("""
        CREATE TABLE IF NOT EXISTS read_model_snapshots_test (
            id         TEXT        NOT NULL,
            type       TEXT        NOT NULL,
            data       JSONB       NOT NULL,
            revision   BIGINT      NOT NULL,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (id, type)
        )
        """)

    let store = PostgresJSONReadModelStore<TestModel>(
        client: client,
        tableName: "read_model_snapshots_test"
    )
    return try await body(store)
}

// MARK: - Tests

@Suite("PostgresJSONReadModelStore")
struct PostgresJSONReadModelStoreTests {

    @Test("fetch 不存在的 id 回傳 nil")
    func fetchNonExistentReturnsNil() async throws {
        try await withStore { store in
            let result = try await store.fetch(byId: "ghost-\(UUID())")
            #expect(result == nil)
        }
    }

    @Test("save 後 fetch 回傳快照與正確 revision")
    func saveAndFetch() async throws {
        let id = UUID().uuidString
        try await withStore { store in
            let model = TestModel(id: id, value: "hello")
            try await store.save(readModel: model, revision: 5)

            let stored = try await store.fetch(byId: id)
            #expect(stored?.readModel.id == id)
            #expect(stored?.readModel.value == "hello")
            #expect(stored?.revision == 5)

            try await store.delete(byId: id)
        }
    }

    @Test("save 兩次覆寫快照（upsert）")
    func saveUpserts() async throws {
        let id = UUID().uuidString
        try await withStore { store in
            try await store.save(readModel: TestModel(id: id, value: "first"), revision: 1)
            try await store.save(readModel: TestModel(id: id, value: "second"), revision: 3)

            let stored = try await store.fetch(byId: id)
            #expect(stored?.readModel.value == "second")
            #expect(stored?.revision == 3)

            try await store.delete(byId: id)
        }
    }

    @Test("delete 後 fetch 回傳 nil")
    func deleteRemovesSnapshot() async throws {
        let id = UUID().uuidString
        try await withStore { store in
            try await store.save(readModel: TestModel(id: id, value: "bye"), revision: 1)
            try await store.delete(byId: id)

            let result = try await store.fetch(byId: id)
            #expect(result == nil)
        }
    }
}
```

- [ ] **Step 4: 跑測試，確認因為找不到實作而 fail**

```bash
swift test --filter ReadModelPersistencePostgresIntegrationTests 2>&1 | grep -E "error:|FAIL|cannot find"
```

Expected: `error: cannot find type 'PostgresJSONReadModelStore' in scope`

這確認測試確實在測試「尚未存在的東西」，TDD RED 成立。

- [ ] **Step 5: Commit failing tests**

```bash
git add Sources/ReadModelPersistencePostgres/ Tests/ReadModelPersistencePostgresIntegrationTests/
git commit -m "[ADD] failing integration tests for PostgresJSONReadModelStore (TDD red)"
```

---

### Task 4: 實作 `PostgresJSONReadModelStore`（TDD GREEN）

**Files:**
- Create: `Sources/ReadModelPersistencePostgres/PostgresJSONReadModelStore.swift`

- [ ] **Step 1: 實作 store**

```swift
// Sources/ReadModelPersistencePostgres/PostgresJSONReadModelStore.swift
import ReadModelPersistence
import PostgresNIO
import Foundation

public struct PostgresJSONReadModelStore<Model: ReadModel & Sendable>: ReadModelStore
    where Model.ID == String
{
    private let client: PostgresClient
    private let typeName: String
    private let tableName: String

    public init(client: PostgresClient, tableName: String = "read_model_snapshots") {
        self.client = client
        self.typeName = String(describing: Model.self)
        self.tableName = tableName
    }

    public func fetch(byId id: String) async throws -> StoredReadModel<Model>? {
        do {
            let rows = try await client.query(
                "SELECT data, revision FROM \(unescaped: tableName) WHERE id = \(id) AND type = \(typeName)"
            )
            for try await (data, revision) in rows.decode((Data, Int64).self) {
                let model = try JSONDecoder().decode(Model.self, from: data)
                return StoredReadModel(readModel: model, revision: UInt64(bitPattern: revision))
            }
            return nil
        } catch {
            throw ReadModelStoreError.fetchFailed(id: id, cause: error)
        }
    }

    public func save(readModel: Model, revision: UInt64) async throws {
        do {
            let data = try JSONEncoder().encode(readModel)
            let rev = Int64(bitPattern: revision)
            try await client.query("""
                INSERT INTO \(unescaped: tableName) (id, type, data, revision, updated_at)
                VALUES (\(readModel.id), \(typeName), \(data), \(rev), now())
                ON CONFLICT (id, type) DO UPDATE
                    SET data = \(data), revision = \(rev), updated_at = now()
                """)
        } catch {
            throw ReadModelStoreError.saveFailed(id: readModel.id, cause: error)
        }
    }

    public func delete(byId id: String) async throws {
        do {
            try await client.query(
                "DELETE FROM \(unescaped: tableName) WHERE id = \(id) AND type = \(typeName)"
            )
        } catch {
            throw ReadModelStoreError.deleteFailed(id: id, cause: error)
        }
    }
}
```

- [ ] **Step 2: 跑整合測試，確認全部通過**

```bash
swift test --filter ReadModelPersistencePostgresIntegrationTests
```

Expected: 4 tests **PASS**

- [ ] **Step 3: 確認既有測試無 regression**

```bash
swift test --filter DDDKitUnitTests && swift test --filter ReadModelPersistenceTests
```

Expected: 全部 PASS

- [ ] **Step 4: Commit**

```bash
git add Sources/ReadModelPersistencePostgres/PostgresJSONReadModelStore.swift
git commit -m "[ADD] PostgresJSONReadModelStore — PostgreSQL + JSONB backed ReadModelStore"
```
