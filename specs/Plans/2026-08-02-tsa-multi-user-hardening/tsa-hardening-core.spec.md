# Spec A: TroubleShooting Assitance Hardening Core

Date: 2026-08-02
Status: Approved
Source Architecture: specs/Plans/2026-08-02-tsa-multi-user-hardening/tsa-multi-user-hardening.architecture.md
Owner: AL Implementation Team

## 1. Goal
Harden core runtime behavior for true multi-user recording by fixing correctness defects and reducing runtime side effects in capture/session flows.

## 2. Scope
### In Scope
- Transaction summary correctness and deterministic grouping.
- Accurate client-type capture metadata.
- Explicit old-record fidelity behavior in modify capture path.
- Reduction/removal of write side effects in hot runtime paths where feasible for this wave.

### Out of Scope
- Privacy classification updates.
- Permission set redesign.
- Packaging and metadata completion.

## 3. Functional Requirements
1. Transaction summary must produce one row per non-null transaction ID with accurate:
- Change count.
- First user.
- Min/Max time range.

2. Summary data must be row-stable:
- No page-global variable leakage across rows.
- No nested cursor corruption of primary loop.

3. Captured Client Type must reflect actual client/session type (not hardcoded client path).

4. Modify capture must explicitly handle permission-constrained old-record access:
- If old record unreadable, behavior must be deterministic and traceable (e.g., empty old payload + explicit marker).

5. Setup/state getter paths used by capture runtime must avoid hidden writes where practical in this wave; if full move is deferred, create explicit technical debt markers and test coverage.

## 4. Target Objects
- src/Pages/DataDebuggerTransactions.Page.al
- src/Codeunits/DataDebuggerContextManager.Codeunit.al
- src/Codeunits/DataDebuggerEventHandlers.Codeunit.al
- src/Codeunits/DataDebuggerSessionManager.Codeunit.al
- src/Tables/DataDebuggerSetup.Table.al (if hot-path write reduction is implemented now)
- src/Tables/DataDebuggerRecordingState.Table.al (if hot-path write reduction is implemented now)
- src/Agent/DDAgentInstall.Codeunit.al (if install-time seeding is introduced here)

## 5. Design Notes
- Preserve true multi-user architecture (recorded user can differ from initiator user).
- Keep automatic Global Trigger subscriber model.
- Avoid breaking existing page/action contracts.
- Favor minimal, targeted changes over broad refactors.

## 6. Non-Functional Requirements
- No regression in start/stop recording flow.
- No measurable degradation in high-frequency capture path.
- No new blocking UI dialogs in capture events.

## 7. Acceptance Criteria
1. Transaction grouping page shows correct counts/times across at least 3 transactions with overlapping timestamps.
2. Client type field is populated with actual runtime type in captured rows.
3. Modify capture behavior is consistent when old record cannot be read and is covered by test.
4. Existing recording tests continue to pass.
5. New tests introduced in this wave pass consistently.

## 8. Test Plan
- Add/extend tests for transaction-summary grouping correctness.
- Add/extend tests for permission-constrained modify capture.
- Add/extend tests for client-type value correctness.

## 9. Delivery Tasks
1. Fix summary aggregation logic and per-row time-range assignment.
2. Replace client-type derivation logic with platform-correct source.
3. Implement explicit no-old-read behavior in modify capture.
4. Add/adjust automated tests.
5. Run full extension compile and tests.

## 10. Dependencies
- None.

## 11. Done Definition
- All acceptance criteria met.
- No new compiler diagnostics introduced.
- PR notes include behavior changes and backward-compatibility confirmation.
