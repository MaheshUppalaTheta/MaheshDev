## Phase 2+3 Complete: Spec A (Core Correctness) + Spec B (Compliance)

Two parallel phases completed. All 20 acceptance criteria pass. Three minor review findings addressed inline before commit; two deferred to Spec C or backlog.

## AL Objects Created/Modified

**Spec A:**
- `Data Debugger Transactions` Page 50007 — fixed nested FindSet cursor; `InnerBuffer` var for inner loop; time range stored per row in `Rec.Value`; `TransactionTime` page-global removed
- `Data Debugger Context Manager` Codeunit 50003 — `GetClientType()` replaced with `exit(Format(CurrentClientType()))`
- `Data Debugger Event Handlers` Codeunit 50001 — `IsReadable: Boolean` removed; `xRecRef.Open()` moved before `ShouldCaptureModification`; no-read-permission path: `CaptureModify` then exit
- `Data Debugger Session Manager` Codeunit 50000 — `SetAutoCalcFields("Old Data","New Data","Call Stack")` before `SetRange` in `GetChanges`; per-row `CalcFields` removed
- `Data Debugger Setup` Table 50001 — `GetSetup()` returns Init'd default without `Insert()`
- `DD Recording State` Table 50007 — `GetState()` returns Init'd default without `Insert()`
- `DD Agent Install` Codeunit 50009 — `OnInstallAppPerCompany` seeds both singletons; `LearnMoreUrlTxt` fixed to 2+ URL path levels

**Spec B:**
- `Data Debugger Change Buffer` Table 50000 — `DataClassification` overrides on fields 7 (CustomerContent), 8 (CustomerContent), 9 (CustomerContent), 11 (EndUserPseudonymousIdentifiers), 12 (EndUserIdentifiableInformation), 16 (CustomerContent)
- `DD Recording State` Table 50007 — `DataClassification` overrides on fields 4 (EndUserPseudonymousIdentifiers), 5 (EndUserPseudonymousIdentifiers), 6 (EndUserIdentifiableInformation)
- `app.json` — brief, description, privacyStatement, EULA, help, url all populated; `allowDebugging: false`; `allowDownloadingSource: false`

## Files Created/Changed

- src/Pages/DataDebuggerTransactions.Page.al — Fix 1 (cursor) + ToolTip on Transaction ID field (F1)
- src/Codeunits/DataDebuggerContextManager.Codeunit.al — Fix 2 (GetClientType)
- src/Codeunits/DataDebuggerEventHandlers.Codeunit.al — Fix 3 (IsReadable/xRecRef)
- src/Codeunits/DataDebuggerSessionManager.Codeunit.al — Fix 4 (SetAutoCalcFields)
- src/Tables/DataDebuggerSetup.Table.al — Fix 5A (getter read-only)
- src/Tables/DataDebuggerRecordingState.Table.al — Fix 5B (getter read-only) + DataClassification fields 4,5,6
- src/Agent/DDAgentInstall.Codeunit.al — Fix 5C (OnInstallAppPerCompany + URL)
- src/Tests/DataDebuggerRecordingTests.Codeunit.al — 3 new tests + SetDirectCapture upsert fix (F2)
- src/Tables/DataDebuggerChangeBuffer.Table.al — DataClassification on fields 7,8,9,11,12,16
- app.json — metadata + exposure policy

## Tests Created/Changed

Codeunit 50140 `DD Recording Tests` — 3 new procedures added:
- `ClientType_CapturedCorrectly` — verifies Client Type is not hard-coded 'Client'
- `ModifyCapture_DoesNotThrow` — verifies normal modify path works after xRecRef restructure
- `TransactionGrouping_Setup_Valid` — verifies 3 modifies → 3 GetChanges entries

`SetDirectCapture` helper — changed from GetSetup/Modify to upsert pattern (prevents CI failure when singleton not yet seeded)

## Skills Applied in This Phase

| Skill | Pattern Used | Evidence |
|-------|-------------|----------|
| skill-performance | SetAutoCalcFields before FindSet; removed per-row CalcFields | DataDebuggerSessionManager.Codeunit.al GetChanges |
| skill-testing | GIVEN/WHEN/THEN for 3 new tests; upsert fixture isolation | DataDebuggerRecordingTests.Codeunit.al lines 320+ |

## BCQuality Evidence

- Submodule SHA: bundled
- Skills run: al-privacy-review, al-performance-review, al-style-review, al-appsource-review
- Outcome: completed
- Findings: 0 blocker / 0 major / 4 minor / 2 info; 3 actionable fixed inline, 2 deferred
- Raw report: specs/Plans/2026-08-02-data-debugger-multi-user-hardening/data-debugger-multi-user-hardening-review-phase-2-3.json

## Deferred Findings

- F3: `SessionStartTime` never populated in `SetData()` — pre-existing design gap; deferred to post-Spec-C cleanup
- F4: `SourceBuffer` parameter unused in `SetData()` — pre-existing design gap; deferred
- F5 (info): `privacyStatement` URL points to OVERVIEW.md not a dedicated privacy policy — requires authoring a privacy policy document

## Review Status

APPROVED_WITH_RECOMMENDATIONS (0/0/4/2 — three minors fixed inline)

## Git Commit Message

```
fix: Spec A+B core correctness and compliance hardening

Spec A — fix 5 confirmed defects:
- Transactions page: separate InnerBuffer var fixes nested FindSet
  cursor corruption; time range stored per row in Rec.Value
- ContextManager: GetClientType() uses CurrentClientType() not SessionId()
- EventHandlers: remove dead IsReadable; open xRecRef before
  ShouldCaptureModification; deterministic no-read-permission path
- SessionManager: SetAutoCalcFields before GetChanges loop
- Setup/State getters: return Init'd default without Insert()
- DDAgentInstall: OnInstallAppPerCompany seeds both singletons;
  fix LearnMoreUrl to 2+ path levels

Spec B — privacy compliance:
- ChangeBuffer fields 7-9,11-12,16: field-level DataClassification
  overrides (CustomerContent / EndUserPseudonymous / EndUserIdentifiable)
- RecordingState fields 4-6: EndUserPseudonymous / EndUserIdentifiable
- app.json: populate metadata; allowDebugging/allowDownloadingSource false

Tests: 3 new regression tests; SetDirectCapture uses upsert pattern
```
