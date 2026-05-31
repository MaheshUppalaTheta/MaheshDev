# Data Debugger – System Overview

## Product Snapshot
- **Purpose:** Capture Business Central database activity in near real time, enrich each change with context, and surface insights that help troubleshoot, optimize, and audit business processes.
- **Version / Platform:** Extension v1.0.0.0 targeting Business Central 26.0+ (runtime 15.0) with object range 50000-50149.
- **Primary Use Cases:** Real-time change tracking, performance diagnostics, behavior analysis, compliance auditing, and developer troubleshooting.

## Functional Layers
| Layer | Objects | Responsibilities |
| --- | --- | --- |
| Event Intake | Codeunit 50001 `Data Debugger Event Handlers` | Subscribes to global database triggers, enforces capture guardrails (table filters, throttling, change thresholds), and serializes record snapshots. |
| Filtering & Setup | Codeunit 50002 + Tables 50001/50002 | Centralized filter policy (table allow/deny, field projection, threshold checks, per-second limits) backed by `Data Debugger Setup` and `Table Filter` data. |
| Context Enrichment | Codeunit 50003 `Context Manager` | Augments each change with user/session/company metadata, client type, rolling transaction IDs, real AL call stack (`SessionInformation.Callstack()`, BC 26+), and a derived trigger source label (Database Insert/Modify/Delete/Rename). |
| Session Orchestration | Codeunit 50000 `Session Manager` | Starts/stops runs, holds the in-memory `Change Buffer` (table 50000), exposes live stats, and launches downstream pages. |
| Analytics | Codeunit 50004 `Analysis Engine` + table 50004 | Generates impact, performance, pattern/burst, relationship, and temporary-vs-real insights stored in the `Analysis Buffer`. |
| UI & Visualization | Pages 50000-50013 + control add-in | Card/List pages for recording control, live stats, results, advanced analysis, context/transaction/table views, and a jsondiffpatch-based record comparison add-in. |

## Operational Flow
1. **Setup (optional):** Use `Data Debugger Setup` + `Table Filter` pages to configure include/exclude lists, field filtering, change thresholds, and throttling caps.
2. **Recording Lifecycle:** On `Data Debugger` (page 50000) click **Start Recording** (binds handlers, resets temp buffer) → perform business process → **Stop Recording** (opens results, clears buffer).
3. **Event Capture:** Global trigger subscribers call `Filter Manager` (table allow/deny, `CanCaptureNow()`, optional `ShouldCaptureModification()`) before serializing old/new JSON and delegating to `Session Manager.AddChange()`.
4. **Context Injection:** Session Manager invokes context manager hooks so every `Change Buffer` row contains user details, transaction grouping, call stack, client type, and trigger source text.
5. **Exploration & Analysis:**
   - **Results** page filters/drilldowns into captured rows, opens context/field changes, transaction/table summaries, exports (Excel/JSON), and launches advanced analysis or record comparison.
   - **Live Stats** page aggregates totals, rate, most-active tables/users, session duration, and last activity (with optional auto-refresh).
   - **Advanced Analysis** page copies the buffer, runs the analysis engine, filters by type/severity/category, exports to Excel, and surfaces recommendations.
6. **Record Comparison:** `DD Record Comparison` page + control add-in load Old/New JSON and field metadata into jsondiffpatch visual diffing (with drill-down actions and exports).

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

## Configuration & Performance Notes
- **Filter Manager:** Lazily loads setup, excludes known system and self tables by default, and enforces change-threshold counts (`Min Field Changes Required`) before logging modifications.
- **Throttling:** Optional per-second capture cap prevents system overload; counters reset each second.
- **Session Limits:** `Max Records Per Session` offers guardrails for long recordings.
- **Storage:** Change and analysis buffers are temporary tables; payload BLOBs store JSON/call-stack text via streams to minimize database writes.

## Setup Configuration Steps
1. **Access Setup:** Open Data Debugger (page 50000) → click **Setup** → opens Setup Card (page 50004).
2. **Table Filtering:**
   - Enable → choose mode: **Include Only** (whitelist) or **Exclude Only** (blacklist).
   - Click **Table Filters** action → opens Table Filters List (page 50005).
   - Add entries with Table ID, Filter Type (Include/Exclude), optional Field Filters (comma-separated), and Enabled flag.
   - Use **Add Common System Tables** action to pre-populate exclusions (Change Log, Activity Log, etc.).
3. **Field Filtering:**
   - Enable → requires per-table field list in Table Filter records.
   - Field Filters field accepts comma-separated field names; matching is case-insensitive with trimming.
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
- **Browser:** Modern browser supporting ES6 for control add-in (jsondiffpatch requires UMD module support).
- **External Dependencies:** jsondiffpatch 0.4.1 loaded from unpkg.com CDN (Scripts/StyleSheets in control add-in definition).

## User Interfaces & Navigation
| Page | Purpose |
| --- | --- |
| `Data Debugger` (Card 50000) | Start/stop control, status banner, live stats preview, links to setup and live analysis. |
| `Data Debugger Results` (List 50001) | Filterable grid with field/context drilldowns, table/transaction summaries, exports, advanced analysis launch, and record comparison. |
| `Data Debugger Live Stats` (Card 50009) | Auto-refreshing aggregates, most-active tables/users, quick links to analysis/results. |
| `DD Advanced Analysis` (List 50008) | Runs analysis engine, filters by type/severity/category, exports findings, shows recommendations, opens record comparison. |
| `DD Record Comparison` + selector pages | Host the control add-in, display record metadata, interpret add-in events (field select, related records, exports). |

## Troubleshooting Quick Reference
### Global Triggers Silent
- **Symptoms:** Recording starts but no changes captured, results page empty.
- **Root Causes:**
  1. `SessionManager.IsActive()` returns false → verify Start Recording was clicked and succeeded.
  2. `FilterManager.IsTableAllowed()` returns false → check Setup table filters; system tables are excluded by default.
  3. `GetDatabaseTableTriggerSetup` not running → add temporary `Message('Setup for table %1', TableId)` to verify invocation.
- **Event Binding:** If using `EventSubscriberInstance = Manual`, ensure `BindSubscription(DDEventHandler)` is called in Start Recording and `UnbindSubscription()` in Stop. Consider switching to automatic subscribers (remove Manual property and binding logic).

### No Modifications Captured (Inserts/Deletes Work)
- **Symptoms:** Insert and delete events appear, but modify operations are missing.
- **Root Cause:** `ShouldCaptureModification()` receives uninitialized `xRecRef` parameter, causing it to always return false when change-threshold filtering is enabled.
- **Workarounds:**
  1. Disable "Enable Change Threshold" in Setup.
  2. Patch Event Handlers: Accept `xRecRef` from `OnDatabaseModify` event parameter, pass it to `ShouldCaptureModification()` and `CaptureModify()`.

### Old/New Data Identical in Modify Events
- **Symptoms:** Record comparison shows no differences; field changes page lists no changed fields.
- **Root Cause:** `OnAfterOnGlobalModify` reloads the record after modification (via `xRecRef.Get(RecRef.RecordId)`), capturing the **new** state twice instead of old vs new.
- **Workaround:** Patch Event Handlers to use the `xRecRef` parameter provided by the global trigger event instead of reloading.

### Temporary Tables Misclassified
- **Symptoms:** Known temporary table instances show as real tables or vice versa.
- **Root Cause:** `IsTemporaryTable()` reads `Table Metadata.TableType` (object definition) instead of `RecRef.IsTemporary()` (instance state).
- **Workaround:** Update `IsTemporaryTable()` to check `RecRef.IsTemporary()` first, fall back to metadata if needed.

### Performance or Memory Pressure
- **Symptoms:** UI lag, slow page refresh, high memory usage during recording.
- **Solutions:**
  1. Narrow table filters (use Include Only mode with specific tables).
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

### Control Add-in Not Loading
- **Symptoms:** Record Comparison page blank, no jsondiffpatch visualization.
- **Causes:**
  1. CDN blocked → unpkg.com must be accessible from browser.
  2. Browser compatibility → requires ES6 module support.
  3. Script/stylesheet paths → verify relative paths in control add-in definition match deployment.

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
| `Data Debugger Change Type` | 50000 | Insert, Modify, Delete, Rename | Classifies database operation type. |
| `DD Table Filter Mode` | 50001 | Include Only, Exclude Only | Determines setup page table filter behavior. |
| `Data Debugger Filter Type` | 50002 | Include, Exclude | Per-table filter action in `Table Filter` records. |
| `Data Debugger Analysis Type` | 50003 | Impact Analysis, Performance Metric, Pattern Detection, Relationship Mapping | Categorizes analysis buffer entries. |
| `Data Debugger Severity` | 50004 | Info, Warning, Critical | Severity classification for analysis findings. |

### Table Fields Deep Dive
**Data Debugger Change Buffer (50000)**
- **Primary Key:** Entry No. (auto-increment)
- **Indexes:** RunTimestamp (Run ID + Timestamp), TableType (Run ID + Table ID + Change Type), Transaction (Run ID + Transaction ID + Timestamp), User (Run ID + User ID + Timestamp)
- **BLOBs:** Old Data, New Data, Call Stack (use `Get*/Set*` methods for stream-based access)
- **Context Fields:** User ID, User Name, Company Name, Session ID, Transaction ID, Client Type, Trigger Source
- **Metadata:** Table ID, Table Name, Change Type, Primary Key, Is Temporary Table, Record Count

**Data Debugger Setup (50001)**
- **Singleton:** Primary Key = '' (empty string)
- **Table Filtering:** Enable Table Filtering (Boolean), Table Filter Mode (enum)
- **Field Filtering:** Enable Field Filtering (Boolean)
- **Change Threshold:** Enable Change Threshold (Boolean), Min Field Changes Required (Integer, default 1)
- **Performance:** Max Records Per Session (Integer, default 10000), Enable Performance Throttling (Boolean), Max Captures Per Second (Integer, default 100)
- **Helper Method:** `GetSetup()` creates and returns singleton record with defaults

**Data Debugger Table Filter (50002)**
- **Fields:** Entry No., Table ID (with lookup to AllObjWithCaption), Table Name (auto-populated), Filter Type (enum), Field Filters (Text[2000] comma-separated), Enabled (Boolean)
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
| Data Debugger | 50000 | Card | Start Recording, Stop Recording, Setup, Live Analysis, Refresh Stats | Main entry point; launches Setup (50004), Live Stats (50009) |
| Data Debugger Results | 50001 | List | View Field Changes, View Call Stack, Group by Table, Group by Transaction, Export to Excel/JSON, Advanced Analysis, Clear Filters, Record Comparison | Opens Field Changes (50002), Context Details (50006), Table Summary (50003), Transactions (50007), Advanced Analysis (50008), Record Comparison (50011). The captured Call Stack now contains the real AL stack via `SessionInformation.Callstack()`. |
| Data Debugger Field Changes | 50002 | List | Show Only Changed Fields, Export to Excel, Copy to Clipboard | Parses Old/New JSON, displays field-by-field diff in Name/Value Buffer |
| Data Debugger Table Summary | 50003 | List | View Table Changes | Aggregates changes by table, drills back to Results filtered by table |
| Data Debugger Setup | 50004 | Card | Table Filters | Opens Table Filters (50005); edits Setup singleton |
| Data Debugger Table Filters | 50005 | List | Add Common System Tables | Manages Table Filter (50002) records; pre-populates exclusion list |
| Data Debugger Context Details | 50006 | Card | Copy Call Stack, Export Context | Displays user/session/transaction/call stack for selected change |
| Data Debugger Transactions | 50007 | List | View Transaction Changes | Groups changes by Transaction ID, drills into filtered Results |
| DD Advanced Analysis | 50008 | List | Refresh Analysis, View Details, Export Analysis, Show Recommendations, Compare Records | Runs Analysis Engine, filters results, shows recommendations dialog, launches Record Comparison |
| Data Debugger Live Stats | 50009 | Card | Refresh, Detailed Analysis, View All Results | Auto-refresh stats, opens Advanced Analysis or Results from active session |
| DD Record Comparison | 50011 | Card | Load Comparison, Refresh, Export, Show Field Details | Hosts control add-in, loads Old/New JSON + metadata into jsondiffpatch visualizer |
| DD Field Comparison Details | 50012 | Card | (View only) | Drill-down from Record Comparison; shows single-field diff with old/new values, lengths, change type |
| DD Record Comparison Selection | 50013 | List | Select Record, View Details, Compare Record | Selection dialog for Record Comparison page |

## Key Implementation Patterns
### Event Subscriber Architecture
- **EventSubscriberInstance = Manual**: Requires explicit `BindSubscription(DDEventHandler)` / `UnbindSubscription(DDEventHandler)` calls in Start/Stop Recording actions.
- **SingleInstance = true**: All manager codeunits maintain state across invocations within the same session.
- **GetDatabaseTableTriggerSetup**: Must return `true` for Insert/Modify/Delete/Rename parameters to enable global triggers per table.

### JSON Serialization Strategy
- **RecordToJson()**: Iterates FieldRef, skips system fields/flowfields/BLOBs, formats by FieldType, applies field filtering before writing.
- **Field Filtering**: `FilterManager.FilterFields()` mutates JsonObject per table filter rules before storage.
- **Parsing**: Field Changes page uses `JsonObject.ReadFrom()` / `Get()` to reconstruct Name/Value pairs.

### Transaction Auto-Reset Logic
- **Triggers:** Context Manager resets Transaction ID after 30 seconds OR 1000 changes (whichever comes first).
- **Purpose:** Groups logically related changes without unbounded growth; useful for relationship mapping.

### Analysis Engine Thresholds
- **Impact Analysis Severity:** Critical if change count > 100, Warning if > 20, else Info.
- **Pattern Detection:** High-volume pattern if count > 50 (Critical if > 200), burst if ≥10 changes within 1 second.
- **Performance Metrics:** Max gap > 60 seconds triggers Warning severity.
- **Table Type Analysis:** Warning if temp usage > 70%, Info otherwise.

### Control Add-in Integration
- **Scripts:** External jsondiffpatch UMD bundle + local RecordComparison.js/Startup.js.
- **Events:** `OnFieldSelected`, `OnViewRelatedRecords`, `OnExportReady`, `OnFiltersChanged` bridge add-in actions to AL.
- **Methods:** `Initialize(config)`, `LoadComparison(oldData, newData, metadata)`, `ApplyFilters(filters)`, `ExportComparison(format)`, `ClearData()`.

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
- Change Log Entry (497), Change Log Setup (498), Activity Log (2000000110), Record Link (2000000068), Delete Log (2000000112), Session Event, System Change Log (2000000168), User Session Log (2000000111), Scheduled Task
- **Self-Exclusion:** All Data Debugger tables (50000-50004) to prevent recursion

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
2. Add row: Table ID = your table, Filter Type = Exclude, Enabled = Yes.
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

