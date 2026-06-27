# Data Debugger – System Overview

## Product Snapshot
- **Purpose:** Capture Business Central database activity in near real time, enrich each change with context, and surface insights that help troubleshoot, optimize, and audit business processes.
- **Version / Platform:** Extension v1.0.0.0 targeting Business Central 26.0+ (runtime 15.0) with object range 50000-50149.
- **Primary Use Cases:** Per-user change tracking (record one selected user's operations environment-wide), performance diagnostics, behavior analysis, compliance auditing, and developer troubleshooting.

## Functional Layers
| Layer | Objects | Responsibilities |
| --- | --- | --- |
| Event Intake | Codeunit 50001 `Data Debugger Event Handlers` | **Automatic** subscribers on the global database triggers (active in every session). Each event is gated by `Session Manager.ShouldCapture()` so only the recorded user's changes pass, then enforces capture guardrails (table filters, throttling, change thresholds) and serializes record snapshots. |
| Filtering & Setup | Codeunit 50002 + Tables 50001/50002 | Centralized filter policy (table allow/deny, field projection, threshold checks, per-second limits) backed by `Data Debugger Setup` and `Table Filter` data. |
| Context Enrichment | Codeunit 50003 `Context Manager` | Augments each change with user/session/company metadata, client type, rolling transaction IDs, real AL call stack (`SessionInformation.Callstack()`, BC 26+), and a derived trigger source label (Database Insert/Modify/Delete/Rename). |
| Session Orchestration | Codeunit 50000 `Session Manager` | Starts/stops runs, persists recording state (active flag, run id, recorded user) in `DD Recording State` (table 50007) so every session can read it, writes captures to the persisted `Change Buffer` (table 50000), exposes live stats, and launches downstream pages. |
| Analytics | Codeunit 50004 `Analysis Engine` + table 50004 | Generates impact, performance, pattern/burst, relationship, and temporary-vs-real insights stored in the `Analysis Buffer`. |
| UI & Visualization | Pages 50000-50009 (+ helper pages) | Card/List pages for recording control, live stats, results, advanced analysis, and context/transaction/table views. |

## Operational Flow
1. **Setup (optional):** Use `Data Debugger Setup` + `Table Filter` pages to configure include/exclude lists, field filtering, change thresholds, and throttling caps.
2. **Recording Lifecycle:** On `Data Debugger` (page 50000) choose the user in **Record User** (defaults to you), click **Start Recording** (writes recording state, clears the previous run's buffer) → the recorded user performs the business process (in their own session, anywhere) → **Stop Recording** (flips the state off, opens results).
3. **Event Capture:** The automatic global-trigger subscribers fire in the acting user's session. Each first checks `Session Manager.ShouldCapture()` (recording active **and** the session belongs to the selected user, matched on User Security ID), then `Filter Manager` (table allow/deny, `CanCaptureNow()`, optional `ShouldCaptureModification()`) before serializing old/new JSON and delegating to `Session Manager.AddChange()`.
4. **Context Injection:** Session Manager invokes context manager hooks so every `Change Buffer` row contains user details, transaction grouping, call stack, client type, and trigger source text.
5. **Exploration & Analysis:**
   - **Results** page filters/drilldowns into captured rows, opens context/field changes, transaction/table summaries, exports (Excel/JSON), and launches advanced analysis.
   - **Live Stats** page aggregates totals, rate, most-active tables/users, session duration, and last activity (with optional auto-refresh).
   - **Advanced Analysis** page copies the buffer, runs the analysis engine, filters by type/severity/category, exports to Excel, and surfaces recommendations.

## Feature Highlights
### Advanced Analysis Suite
- **Impact Analysis:** Quantifies change volume per table, user, and transaction with severity heuristics (Info/Warning/Critical) to spotlight hotspots.
- **Performance Metrics:** Computes change rate averages, gap durations, burst detection, and peak periods for capacity planning.
- **Pattern & Relationship Detection:** Flags high-volume patterns, rapid bursts (sub-second sequences), and multi-table transaction relationships with textual details.
- **Recommendations:** Context-aware guidance covering critical alerts, performance optimizations, monitoring hints, and best practices.

### Temporary vs Real Table Tracking
- Automatic classification for each event, storing `Is Temporary Table`, suffixing temp table names, and enabling table-type filters (All / Real only / Temp only).
- Analysis engine computes distribution percentages, highlights heavy temp usage (>70%) vs balanced workloads, and suggests optimization or validation actions.
- Export pipelines (Excel/JSON) retain table-type metadata for downstream reporting or Power BI ingestion.

### Context-Rich Capture
- User/session/company, client type, transaction IDs, and textual call-stack traces are persisted per entry, enabling forensic debugging and compliance-ready audit trails.

### Call-Stack & Error Capture
Data Debugger captures two distinct kinds of call stack, both stored in the `Call Stack` BLOB of `Change Buffer` (50000):

**1. Live call stack (every change).** For every Insert/Modify/Delete/Rename, `Context Manager.CaptureCallStack()` records `SessionInformation.Callstack()` — the AL call stack at the moment of the database write — and derives a human-readable `Trigger Source` label (Database Insert/Modify/Delete/Rename) from it. This is the always-on path for normal operations. (The stored stack includes Data Debugger's own capture frames at the top.)

**2. Error origin call stack (when the recorded user's process fails).** When a runtime error occurs in the recorded session, Business Central writes an `Error Message` record (table 700) whose `Error Call Stack` field holds the *actual* AL stack where the error was raised. The global **Insert** subscriber (`CaptureInsert`) detects this table specifically and:
- Reads the `Error Call Stack` BLOB straight from the `RecRef` buffer (`TempBlob.FromFieldRef`). It reads with `TextEncoding::Windows` and `Type Helper.ReadAsTextWithSeparator(..., LFSeparator())` to reconstruct the full **multi-line** stack — matching exactly how the platform's own `Error Message.SetErrorCallStack`/`GetErrorCallStack` store and read the field. (It does **not** call `ErrorMessage.GetErrorCallStack()`, because that method does a `CalcFields` that re-reads from the database by primary key, and the row is not yet queryable from inside the insert trigger.)
- Logs the entry with **Change Type = `Error`** (enum value 4) instead of `Insert`.
- Passes the decoded stack through `Session Manager.AddChange(... CallStackOverride)` so the persisted `Call Stack` reflects the error's true origin rather than the synthetic capture-path stack. If the field is empty, a marker string is stored instead — an `Error` entry deliberately never falls back to the live code-execution call stack.

This means an `Error` row in the Results grid points at *where the failure came from*, not where Data Debugger intercepted it — the key value for diagnosing a failed process.

**3. Session last-error capture (at Stop Recording).** Path 2 only fires when an `Error Message` row is *inserted*. A plain runtime error (`Error(...)`) raised by the recorded process does not necessarily write to table 700, so it would otherwise go unrecorded. To cover this, `Start Recording` calls `ClearLastError()` and `Stop Recording` calls `CaptureLastSessionError()`: if `GetLastErrorText()` is non-empty at stop, it logs one final entry — **Change Type = `Error`**, `Table ID = 0` (shown as **"Session Runtime Error"**), `New Data` = `{"ErrorMessage": <text>}`, and `Call Stack` = `GetLastErrorCallStack()` (passed as the override). The capture happens *before* the rollback-safe flush and before `Is Recording` is flipped off, so it is included in the run. **Scope:** `GetLastError*` is session-local, so this reliably catches errors when recording **yourself** (controller session = recorded session); when recording another user in Direct mode, the error occurs in that user's session and is not visible at stop.

> **⚠️ Limitation — interactive "collect all errors" posting is NOT captured.** BC's error-collection framework (`Codeunit "Error Message Management"`) accumulates posting/validation errors in **temporary** `Error Message` records and displays them all at once via `ShowErrors()`. Temporary-record inserts do **not** raise the global `OnDatabaseInsert` trigger, so this path is never seen by the subscriber. Error capture therefore only works for `Error Message` rows actually **persisted** to table 700 (e.g. job-queue error logging, Error Message Register persistence, batch flows via `CopyFromTemp`). Capturing the interactive collect-and-show path would require subscribing to the error-framework integration events (e.g. `OnLogError`) instead of, or in addition to, the DB trigger.

**Interplay with Rollback-Safe Capture.** A raised error rolls back the database transaction, which would normally also discard the `Error Message` row and any captured changes. Because rollback-safe mode (the default) buffers captures in session memory on a SingleInstance codeunit — outside the database transaction — the `Error` entry and all preceding changes survive the rollback and are flushed on `Stop Recording`. `Start Recording` also calls `ClearLastError()` so errors are attributable to the current run. The `DD Test Error Runner` (codeunit 50141) exercises exactly this: it modifies a Customer, raises an error to force a rollback, and the test asserts the in-memory capture survived.

> **Note:** Error capture rides on the **Insert** trigger of table 700, so it requires table 700 to pass the capture scope. In *Only Selected Tables* (whitelist) mode, add `Error Message` (700) to the Table Filters list to keep capturing error stacks.

### Call-Stack Override Mechanism
- **`AddChange` overloads:** `Session Manager` exposes three overloads of `AddChange`; the widest accepts a final `CallStackOverride: Text` argument.
- **`BuildEntry` resolution:** when `CallStackOverride <> ''`, `BuildEntry` writes it verbatim to the `Call Stack` BLOB; otherwise it calls `Context Manager.CaptureCallStack()` to record the live `SessionInformation.Callstack()`.
- **Used by error capture:** two callers supply an override today — `CaptureInsert` (the decoded `Error Call Stack` from table 700, or a marker string when empty) and `CaptureLastSessionError` (the session's `GetLastErrorCallStack()`). New callers wanting to attach a known stack can reuse the same overload.

## Configuration & Performance Notes
- **Filter Manager:** Lazily loads setup, excludes known system and self tables by default, and enforces change-threshold counts (`Min Field Changes Required`) before logging modifications.
- **Throttling:** Optional per-second capture cap prevents system overload; counters reset each second.
- **Session Limits:** `Max Records Per Session` offers guardrails for long recordings.
- **Storage:** The Change Buffer is a persisted database table — captured data survives the session and a crash, and is cleared only at the start of the next recording (the Analysis Buffer remains temporary/in-memory). Payload BLOBs store JSON/call-stack text via streams.

## Setup Configuration Steps
1. **Access Setup:** Open Data Debugger (page 50000) → click **Setup** → opens Setup Card (page 50004).
2. **Table Filtering (Capture Scope):**
   - Set **Table Capture Scope** on the Setup card: **All Tables** (default), **Only Selected Tables** (whitelist), or **All Except Selected Tables** (blacklist).
   - Click **Table Filters** action → opens Table Filters List (page 50005).
   - Add the tables that define the whitelist/blacklist: Table ID + Enabled. (The optional **Select Fields** action refines *which fields* are captured for a table — it does not affect whether the table itself is captured.)
   - Use **Add Common System Tables** action to pre-populate the list with noisy system tables (useful with **All Except Selected Tables**).
3. **Field Filtering (optional, per table):**
   - No global toggle — it applies automatically to any Table Filter row that has fields selected.
   - On the Table Filters page, use the **Select Fields** action to tick the fields to capture for the current row (checkbox list via `DD Field Selection`, page 50111, backed by the **persisted** table `DD Field Selection Buffer`, 50005, keyed by Table ID + Field No.). Edits save immediately and are retained across sessions; deleting a Table Filter row cascades to delete its stored field selections (unless another row still references the same Table ID).
   - Semantics are simple: if any fields are selected, **only** those fields are captured for that table; if none are selected, all fields are captured. Field selection only has effect for tables that are actually captured (i.e. not for tables in an "All Except Selected Tables" exclusion list). Matching is case-insensitive with trimming.
4. **Change Threshold:**
   - Enable → set Min Field Changes Required (default 1, range 1+).
   - ⚠️ **Known Issue:** Currently broken due to uninitialized `xRecRef` in event handler—disable until patched.
5. **Performance Throttling:**
   - Enable → set Max Captures Per Second (default 100, range 1+).
   - Prevents system overload during batch operations; counter resets each second.

## System Requirements & Dependencies
- **Platform:** Business Central 26.0+ (on-premises or cloud), runtime 15.0.
- **Features:** NoImplicitWith (runtime feature flag).
- **Permissions:** Read access to Table Metadata, Field, AllObjWithCaption; write access to temporary buffers during session.

## User Interfaces & Navigation
| Page | Purpose |
| --- | --- |
| `Data Debugger` (Card 50000) | Start/stop control, status banner, live stats preview, links to setup and live analysis. |
| `Data Debugger Results` (List 50001) | Filterable grid with field/context drilldowns, table/transaction summaries, exports, and advanced analysis launch. |
| `Data Debugger Live Stats` (Card 50009) | Auto-refreshing aggregates, most-active tables/users, quick links to analysis/results. |
| `DD Advanced Analysis` (List 50008) | Runs analysis engine, filters by type/severity/category, exports findings, and shows recommendations. |

## Troubleshooting Quick Reference
### Global Triggers Silent
- **Symptoms:** Recording starts but no changes captured, results page empty.
- **Root Causes:**
  1. `SessionManager.ShouldCapture()` returns false → either no recording is active, or the change was made by a different user than the one selected in **Record User** (match is on User Security ID).
  2. `FilterManager.IsTableAllowed()` returns false → check Setup table filters; system tables are excluded by default.
  3. `GetDatabaseTableTriggerSetup` not running → add temporary `Message('Setup for table %1', TableId)` to verify invocation.
- **Subscribers:** The handlers are **automatic** (no `BindSubscription`), so they run in every session. If nothing is captured, confirm a recording is active and that the operations are performed by the **selected** user. Note the platform caches `GetDatabaseTableTriggerSetup` per session, so changing the table filters may not take effect in sessions that are already open.

### No Modifications Captured (Inserts/Deletes Work)
- **Symptoms:** Insert and delete events appear, but modify operations are missing.
- **Root Cause:** `ShouldCaptureModification()` receives uninitialized `xRecRef` parameter, causing it to always return false when change-threshold filtering is enabled.
- **Workarounds:**
  1. Disable "Enable Change Threshold" in Setup.
  2. Patch Event Handlers: Accept `xRecRef` from `OnDatabaseModify` event parameter, pass it to `ShouldCaptureModification()` and `CaptureModify()`.

### Old/New Data Identical in Modify Events
- **Symptoms:** Field Changes page lists no changed fields.
- **Root Cause:** `OnAfterOnGlobalModify` reloads the record after modification (via `xRecRef.Get(RecRef.RecordId)`), capturing the **new** state twice instead of old vs new.
- **Workaround:** Patch Event Handlers to use the `xRecRef` parameter provided by the global trigger event instead of reloading.

### Temporary Tables Misclassified
- **Symptoms:** Known temporary table instances show as real tables or vice versa.
- **Root Cause:** `IsTemporaryTable()` reads `Table Metadata.TableType` (object definition) instead of `RecRef.IsTemporary()` (instance state).
- **Workaround:** Update `IsTemporaryTable()` to check `RecRef.IsTemporary()` first, fall back to metadata if needed.

### Performance or Memory Pressure
- **Symptoms:** UI lag, slow page refresh, high memory usage during recording.
- **Solutions:**
  1. Narrow the Capture Scope (use **Only Selected Tables** with a short list).
  2. Enable performance throttling (max captures per second).
  3. Run multiple shorter sessions instead of one long session.
  4. Use advanced analysis to detect bursts or heavy temp-table usage patterns.

### Missing Context Data
- **Symptoms:** Call stack blank, transaction IDs missing, user names empty.
- **Causes:**
  1. Context Manager not initialized → ensure codeunit 50003 is SingleInstance and not cleared.
  2. Transaction auto-reset → happens after 30s or 1000 changes by design; earlier entries retain old IDs.
  3. Permissions → verify read access to User table, session metadata.

### Export Failures
- **Symptoms:** Excel/JSON export buttons trigger errors or produce empty files.
- **Causes:**
  1. File permissions → check temp folder write access.
  2. Excel Buffer missing → ensure base app references are correct.
  3. BLOB data not loaded → pages must call `CalcFields("Old Data", "New Data", "Call Stack")` before export.

### Analysis Returns No Results
- **Symptoms:** Advanced Analysis page empty after clicking Refresh Analysis.
- **Causes:**
  1. Insufficient data → analysis requires minimum ~10 changes for meaningful patterns.
  2. Empty buffer → ensure source data was passed via `SetSourceData()`.
  3. Filters too restrictive → clear analysis type/severity/category filters.

## Troubleshooting Quick Reference

## Data Model Reference
### Enums
| Enum | Object ID | Values | Purpose |
| --- | --- | --- | --- |
| `Data Debugger Change Type` | 50000 | Insert, Modify, Delete, Rename, **Error** | Classifies the captured entry. `Error` (value 4) marks an entry sourced from an `Error Message` (table 700) insert, whose `Call Stack` holds the error-origin stack. Marked `Extensible = false`. |
| `DD Capture Scope` | 50005 | All Tables, Only Selected Tables, All Except Selected Tables | Single Setup control deciding how the Table Filters list is interpreted (capture all / whitelist / blacklist). |
| `Data Debugger Analysis Type` | 50003 | Impact Analysis, Performance Metric, Pattern Detection, Relationship Mapping | Categorizes analysis buffer entries. |
| `Data Debugger Severity` | 50004 | Info, Warning, Critical | Severity classification for analysis findings. |

### Table Fields Deep Dive
**Data Debugger Change Buffer (50000)**
- **Primary Key:** Entry No. (auto-increment)
- **Indexes:** RunTimestamp (Run ID + Timestamp), TableType (Run ID + Table ID + Change Type), Transaction (Run ID + Transaction ID + Timestamp), User (Run ID + User ID + Timestamp)
- **BLOBs:** Old Data, New Data, Call Stack (use `Get*/Set*` methods for stream-based access). For `Error`-type entries the `Call Stack` holds the error-origin stack copied from `Error Message`.`Error Call Stack`; for all other types it holds the live `SessionInformation.Callstack()`.
- **Context Fields:** User ID, User Name, Company Name, Session ID, Transaction ID, Client Type, Trigger Source
- **Metadata:** Table ID, Table Name, Change Type, Primary Key, Is Temporary Table, Record Count

**Data Debugger Setup (50001)**
- **Singleton:** Primary Key = '' (empty string)
- **Table Filtering:** Table Capture Scope (enum `DD Capture Scope`: All Tables / Only Selected Tables / All Except Selected Tables; defaults to All Tables)
- **Field Filtering:** no setup field — configured per row on Table Filters via the **Select Fields** action; applies whenever a row has fields selected (captures only those fields)
- **Change Threshold:** Enable Change Threshold (Boolean), Min Field Changes Required (Integer, default 1)
- **Performance:** Max Records Per Session (Integer, default 10000), Enable Performance Throttling (Boolean), Max Captures Per Second (Integer, default 100)
- **Helper Method:** `GetSetup()` creates and returns singleton record with defaults

**DD Recording State (50007)**
- **Singleton:** Primary Key = '' (empty string); created on demand by `GetState()`.
- **Purpose:** Holds cross-session recording state so the always-on capture handlers (which run in the recorded user's session) can read it.
- **Fields:** `Is Recording` (Boolean), `Run ID` (Guid), `Recorded User Security ID` (Guid — the match key against `UserSecurityId()`), `Recorded User ID` (Code[50], login name for display), `Recorded User Name` (Text[80]), `Start Time` (DateTime).
- **Written by:** Session Manager `StartRecording`/`StopRecording`. **Read by:** every session's capture path (cached ~1s via `EnsureCacheFresh`).

**Data Debugger Table Filter (50002)**
- **Fields:** Entry No., Table ID (lookup to AllObjWithCaption), Table Name (auto-populated), Enabled (Boolean). Table membership is defined by a row's presence + Enabled; the Setup **Capture Scope** decides whether the list is a whitelist or blacklist. Per-field capture selections live in the separate persisted table `DD Field Selection Buffer` (50005), and are cascade-deleted via this table's OnDelete trigger.
- **Trigger Behavior:** OnInsert/OnModify automatically updates Table Name from metadata

**Data Debugger Live Stats (50003)**
- **Temporary:** Never persisted
- **Fields:** Total Changes, Changes Per Second (decimal 2:2), Duration Text, Last Capture Info, Start Time, Last Capture Time
- **Computed By:** SessionManager.GetLiveStatistics()

**Data Debugger Analysis Buffer (50004)**
- **Temporary:** Holds analysis results in-memory
- **Fields:** Analysis Type (enum), Category (Text[50]), Description (Text[250]), Value (Decimal 2:5), Value Text (Text[100]), Severity (enum), Related Table ID/Name, Details (BLOB), Analysis Timestamp
- **Helper Method:** `SetDetails()`/`GetDetails()` for BLOB stream access

## Page Catalog with Actions
| Page | Object ID | Type | Key Actions | Navigation Target |
| --- | --- | --- | --- | --- |
| Data Debugger | 50000 | Card | Record User (select), Start Recording, Stop Recording, Setup, Live Analysis, Refresh Stats | Main entry point; pick the user to record (User-table lookup, defaults to you), then start/stop; launches Setup (50004), Live Stats (50009) |
| Data Debugger Results | 50001 | List | View Field Changes, View Call Stack, Group by Table, Group by Transaction, Export to Excel/JSON, Advanced Analysis, Clear Filters | Opens Field Changes (50002), Context Details (50006), Table Summary (50003), Transactions (50007), Advanced Analysis (50008). The **Table Filter** field has a drill-down (`DD Table Pick`, 50112, backed by `DD Table Pick Buffer`, 50006) listing the tables present in the results with operation counts; picking one filters the grid to that table by Table ID. The captured Call Stack contains the real AL stack via `SessionInformation.Callstack()`. |
| Data Debugger Field Changes | 50002 | List | Show Only Changed Fields, Export to Excel, Copy to Clipboard | Parses Old/New JSON, displays field-by-field diff in Name/Value Buffer |
| Data Debugger Table Summary | 50003 | List | View Table Changes | Aggregates changes by table, drills back to Results filtered by table |
| Data Debugger Setup | 50004 | Card | Table Filters | Opens Table Filters (50005); edits Setup singleton |
| Data Debugger Table Filters | 50005 | List | Add Common System Tables | Manages Table Filter (50002) records; pre-populates exclusion list |
| Data Debugger Context Details | 50006 | Card | Copy Call Stack, Export Context | Displays user/session/transaction/call stack for selected change |
| Data Debugger Transactions | 50007 | List | View Transaction Changes | Groups changes by Transaction ID, drills into filtered Results |
| DD Advanced Analysis | 50008 | List | Refresh Analysis, View Details, Export Analysis, Show Recommendations | Runs Analysis Engine, filters results, shows recommendations dialog |
| Data Debugger Live Stats | 50009 | Card | Refresh, Detailed Analysis, View All Results | Auto-refresh stats, opens Advanced Analysis or Results from active session |

## API Surface (External / MCP Integration)
These OData v4 API objects expose the persisted capture data for external consumption (e.g. an MCP server that lets Claude analyse a recorded session). All are read-only and share publisher/group/version `theta/dataDebugger/v1.0`.

| Object | ID | Entity Set | Purpose |
| --- | --- | --- | --- |
| `DD Change Entry API` (Page) | 50100 | `changeEntries` | One row per captured change. Surfaces all context fields plus the `oldData`, `newData`, and `callStack` BLOBs decoded to text. Supports OData `$filter` (e.g. by `runId`, `tableId`, `changeType`). |
| `DD Recording Run API` (Query) | 50101 | `recordingRuns` | Summary grouped by `runId` with `changeCount`, `firstChange`, `lastChange` — lets a client discover sessions before drilling into entries. |

**Typical MCP flow:** list `recordingRuns` → pick a `runId` → query `changeEntries?$filter=runId eq {guid}` → read the typed context + old/new JSON + call stack per change.

**Base URL pattern:** `/api/theta/dataDebugger/v1.0/companies({id})/changeEntries`

> Note: `changeEntries` reads the Change Buffer, which is cleared at the start of each new recording. Pull data after stopping (or during) a session, before the next run begins.

## Key Implementation Patterns
### Event Subscriber Architecture
- **Automatic subscribers**: The Event Handlers codeunit uses automatic (not `Manual`) subscribers on `Global Triggers`, so capture runs in every user session — this is what allows recording a *selected* user's operations regardless of which session they occur in (mirrors the base Change Log). No `BindSubscription` is used.
- **User gating**: Every On* handler calls `Session Manager.ShouldCapture()`, which returns true only when a recording is active and `UserSecurityId()` matches the recorded user stored in `DD Recording State`. The state is cached per session for ~1 second to keep the always-on path cheap.
- **SingleInstance = true**: All manager codeunits maintain state across invocations within the same session; cross-session truth (active flag, run id, recorded user) lives in `DD Recording State` (table 50007).
- **GetDatabaseTableTriggerSetup**: Gated on table filters only (not on "is recording"), because the platform caches it per session — gating on recording state would stop already-open sessions from ever raising triggers. Returns `true` for Insert/Modify/Delete/Rename on allowed tables. **Footprint:** because it is always-on, choosing **Only Selected Tables** keeps the per-write overhead in idle sessions minimal.

### JSON Serialization Strategy
- **RecordToJson()**: Iterates FieldRef, skips system fields/flowfields/BLOBs, formats by FieldType, applies field filtering before writing.
- **Field Filtering**: `FilterManager.FilterFields()` reads the selected fields for the table from `DD Field Selection Buffer` (50005) and, if any are selected, keeps only those keys in the JsonObject before storage.
- **Parsing**: Field Changes page uses `JsonObject.ReadFrom()` / `Get()` to reconstruct Name/Value pairs.

### Transaction Auto-Reset Logic
- **Triggers:** Context Manager resets Transaction ID after 30 seconds OR 1000 changes (whichever comes first).
- **Purpose:** Groups logically related changes without unbounded growth; useful for relationship mapping.

### Analysis Engine Thresholds
- **Impact Analysis Severity:** Critical if change count > 100, Warning if > 20, else Info.
- **Pattern Detection:** High-volume pattern if count > 50 (Critical if > 200), burst if ≥10 changes within 1 second.
- **Performance Metrics:** Max gap > 60 seconds triggers Warning severity.
- **Table Type Analysis:** Warning if temp usage > 70%, Info otherwise.

### Export Mechanisms
- **Excel Export:** Uses `Excel Buffer` temporary table with headers/data rows, calls `CreateNewBook()` / `WriteSheet()` / `SetFriendlyFilename()` / `OpenExcel()`.
- **JSON Export:** Serializes Change Buffer via JsonArray/JsonObject, triggers file download.
- **Analysis Export:** Same Excel pattern but sourced from Analysis Buffer instead of Change Buffer.

## Known Issues & Workarounds
### Critical Bugs (Documented Earlier)
1. **Change-Threshold Filtering Broken:** `ShouldCaptureModification()` receives uninitialized `xRecRef`, always returns false when enabled. **Workaround:** Disable change threshold or patch Event Handlers to pass `xRecRef` from `OnDatabaseModify` event parameter.
2. **Modify Events Store Duplicate Data:** Old and new payloads are identical because `OnAfterOnGlobalModify` reloads the already-updated record instead of using event's `xRecRef`. **Workaround:** Patch Event Handlers to accept and use `xRecRef` parameter from global trigger event.
3. **IsTemporaryTable Misclassifies Instances:** Reads `Table Metadata.TableType` (object definition) instead of `RecRef.IsTemporary()` (instance state). **Workaround:** Update `IsTemporaryTable()` to check record instance first.

### Excluded System Tables (Hard-Coded in Filter Manager)
- Change Log Entry (497), Change Log Setup (498), Change Log Entry (Archive) (2000000053), Activity Log (2000000110), Record Link (2000000068), Delete Log (2000000112), Session Event, System Change Log (2000000168), User Session Log (2000000111), Scheduled Task
- **Self-Exclusion:** the extension's **entire reserved object range 50000-50149** (per `app.json` idRanges) is excluded to prevent recursion. This is a range check, not a per-table list, so every current and future Data Debugger table is covered automatically — including `DD Recording State` (50007), which is modified on every start/stop and was previously captured because the old hard-coded list only covered 50000-50004.

### Performance Considerations
- **Large Sessions:** 10,000+ changes may slow UI refresh; use table filters or shorter recording windows.
- **Throttling Reset:** Per-second counter resets synchronously; microsecond bursts may exceed cap before reset.
- **Analysis Engine:** Dictionary-based algorithms scale linearly; expect ~1-2 seconds for 10,000 changes on modern hardware.

## Extensibility Tips
- **New Analysis:** Add another `Perform*` routine in `Analysis Engine` and invoke it from `AnalyzeChanges()`; store specialized details via `AnalysisBuffer.SetDetails()`.
- **Custom Filters:** Extend `Data Debugger Table Filter` with additional metadata—`Filter Manager` already honors include/exclude records and field lists.
- **UI Enhancements:** Pages needing current-session data should call `SessionManager.GetCurrentSessionData()` to obtain a temporary copy without mutating the live buffer.
- **Automation:** Exported JSON can feed Power BI or automated alerting; leverage recommendations output as a seed for playbooks.
- **New Enums:** All enums are marked `Extensible = true` except `Change Type`—add custom analysis types, severities, or filter modes via enum extensions.

## Common Development Scenarios
### Scenario 1: Add New Analysis Metric
1. Open `DataDebuggerAnalysisEngine.Codeunit.al` (50004).
2. Create new `Perform*` local procedure (e.g., `PerformCustomAnalysis()`).
3. Call it from `AnalyzeChanges()` after existing analysis routines.
4. Populate Analysis Buffer with custom entries using new Category/Description values.
5. Optionally extend `Data Debugger Analysis Type` enum for filtering.

### Scenario 2: Exclude Custom Tables from Capture
1. Open Data Debugger Setup → click Table Filters.
2. Set **Table Capture Scope = All Except Selected Tables**, then add a row: Table ID = your table, Enabled = Yes.
3. Alternatively, update `IsSystemTableExcluded()` in Filter Manager to hard-code exclusions.

### Scenario 3: Create Custom Results View
1. Create new page sourcing temporary `Data Debugger Change Buffer`.
2. Call `SessionManager.GetCurrentSessionData(TempBuffer)` to populate.
3. Add custom filters/groupings/visualizations as needed.
4. Link from Results page actions or Advanced Analysis page.

### Scenario 4: Integrate with External System
1. Use Export to JSON action to generate machine-readable output.
2. Parse JSON in external tool (Python, Power BI, custom AL integration).
3. For real-time integration, extend Session Manager to expose event publishers or webhook calls.

### Scenario 5: Debug Change-Threshold Issue
1. Locate `OnAfterOnGlobalModify` in Event Handlers codeunit.
2. Change signature to accept `xRecRef: RecordRef` parameter from event.
3. Pass `xRecRef` directly to `ShouldCaptureModification()` and `CaptureModify()`.
4. Remove the `xRecRef.Open()` / `xRecRef.Get()` logic that reloads the record.
5. Test with change threshold enabled—modifications should now appear.

## Document Intent & Maintenance
This single overview replaces previous scattered docs (`ARCHITECTURE*.md`, `ADVANCED_FEATURES_GUIDE.md`, `EVENT_TROUBLESHOOTING.md`, `TEMPORARY_TABLE_TRACKING.md`). Keep it as the canonical technical reference for contributors and AI assistants.

**Update triggers:**
- New features/pages/tables/enums → add to relevant catalog section.
- Configuration changes → update Setup Configuration Steps.
- Bug fixes → remove from Known Issues, add to Troubleshooting if symptom persists.
- Performance tuning → document thresholds in Implementation Patterns.
- API changes → update manager responsibilities and extensibility tips.

**For AI assistant (Copilot) usage:**
- This doc provides complete context for understanding system architecture, making code changes, troubleshooting user issues, and extending functionality.
- Cross-reference object IDs, table/enum names, and page actions when writing code.
- Consult Known Issues section before implementing features that may conflict with documented bugs.
- Use Page Catalog for navigation flows when designing UI enhancements.
- Reference Implementation Patterns when debugging or optimizing existing code.

