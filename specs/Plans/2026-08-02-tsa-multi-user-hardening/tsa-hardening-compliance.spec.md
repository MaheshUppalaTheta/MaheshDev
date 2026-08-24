# Spec B: Data Debugger Hardening Compliance

Date: 2026-08-02
Status: Approved
Source Architecture: specs/Plans/2026-08-02-data-debugger-multi-user-hardening/data-debugger-multi-user-hardening.architecture.md
Owner: AL Implementation Team

## 1. Goal
Bring the extension to AppSource-oriented compliance baseline for privacy classification, app metadata, and release exposure posture.

## 2. Scope
### In Scope
- Field-level DataClassification corrections in core data tables.
- app.json metadata completion.
- Resource exposure policy hardening for release intent.

### Out of Scope
- Core transaction/capture correctness fixes.
- Permission-set decomposition.
- Test-app separation.

## 3. Functional Requirements
1. Data classification for stored capture content must be explicit and appropriate at field level.
2. Recording-state user identity fields must be correctly classified.
3. app.json metadata fields must be populated for publishing workflows:
- brief
- description
- privacyStatement
- EULA
- help
- url

4. Resource exposure policy must reflect release-safe posture:
- avoid shipping with permissive source/debug exposure unless explicitly justified.

## 4. Target Objects
- src/Tables/DataDebuggerChangeBuffer.Table.al
- src/Tables/DataDebuggerRecordingState.Table.al
- app.json

## 5. Design Notes
- Keep functional behavior unchanged in this compliance wave.
- Use field-level overrides when table-level classification is too coarse.
- Metadata URLs should be stable and publicly reachable.

## 6. Non-Functional Requirements
- No runtime behavior change in recording/capture operations.
- No breaking API/page contract changes.

## 7. Acceptance Criteria
1. Table fields storing user identity and payload/call stack are explicitly classified.
2. app.json metadata is fully populated and non-empty.
3. resourceExposurePolicy is reviewed and set to intended release values.
4. Build and analyzer checks pass for changed artifacts.

## 8. Test Plan
- Compile and run analyzers.
- Validate no behavior regressions in smoke run:
- Start recording.
- Capture representative insert/modify.
- Stop and view results.

## 9. Delivery Tasks
1. Define field-classification matrix for both tables.
2. Update table field properties.
3. Populate app metadata fields.
4. Review resourceExposurePolicy and set target posture.
5. Validate compile/analyzers.

## 10. Dependencies
- None.
- Can run in parallel with Spec A.

## 11. Done Definition
- Acceptance criteria met.
- Documentation of classification decisions included in PR description.
