# Architecture Document: Data Debugger Multi-User Hardening

Date: 2026-08-02
Complexity: HIGH
Author: Angus, AL Architect
Status: Approved

> Skills applied: None (general architecture patterns only)

## 1. Executive Summary
This architecture hardens the Data Debugger extension for true multi-user recording (User A starts recording, User B's operations are captured), while prioritizing AppSource readiness and operational safety. The focus is on correctness, privacy classification, permissions, release hygiene, and resilient cross-session behavior.

## 2. Business Objectives
- Preserve core product behavior: true multi-user recording remains supported and reliable.
- Achieve AppSource-oriented quality gates for privacy, security, and metadata.
- Eliminate high-risk behaviors that can corrupt business data or mislead diagnostics.
- Improve maintainability with clear separation of demo/test/release artifacts.

## 3. Scope
### In Scope
- Recording/session architecture for cross-session user targeting.
- Event subscriber capture path correctness and data quality.
- Data model hardening for privacy classifications.
- Permission model decomposition and least-privilege alignment.
- Release packaging hygiene and metadata completion.
- Test strategy expansion for multi-user scenarios and regressions.

### Out of Scope
- Redesign into single-user-only mode.
- New customer-facing feature development unrelated to hardening.
- Non-AL platform changes outside extension boundaries.

## 4. Current State
- Multi-user behavior is implemented via database-backed singleton state in DD Recording State and global trigger subscribers.
- Capture supports rollback-safe buffering and direct DB mode.
- Several quality gaps exist in release hygiene, privacy classification, and transaction-summary correctness.
- App metadata and permission hardening are incomplete for AppSource-focused publishing.

## 5. Target Architecture
### 5.1 Recording Control Plane
- Keep DB-backed run state for cross-session visibility.
- Preserve recorded-user gate as the authoritative capture predicate.
- Keep setup cache, but reduce stale-state windows and hidden write side effects.

### 5.2 Capture Data Plane
- Continue automatic Global Trigger subscribers with runtime filtering.
- Ensure modify-capture path explicitly handles no-read-permission branches.
- Ensure transaction grouping outputs deterministic and row-correct summaries.

### 5.3 Packaging and Release Plane
- Exclude non-production artifacts from release app payload.
- Keep diagnostics and demo utilities in dedicated non-production scope.

## 6. Data Architecture
### 6.1 Classification Strategy
- Apply field-level DataClassification overrides on capture tables:
- Old/New payload blobs and call stack: customer-content sensitive classification.
- User identifiers and names: end-user identifier classifications.
- Keep pure operational counters and run IDs under system metadata where appropriate.

### 6.2 Singleton Initialization
- Move singleton seed writes from hot-path getter calls into install/upgrade lifecycle.
- Keep getter logic read-focused and side-effect free during runtime capture.

### 6.3 Transaction Summary Model
- Replace cursor-fragile nested iteration with deterministic aggregation (separate iterator/temporary aggregation structure).
- Persist computed range per summary row, not a page-global variable.

## 7. Integration and Event Architecture
### 7.1 Global Trigger Pattern
- Retain automatic subscribers for true multi-user capture.
- Keep runtime gate ordering:
- Is recording active.
- Acting user equals recorded user.
- Table and field filters permit capture.
- Throttling allows capture.

### 7.2 Old/New Record Fidelity
- On modify events, if old record cannot be read due to permissions, capture should mark degraded fidelity explicitly, not silently produce ambiguous output.

## 8. Security and Privacy
- Decompose broad generated permission set into least-privilege sets:
- Reader: view/debug data only.
- Operator: recording operations.
- Admin: setup and maintenance actions.
- Remove permissive release settings where debugging/source download is not required.
- Complete app privacy/legal/help metadata for publishing readiness.

## 9. Performance and Scalability
- Avoid writes in frequently called setup/state getter paths.
- Reduce repeated BLOB calc overhead in iteration-heavy read paths.
- Preserve throttling controls and validate their behavior under concurrent sessions.
- Maintain lightweight cache invalidation semantics for cross-session state changes.

## 10. Observability and Diagnostics
- Keep run-level IDs and transaction IDs as primary correlation keys.
- Ensure client type and trigger-source metadata are accurate and trustworthy.
- Preserve rollback-safe diagnostics while preventing accidental leakage of sensitive free-form error text in external surfaces.

## 11. Testing Strategy
### 11.1 Test Scope Expansion
- Add regression tests for transaction summary correctness.
- Add permission-lowered tests for modify old-value fidelity behavior.
- Add tests for table scope modes and field-selection combinations.
- Add tests for throttling behavior under burst operations.

### 11.2 Test Packaging
- Keep tests outside production distribution artifact or in a dedicated test app pipeline.

## 12. Delivery Plan
### Wave 0: Safety and Correctness Hotfix
- Exclude demo/bad extension artifacts from production release payload.
- Fix transaction summary grouping and row-time-range correctness.
- Fix client type derivation correctness.
- Clarify no-read-permission modify-capture behavior.

### Wave 1: AppSource Compliance
- Correct field-level data classifications for capture and recording-state tables.
- Complete app metadata (brief, description, privacy, EULA, help URL, public URL).
- Harden release resource exposure posture.

### Wave 2: Multi-User Runtime Robustness
- Move singleton initialization writes to install/upgrade lifecycle.
- Refine setup/cache behavior to reduce side effects and stale windows.
- Remove commit-side effects from validation flow where feasible.

### Wave 3: Security and QA Hardening
- Split permissions into least-privilege sets.
- Expand automated tests for edge cases and concurrency patterns.
- Remove dead/commented API artifacts or promote them to active contract.

## 13. Risks and Mitigations
- Risk: cross-session race conditions in state reads.
- Mitigation: explicit cache invalidation points and deterministic state refresh strategy.

- Risk: privacy review rejection due to misclassification.
- Mitigation: field-level classification matrix and review checklist in CI gate.

- Risk: release contamination by demo artifacts.
- Mitigation: release build profile/folder discipline and pre-release artifact scan.

- Risk: regression while fixing summary logic.
- Mitigation: targeted regression tests and baseline sample data snapshots.

## 14. Spec Decomposition
This requirement is best implemented with 3 linked technical specs:

### Spec A: data-debugger-hardening-core
- Scope: capture/session codeunits, transaction summaries, state initialization, runtime correctness.
- Dependencies: none.
- Estimated phases: 2.

### Spec B: data-debugger-hardening-compliance
- Scope: table field classifications, app metadata, release exposure settings.
- Dependencies: none.
- Estimated phases: 1.

### Spec C: data-debugger-hardening-security-tests
- Scope: permission sets, test segregation and expanded regressions.
- Dependencies: A and B complete.
- Estimated phases: 2.

Execution order: A + B in parallel, then C.

## 15. Acceptance Criteria
- True multi-user recording remains functional end-to-end.
- No production artifact contains demo/dangerous subscriber code.
- Transaction summary page shows correct per-transaction counts and time ranges.
- Client type and trigger context are accurate in captured output.
- Field-level data classifications pass privacy review expectations.
- App metadata is complete for publishing workflows.
- Permission model aligns with least privilege.
- Expanded automated tests pass for multi-user and edge-case scenarios.

## 16. Handoff
1. Create technical specs from this architecture:
- specs for core hardening (A), compliance (B), and security/tests (C).

2. Implement using TDD orchestration:
- Execute A and B in parallel tracks, then execute C.

3. Validate release readiness:
- AppSource-oriented checklist for privacy, permissions, metadata, and artifact hygiene before publish.
