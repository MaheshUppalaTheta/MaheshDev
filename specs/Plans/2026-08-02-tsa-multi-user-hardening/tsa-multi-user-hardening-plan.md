# Plan: TroubleShooting Assistant Multi-User Hardening

TL;DR: Three waves of hardening — core correctness bugs (Spec A), privacy/compliance (Spec B in parallel with A), and security/tests (Spec C after A+B). Preserves true multi-user recording throughout.

**AL Context:**
- Extension: DataDebugger, BC Runtime 17.0, Application 28.0.0.0
- Extension Type: standalone extension (no table/page extensions, own object range 50000–50149)
- AL-Go Structure: single app.json, src/Tests in same project (to remain so for this implementation)
- Dependencies: none

**BCQuality:** active (bundled assets) — applies to all phases.

---

## Phase 2: Spec A — Core Correctness (Wave 0)

**Objective:** Fix 5 confirmed defects in capture/session/context code and add regression tests.

**AL Objects to Create/Modify:**
- `DataDebuggerTransactions` Page 50007 — fix nested cursor + per-row scalar bug
- `DataDebuggerContextManager` Codeunit 50003 — fix GetClientType()
- `DataDebuggerEventHandlers` Codeunit 50001 — fix IsReadable dead-code + xRecRef unpositioned
- `DataDebuggerSessionManager` Codeunit 50000 — replace CalcFields in loop with SetAutoCalcFields
- `DataDebuggerSetup` Table 50001 — remove Insert from GetSetup() hot path
- `DD Recording State` Table 50007 — remove Insert from GetState() hot path
- `DD Agent Install` Codeunit 50009 — add OnInstallAppPerCompany to seed singletons

**Event Architecture:** No new subscribers. All changes are within existing code paths.

**Files to Modify:**
- src/Pages/DataDebuggerTransactions.Page.al
- src/Codeunits/DataDebuggerContextManager.Codeunit.al
- src/Codeunits/DataDebuggerEventHandlers.Codeunit.al
- src/Codeunits/DataDebuggerSessionManager.Codeunit.al
- src/Tables/DataDebuggerSetup.Table.al
- src/Tables/DataDebuggerRecordingState.Table.al
- src/Agent/DDAgentInstall.Codeunit.al
- src/Tests/DataDebuggerRecordingTests.Codeunit.al (extend with A-specific tests)

**Tests to Write (extend codeunit 50140):**
- `ClientType_CapturedCorrectly` — verify Client Type is not always 'Client'
- `ModifyCapture_NoReadPermission_IsTraceable` — xRecRef empty → old data empty, no crash
- `TransactionSummary_GroupsCorrectly` — 3 transactions, verify per-row count and time

**Steps:**
1. Write failing tests first (RED)
2. Fix `GetClientType()` → `exit(Format(CurrentClientType()))`
3. Fix `OnAfterOnGlobalModify` — remove `IsReadable`, add early-exit when no read permission; also fix `xRecRef` must be Open before `ShouldCaptureModification` call
4. Fix `GetChanges` — `SetAutoCalcFields` before loop, remove per-row `CalcFields`
5. Fix `DataDebuggerTransactions.SetData()` — introduce `InnerBuffer` variable, store `TimeRange` per row before `Rec.Insert()`
6. Remove `Insert` from `GetSetup()` and `GetState()` — return default-init record without persisting
7. Add `OnInstallAppPerCompany` to `DDAgentInstall` to seed singletons on install
8. Run tests (GREEN)
9. Validate compile

**Open Questions Phase 2:**
- Should `xRecRef` permission-denied modify captures emit a JSON marker `{"_unreadable":true}` for old data, or silently skip? Default: emit marker.

---

## Phase 3: Spec B — Compliance (Wave 1, parallel with A)

**Objective:** Field-level DataClassification corrections and app.json metadata + exposure policy hardening.

**AL Objects to Modify:**
- `TroubleShooting Assistant Change Buffer` Table 50000 — add DataClassification to fields 8, 9, 11, 12, 16
- `DD Recording State` Table 50007 — add DataClassification to fields 4, 5, 6
- `app.json` — populate brief, description, privacyStatement, EULA, help, url; tighten resourceExposurePolicy

**Files to Modify:**
- src/Tables/DataDebuggerChangeBuffer.Table.al
- src/Tables/DataDebuggerRecordingState.Table.al
- app.json

**No new test code in this phase.** Validation: compile clean, analyzer clean.

---

## Phase 4: Spec C — Security and Tests (Wave 3, after A and B)

**Objective:** Role-based permission sets, artifact hygiene, expanded test suite.

**AL Objects to Create/Modify:**
- `DD-Reader` PermissionSet 50001 — new, read-only viewer access
- `DD-Operator` PermissionSet 50002 — new, operational recording access, includes DD-Reader
- `DD-Admin` PermissionSet 50003 — new, full access, includes DD-Operator
- `GeneratedPermission` PermissionSet 50000 — replaced by composed `DD-Admin`
- `DataDebuggerHardeningTests` Codeunit 50142 — new test codeunit for Spec C scenarios

**Artifact Hygiene:**
- `src/Temp/DemoBadExtension.al` → rename to `DemoBadExtension.al.bak` (excluded from AL compiler)
- `ff.al` → rename to `ff.al.bak` + remove `page "Event Recorder Custom" = X;` from permissionset
- `src/API/DataDebuggerRecordingRunAPI.Query.al` — leave as-is (commented out, no action)

**Files to Create/Modify:**
- GeneratedPermission.permissionset.al (replace with DD-Admin composition)
- New: DDReader.permissionset.al
- New: DDOperator.permissionset.al
- New: DDAdmin.permissionset.al
- src/Tests/ — new test codeunit 50142
- src/Temp/DemoBadExtension.al → .bak
- ff.al → .bak

**Tests to Write (new codeunit 50142):**
- `MultiUser_UserBChanges_NotCapturedWhenRecordingUserA` — confirms user gate works across security IDs
- `MultiUser_UserBChanges_CapturedWhenRecordingUserB` — confirms targeted user IS captured
- `TableScope_WhitelistFilters_OtherTablesIgnored` — only listed tables captured in OnlySelected mode
- `TableScope_BlacklistFilters_ListedTablesIgnored` — listed tables excluded in AllExcept mode
- `FieldSelection_FiltersApplied_UnselectedFieldsAbsent` — field selection filtering works
- `Throttle_BurstChanges_CappedAtLimit` — throttle respects MaxCapturesPerSecond

**Open Questions Phase 4:**
- Should `GeneratedPermission` PermissionSet 50000 be removed entirely or kept as a backward-compat alias pointing to DD-Admin? Default: keep as composed alias (safer for any existing assignments in customer environments).

---

## Delivery Order

| Phase | Wave | Spec | Can run in parallel with |
|-------|------|------|--------------------------|
| 2 | 0 | A — Core Correctness | Phase 3 |
| 3 | 1 | B — Compliance | Phase 2 |
| 4 | 3 | C — Security + Tests | Must follow Phase 2 AND Phase 3 |

---

## Open Questions (Global)
1. For `GetSetup()` / `GetState()` — when no record exists (e.g. first use before install), should the getter return an in-memory default (no Insert) or should it error? Recommended: return in-memory default (Init + field defaults) without Insert. Install seeds it. If somehow missed, the caller gets a valid record without a side-effect write.
2. For `app.json` metadata — privacy statement and EULA URLs: are there specific URLs for this product already? Placeholder format will be used if none provided.
