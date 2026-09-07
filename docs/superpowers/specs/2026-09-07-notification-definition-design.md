# Notification Definition & Template Variables — Design

Status: approved in brainstorming 2026-09-07 (NotificationContext session). Supersedes, in form,
the "PL events carry all typed template parameters" contract recorded in NotificationContext's
decisions doc (2026-08-10): the *principle* — a published event carries its complete notification
intent, the consumer never queries back upstream — is unchanged; its **form upgrades from typed
parameters to fully rendered content**.

## 1. Motivation

Today a notification's copy lives in three hand-written places: the upstream forwarder's
translate rule (parameter extraction), NotificationContext's `NotificationTemplate` enum +
`DefaultTemplateRenderer` (copy), and its PL translator (event→template mapping). Adding or
changing one notification touches all three, in two repos, and the parameter list that the PL
event must carry is enforced only by convention.

This design moves notification ownership entirely into the **upstream context**: one
`notification.yaml` declares which events notify, per-channel copy, and the variables the copy
needs; one `variables.yaml` declares the variables as a typed, implementable contract. swift-ddd-kit
generates the Swift for both. The upstream renders **before publishing**; the PL event carries the
rendered result per channel. NotificationContext needs no yaml, no templates, no copy — it is a
pure result pipeline (dedup, throttle, preference, store, dispatch, inbox).

The variables half is deliberately independent: it is the seed of a general template-variable
framework. The owner intends to eventually rewrite OpportunityContext's existing template-variable
system (the `%Placeholder%` contract used by the letter pipeline / QuotingContentManager) on top
of it.

## 2. Ownership & data flow

```
XXXContext (upstream — owns events, copy, variables)
  variables.yaml     ──VariablesGeneratorPlugin──▶ variables protocol (one template-method per variable)
  notification.yaml  ──NotificationGeneratorPlugin──▶ per-event: input struct + recipients() + render()
  forwarder: decode input → recipients() → render(input, variablesImpl) → PL payload = rendered fields
        │
        ▼  PublishedLanguageEvent { recipientIds, payload: {"mail.subject": …, "inApp.title": …} }
NotificationContext (pure result pipeline — no yaml, no templates)
  ingest: payload → per-channel contents → NotificationCreated (audit-immutable) → dispatch/inbox
```

Rendering snapshot semantics: values are resolved **at forwarding time** (upstream's live read
models — renames are reflected up to that moment), stored immutably on `NotificationCreated`.
The only cross-context contract left is the payload key convention plus `recipientIds`.

## 3. `variables.yaml`

```yaml
QuotingCaseGroupName:
  placeholder: QuotingCaseGroupName        # the %…% token; may differ from the variable name
  inputs:
    - quotingCaseGroupingId: String        # ordered list of single-key maps = method parameter order

CollaboratorDescription:
  placeholder: CollaboratorDescription
  inputs:
    - quotingCaseGroupingId: String
    - collaboratorId: String

QuotingCaseGroupCollaboratorRole:
  placeholder: QuotingCaseGroupCollaboratorRole
  inputs:
    - quotingCaseGroupingId: String
    - collaboratorId: String
```

Rules:
- Top-level key = variable name (drives the generated method name, lowerCamelCased).
- `placeholder` is required and must be unique across the file (it is the `%token%` matched in
  templates; explicit because variable name and placeholder text may legitimately diverge).
- `inputs` is an **ordered** list of `name: SwiftType` single-key maps; order = generated
  parameter order. Input names are, by convention, upstream event property names (see §4).
- Supported input types initially: `String` (others are a schema extension, not a free-for-all).

Generated (per yaml, protocol name from a small generator config, mirroring
`event-generator-config.yaml` conventions):

```swift
public protocol OpportunityNotificationVariables: Sendable {
    func collaboratorDescription(quotingCaseGroupingId: String, collaboratorId: String) async throws -> String
    func quotingCaseGroupCollaboratorRole(quotingCaseGroupingId: String, collaboratorId: String) async throws -> String
    func quotingCaseGroupName(quotingCaseGroupingId: String) async throws -> String
}
```

plus an internal placeholder↔method dispatch table for the renderer. Methods are `async throws`:
implementations read read-models and may fail; a throw at forwarding time is transient (nack →
redelivery), consistent with the forwarder's existing semantics.

## 4. `notification.yaml`

```yaml
CollaboratorAdded:
  recipients:
    - collaboratorId                       # event field name(s) → PL recipientIds (fan-out list)
  notifications:
    - type: mail
      subject: 你已被加入案件「%QuotingCaseGroupName%」
      content: |
        你以「%QuotingCaseGroupCollaboratorRole%」角色被加入案件「%QuotingCaseGroupName%」，%CollaboratorDescription%。
    - type: inApp
      title: 你已被加入案件「%QuotingCaseGroupName%」
      content: 你以「%QuotingCaseGroupCollaboratorRole%」角色被加入案件「%QuotingCaseGroupName%」。
```

Rules:
- Top-level key = domain event type name (the raw `eventType` string on the wire).
- `recipients`: list of event field names; each referenced field becomes a `String` on the
  generated input struct; PL `recipientIds` = their values (fan-out).
- `notifications`: a **list** — one entry per channel; `type` is a closed set with a typed field
  schema per type: `mail` → `subject` + `content` (future: attachments), `inApp` → `title` +
  `content`. Unknown types or missing/extra fields are generation errors.
- **No per-event variables list.** The generator extracts `%Placeholder%` tokens from every text
  field and resolves them against `variables.yaml`. A token with no variable definition is a
  generation error; a defined variable never referenced by any notification is a warning.
- Input binding is by **naming convention**: every input name of every referenced variable, and
  every `recipients` field name, must be a property of the event. Where `event.yaml` is
  co-located in the same target the generator cross-validates at build time; where it is not
  (e.g. a standalone sidecar package), the contract is enforced at runtime by `Decodable` failure
  → the forwarder's existing permanent-park semantics.
  **v1 status:** only the runtime fallback is implemented — the co-located `event.yaml`
  build-time cross-check described above is not built yet; see §11.

Generated (per event):

```swift
public struct CollaboratorAddedNotificationInput: Decodable {   // union of inputs ∪ recipients
    public let quotingCaseGroupingId: String
    public let collaboratorId: String
}

public enum CollaboratorAddedNotification {
    public static func recipients(input: CollaboratorAddedNotificationInput) -> [String]
    public static func render(
        input: CollaboratorAddedNotificationInput,
        variables: some OpportunityNotificationVariables
    ) async throws -> [RenderedNotification]
}
```

`render` resolves each distinct variable **once** (deduplicated across all of the event's
templates), substitutes `%placeholder%` occurrences, and returns one `RenderedNotification` per
`notifications` entry.

## 5. Runtime product: `NotificationDefinition`

A small new library product/target in swift-ddd-kit:

```swift
public enum NotificationType: String, Codable, Sendable { case mail, inApp }

public struct RenderedNotification: Equatable, Sendable {
    public let type: NotificationType
    public let fields: [String: String]      // mail: subject/content; inApp: title/content
}

public enum PlaceholderSubstitution { /* %token% substitution engine used by generated render() */ }
```

The variables generator does **not** depend on this product — only the notification generator's
output does — so the future template-variable rewrite can adopt the variables framework without
dragging notification types along.

## 6. Wire contract (Published Language)

Rendered fields flatten into the existing `PublishedLanguageEvent.payload: [String: String]` with
namespaced keys — **no envelope change**:

```
"mail.subject"  / "mail.content"
"inApp.title"   / "inApp.content"
```

`recipientIds`, `eventId` (uppercase UUID, consumer dedup key), `partitionKey` (aggregate id) are
unchanged. Consumer guard: `inApp.title` and `inApp.content` are required (they are the inbox and
audit baseline); their absence is a permanent contract violation (→ DLQ). Other channels are
optional — absence simply means that channel isn't sent.

**Versioning note:** switching `OpportunityCollaboratorAdded.v1` payload from typed parameters to
rendered fields is a breaking change by the PL rules; it is applied as an in-place redefinition of
`.v1` ONLY because every producer and consumer of this contract lives on unmerged PR branches with
no deployment. After these merge, any such change requires a `.v2`.

## 7. Producer-side adoption (OpportunityContext sidecar, PR #331 branch)

- `forwarder/` gains `variables.yaml` + `notification.yaml` (the authoritative copies; they move
  into the OC main package target when OC migrates to swift-ddd-kit 1.x) and both plugins.
- Hand-written code shrinks to the **variables implementation** (protocol conformance reading
  KurrentDB — the generalization of today's caseName reader) plus a thin generated-driven rule:
  decode input struct → `recipients()` → `render()` → payload.
- Retired: the two hand-written translate rules, `CaseNameReading`/`KurrentCaseNameReader`, and
  the editor/viewer literal filter (whether an event notifies is now solely "is it in
  notification.yaml"; role-based suppression, if still wanted, is a variables/copy concern).

## 8. Consumer-side adoption (NotificationContext, PR #2 branch)

- `IngestNotificationCommand` carries rendered contents instead of a template; the translator
  becomes generic (`{type}.{field}` extraction + the inApp guard). Retired: `NotificationTemplate`,
  `CollaboratorRole`, `TemplateRendering`, `DefaultTemplateRenderer`, and the per-event mapping in
  `OpportunityPLTranslator`.
- `NotificationCreated` evolves additively: existing `title`/`body` are **defined as the inApp
  variant** (inbox display + audit baseline; zero migration for old events); new optional
  `mailSubject`/`mailContent`. Future channels add optional fields.
- Email dispatch reads the mail variant, falling back to `title`/`body` for pre-migration events.

## 9. Migration order

1. **swift-ddd-kit** (this repo): runtime product + both generators + plugins + tests. Branch
   `feature/notification-definition` → PR. **No tag from automation** — the owner merges and tags
   (expected `1.4.0`) himself.
2. **OC sidecar** (PR #331 branch): pin swift-ddd-kit to the feature branch revision temporarily
   (switch to the version pin once the owner tags), adopt yamls, implement variables, retire old
   rules.
3. **NotificationContext** (PR #2 branch): same temporary pin; ingest/dispatch consume rendered
   contents; retire the template layer.
4. Local stack redeploy + mailpit e2e re-verification; NotificationContext decisions doc gains the
   superseding entry; the pipeline artifact page is updated.

## 10. Testing

- **Kit:** golden-output generator tests (yaml → expected Swift) and generation-error tests
  (unknown placeholder, unknown type, malformed inputs list, duplicate placeholder); substitution
  engine unit tests (multi-occurrence, adjacent tokens, missing-value throw).
- **Sidecar:** offline rule tests with a stub variables implementation (assert payload keys,
  recipients fan-out, single-resolution per variable, throw → transient).
- **NC:** offline translator/ingest tests on the `{type}.{field}` contract incl. the inApp guard
  and old-event fallback; existing docker e2e re-run with assertions on the mail variant.

## 11. Out of scope (recorded, deliberate)

- Rewriting OC's existing template-variable system (letter pipeline / QCM placeholders) onto the
  variables framework — the declared long-term goal this framework is shaped for, but a separate
  effort.
- `mail` attachments (the type schema leaves room; no design yet).
- New notification types beyond `mail`/`inApp` (push etc.) — additive type-schema extensions.
- Localization/multi-language copy.
- Digest/quiet-hours interactions (F 區 unchanged).
- The §4 co-located `event.yaml` build-time cross-check (naming-convention binding validated
  against the event's actual fields at generation time) — v1 relies solely on the runtime
  `Decodable`-failure fallback; a build-time check is a recorded follow-up.
