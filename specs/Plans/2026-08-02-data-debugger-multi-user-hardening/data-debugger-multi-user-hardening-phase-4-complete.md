## Phase 4 Complete: Spec C — Security, Role-Based Permissions & Hardening Tests

Decomposed the monolithic `GeneratedPermission` into three least-privilege roles (DD-Reader, DD-Operator, DD-Admin), deactivated the demo subscriber that applied a destructive 15% price reduction on every sales post, and added a 6-test hardening suite covering the multi-user gate, table scope filters, field selection, and performance throttle.

**AL Objects Created/Modified:**

| Object | Type | Action |
|--------|------|--------|
| DD-Reader (50001) | PermissionSet | Created |
| DD-Operator (50002) | PermissionSet | Created |
| DD-Admin (50003) | PermissionSet | Created |
| GeneratedPermission (50000) | PermissionSet | Modified — replaced body with IncludedPermissionSets = DD-Admin |
| DD Hardening Tests (50142) | Codeunit (Test) | Created — 6 test procedures |
| Demo Bad Extension (50050) | Codeunit | Modified — [EventSubscriber] attribute removed |

**Files created/changed:**

- `DDReader.permissionset.al` — New. R on all capture tables; execute display/read pages only.
- `DDOperator.permissionset.al` — New. Includes DD-Reader + RIMD on recording-control tables (ChangeBuffer, RecordingState, TableFilter, FieldSelectionBuffer, AnalysisBuffer, LiveStats, TablePickBuffer) + execute operational codeunits/pages.
- `DDAdmin.permissionset.al` — New. Includes DD-Operator + RIMD on Setup and Agent tables + execute all admin/agent codeunits and pages.
- `GeneratedPermission.permissionset.al` — Replaced 48-line full-grant with 5-line backward-compat alias pointing to DD-Admin.
- `src/Tests/DataDebuggerHardeningTests.Codeunit.al` — New test codeunit ID 50142 with 6 tests.
- `src/Temp/DemoBadExtension.al` — [EventSubscriber] attribute removed; procedure becomes an inert local, no event binding occurs.

**Tests created:**

| Procedure | What it covers |
|-----------|---------------|
| `MultiUser_OtherUser_NotCaptured` | User gate negative: recording for a fake GUID, current user acts → 0 captures |
| `MultiUser_CurrentUser_Captured` | User gate positive: recording for UserSecurityId(), current user acts → ≥1 capture |
| `TableScope_Whitelist_UnlistedTableIgnored` | Whitelist scope: Vendor in list, Customer modified → 0 Customer captures |
| `TableScope_Blacklist_ListedTableIgnored` | Blacklist scope: Customer in list, Customer modified → 0 Customer captures |
| `FieldFilter_WithSelection_CaptureNotBlocked` | Field selection: Name field selected, Name modified → capture still created |
| `Throttle_Enabled_UnderLimit_AllCaptured` | Throttle path: limit=100, 3 modifies → all 3 captured |

**Skills Applied in This Phase:**

| Skill | Pattern Used | Evidence |
|-------|-------------|----------|
| skill-permissions | Least-privilege role split with IncludedPermissionSets composition | DDReader/Operator/Admin.permissionset.al |
| skill-testing | GIVEN/WHEN/THEN, Initialize isolation, MessageHandler, EnsureCustomer | DataDebuggerHardeningTests.Codeunit.al |

**BCQuality Evidence:**
- Submodule SHA: bundled
- Skills run: al-code-review, al-security-review, al-testing-review, al-style-review
- Outcome: completed (two-pass: NEEDS_REVISION on first pass, fixed, APPROVED_WITH_RECOMMENDATIONS on second)
- Findings addressed: F1–F3 (major — DDReader RIMD→R), F4 (minor — Caption), F6 (minor — GIVEN/WHEN/THEN), F7 (minor — Customer reset), F8/F9 (info — variable names)
- Remaining open: F5 (minor — custom AssertTrue kept for consistency with codeunit 50140 pattern)
- Raw report: `data-debugger-multi-user-hardening-review-phase-4.json`

**Known deviations:**
- `DataDebuggerSetup.Table.al` `GetSetup()` was externally re-edited to re-add `Setup.Insert()` after the Spec A fix. This reverts the singleton-getter write guard. User-accepted deviation; the OnInstallAppPerCompany seed remains as the primary protection.
- `ff.al` (page 50040 "Event Recorder Custom") remains compiled. Its permissionset reference was removed; the page itself is harmless and retained for informational value.

**Review Status:** APPROVED_WITH_RECOMMENDATIONS (0 blocker / 0 major / 1 minor remaining)

**Git Commit Message:**
```
feat(security): role-based permissionsets + hardening tests

Split monolithic GeneratedPermission into DD-Reader (50001),
DD-Operator (50002), DD-Admin (50003) using IncludedPermissionSets
composition. GeneratedPermission becomes a backward-compat alias.

Deactivate DemoBadExtension subscriber (15% sales price reduction
was active in production; [EventSubscriber] attribute removed).

Add 6-test codeunit DD Hardening Tests (50142) covering multi-user
gate, table scope whitelist/blacklist, field selection, and throttle.
```
