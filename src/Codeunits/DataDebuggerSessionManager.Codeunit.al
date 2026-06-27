codeunit 50000 "Data Debugger Session Manager"
{
    SingleInstance = true;

    var
        // In-memory capture buffer used when "Rollback-Safe Capture" is on. Because this lives in
        // session memory on a SingleInstance codeunit, it is NOT part of the database transaction,
        // so a process error/rollback does not discard it. It is flushed to the persisted Change
        // Buffer table on StopRecording.
        TempChangeBuffer: Record "Data Debugger Change Buffer" temporary;
        // AutoIncrement does not fire on temporary tables, so we assign Entry No. ourselves.
        LastTempEntryNo: Integer;

        // Per-session cache of the recording state. Capture-path code (which can run in any
        // user's session on every database write) reads these instead of hitting the database
        // each time. The cache is refreshed at most once per second.
        CacheValid: Boolean;
        CacheTime: DateTime;
        CachedIsRecording: Boolean;
        CachedRunId: Guid;
        CachedRecUserSecId: Guid;
        CachedRollbackSafe: Boolean;

    procedure StartRecording(RecUserSecurityId: Guid; RecUserId: Code[50]; RecUserName: Text): Guid
    var
        State: Record "DD Recording State";
        ChangeBuffer: Record "Data Debugger Change Buffer";
        Setup: Record "Data Debugger Setup";
        ContextManager: Codeunit "Data Debugger Context Manager";
        FilterManager: Codeunit "Data Debugger Filter Manager";
        NewRunId: Guid;
    begin
        if IsNullGuid(RecUserSecurityId) then
            Error('Select a user to record before starting.');

        // Pick up any setup changes made since the client session started.
        FilterManager.ReloadSetup();
        Setup := Setup.GetSetup();

        // Clear any existing captured data from the previous run (both stores).
        ChangeBuffer.Reset();
        ChangeBuffer.DeleteAll();
        TempChangeBuffer.Reset();
        TempChangeBuffer.DeleteAll();
        LastTempEntryNo := 0;

        NewRunId := CreateGuid();

        State := State.GetState();
        State."Is Recording" := true;
        State."Run ID" := NewRunId;
        State."Recorded User Security ID" := RecUserSecurityId;
        State."Recorded User ID" := RecUserId;
        State."Recorded User Name" := CopyStr(RecUserName, 1, MaxStrLen(State."Recorded User Name"));
        State."Start Time" := CurrentDateTime();
        // Snapshot the capture mode for the run so the recorded user's session reads a stable value.
        // Rollback-safe is the default; only the explicit "Direct Database Capture" opt-in disables it.
        State."Rollback-Safe Capture" := not Setup."Direct Database Capture";
        State.Modify();

        // Start a fresh transaction context for the recording session.
        ContextManager.StartNewTransaction();

        // Clear any previous error state so we can detect errors that occur during this recording.
        ClearLastError();

        InvalidateCache();

        Message('Data Debugger recording started for user %1. Run ID: %2', RecUserId, NewRunId);
        exit(NewRunId);
    end;

    procedure StopRecording()
    var
        State: Record "DD Recording State";
        TempBuffer: Record "Data Debugger Change Buffer" temporary;
        DataDebuggerResults: Page "Data Debugger Results";
        ContextManager: Codeunit "Data Debugger Context Manager";
        RunId: Guid;
        StartTime: DateTime;
    begin
        State := State.GetState();
        if not State."Is Recording" then begin
            Message('No active recording session found.');
            exit;
        end;

        RunId := State."Run ID";
        StartTime := State."Start Time";

        // If the recorded process raised a (trapped) runtime error during this run, log it as a
        // final Error entry. Done before the flush and before flipping "Is Recording" off, so the
        // entry is included in the rollback-safe flush. ClearLastError() at StartRecording scopes
        // this to the current run.
        CaptureLastSessionError();

        // If we captured in memory, persist it now (after the recorded process has finished, so a
        // mid-process rollback could not have discarded it). Commit so the flushed rows survive.
        if State."Rollback-Safe Capture" then begin
            FlushTempToReal();
            Commit();
        end;

        State."Is Recording" := false;
        State.Modify();
        InvalidateCache();

        // End transaction context
        ContextManager.EndTransaction();

        Message('Data Debugger recording stopped. Captured %1 changes.', GetTotalChangeCount(RunId));

        // Open results page with captured data (persisted; survives the session).
        // GetChanges(TempBuffer);
        // DataDebuggerResults.SetData(TempBuffer, RunId, StartTime);
        // DataDebuggerResults.RunModal();
    end;

    local procedure CaptureLastSessionError()
    var
        JsonObj: JsonObject;
        ErrorText: Text;
        ErrorCallStack: Text;
        NewDataJson: Text;
    begin
        // GetLastErrorText/GetLastErrorCallStack reflect the last (trapped) error in this session.
        // StartRecording cleared them, so a non-empty value here belongs to the current run.
        ErrorText := GetLastErrorText();
        if ErrorText = '' then
            exit;

        ErrorCallStack := GetLastErrorCallStack();
        if ErrorCallStack = '' then
            ErrorCallStack := '(no error call stack available)';

        JsonObj.Add('ErrorMessage', ErrorText);
        JsonObj.WriteTo(NewDataJson);

        // Table 0 → "Session Runtime Error" (see BuildEntry). The error-origin call stack is passed
        // as the override so it is stored verbatim, not the synthetic capture-path stack.
        AddChange(0, "Data Debugger Change Type"::Error, ErrorText, '', NewDataJson, false, ErrorCallStack);
    end;

    procedure IsActive(): Boolean
    begin
        EnsureCacheFresh();
        exit(CachedIsRecording);
    end;

    /// <summary>
    /// Returns true only when a recording is active AND the current session belongs to the
    /// user selected for the run. This is the gate the global-trigger handlers use so that
    /// only the chosen user's database operations are captured.
    /// </summary>
    procedure ShouldCapture(): Boolean
    begin
        EnsureCacheFresh();
        if not CachedIsRecording then
            exit(false);
        exit(UserSecurityId() = CachedRecUserSecId);
    end;

    procedure GetCurrentRunId(): Guid
    var
        State: Record "DD Recording State";
    begin
        State := State.GetState();
        exit(State."Run ID");
    end;

    procedure GetRecordingUserId(): Code[50]
    var
        State: Record "DD Recording State";
    begin
        State := State.GetState();
        exit(State."Recorded User ID");
    end;

    procedure AddChange(TableId: Integer; ChangeType: Enum "Data Debugger Change Type"; PrimaryKey: Text; OldDataJson: Text; NewDataJson: Text)
    begin
        AddChange(TableId, ChangeType, PrimaryKey, OldDataJson, NewDataJson, false);
    end;

    procedure AddChange(TableId: Integer; ChangeType: Enum "Data Debugger Change Type"; PrimaryKey: Text; OldDataJson: Text; NewDataJson: Text; IsTemporaryTable: Boolean)
    begin
        AddChange(TableId, ChangeType, PrimaryKey, OldDataJson, NewDataJson, IsTemporaryTable, '');
    end;

    procedure AddChange(TableId: Integer; ChangeType: Enum "Data Debugger Change Type"; PrimaryKey: Text; OldDataJson: Text; NewDataJson: Text; IsTemporaryTable: Boolean; CallStackOverride: Text)
    var
        ChangeBuffer: Record "Data Debugger Change Buffer";
    begin
        EnsureCacheFresh();
        if not CachedIsRecording then
            exit;

        // Build the entry in a (non-temporary) record buffer first, so the context helpers always
        // operate on the same record type regardless of where the entry is ultimately stored.
        BuildEntry(ChangeBuffer, TableId, ChangeType, PrimaryKey, OldDataJson, NewDataJson, IsTemporaryTable, CallStackOverride);

        if CachedRollbackSafe then begin
            // Rollback-safe: copy into the in-memory buffer so a process error/rollback cannot
            // discard it. The record assignment carries the in-memory BLOB values.
            LastTempEntryNo += 1;
            TempChangeBuffer := ChangeBuffer;
            TempChangeBuffer."Entry No." := LastTempEntryNo; // AutoIncrement does not fire on temp tables
            TempChangeBuffer.Insert();
        end else
            // Direct mode: write straight to the persisted table (supports recording another user,
            // but the rows roll back if the recorded process errors).
            ChangeBuffer.Insert(); // "Entry No." AutoIncrement is assigned by the platform
    end;



    local procedure BuildEntry(var Buf: Record "Data Debugger Change Buffer"; TableId: Integer; ChangeType: Enum "Data Debugger Change Type"; PrimaryKey: Text; OldDataJson: Text; NewDataJson: Text; IsTemporaryTable: Boolean; CallStackOverride: Text)
    var
        TableMetadata: Record "Table Metadata";
        ContextManager: Codeunit "Data Debugger Context Manager";
    begin
        Buf.Init();
        Buf."Run ID" := CachedRunId;
        Buf.Timestamp1 := CurrentDateTime();
        Buf."Table ID" := TableId;
        Buf."Change Type" := ChangeType;
        Buf."Primary Key" := CopyStr(PrimaryKey, 1, MaxStrLen(Buf."Primary Key"));
        Buf."Is Temporary Table" := IsTemporaryTable;

        // Get table name with temporary indicator
        if TableMetadata.Get(TableId) then begin
            if IsTemporaryTable then
                Buf."Table Name" := TableMetadata.Name + ' (Temp)'
            else
                Buf."Table Name" := TableMetadata.Name;
        end else if TableId = 0 then
                // Synthetic entry: a session-level runtime error captured at Stop Recording, not a row change.
                Buf."Table Name" := 'Session Runtime Error'
        else begin
            if IsTemporaryTable then
                Buf."Table Name" := Format(TableId) + ' (Temp)'
            else
                Buf."Table Name" := Format(TableId);
        end;

        Buf.SetOldData(OldDataJson);
        Buf.SetNewData(NewDataJson);

        // Capture enhanced context information. These run in the recorded user's own session,
        // so the user/session/call-stack context reflects that user.
        ContextManager.CaptureUserContext(Buf);
        ContextManager.CaptureTransactionContext(Buf);

        // Use the call stack from the source record (e.g., Error Message table) if provided,
        // otherwise capture the current call stack.
        if CallStackOverride <> '' then
            Buf.SetCallStack(CallStackOverride)
        else
            ContextManager.CaptureCallStack(Buf);
    end;

    local procedure FlushTempToReal()
    var
        RealBuffer: Record "Data Debugger Change Buffer";
        NextEntryNo: Integer;
    begin
        // Move the in-memory capture into the persisted table, preserving capture order. BLOBs are
        // transferred via the table's stream helpers so their content copies reliably.
        TempChangeBuffer.Reset();
        TempChangeBuffer.SetCurrentKey("Entry No.");
        if not TempChangeBuffer.FindSet() then
            exit;

        // Assign Entry No. explicitly (max existing + 1) instead of relying on AutoIncrement: the
        // table's identity seed can drift behind the data, which would otherwise cause a duplicate
        // "Entry No." collision here. This is safe whether the table is empty or still has rows.
        if RealBuffer.FindLast() then
            NextEntryNo := RealBuffer."Entry No." + 1
        else
            NextEntryNo := 1;

        repeat
            RealBuffer.Init();
            RealBuffer."Entry No." := NextEntryNo;
            NextEntryNo += 1;
            RealBuffer."Run ID" := TempChangeBuffer."Run ID";
            RealBuffer.Timestamp1 := TempChangeBuffer.Timestamp1;
            RealBuffer."Table ID" := TempChangeBuffer."Table ID";
            RealBuffer."Table Name" := TempChangeBuffer."Table Name";
            RealBuffer."Change Type" := TempChangeBuffer."Change Type";
            RealBuffer."Primary Key" := TempChangeBuffer."Primary Key";
            RealBuffer."Record Count" := TempChangeBuffer."Record Count";
            RealBuffer."User ID" := TempChangeBuffer."User ID";
            RealBuffer."User Name" := TempChangeBuffer."User Name";
            RealBuffer."Company Name" := TempChangeBuffer."Company Name";
            RealBuffer."Session ID" := TempChangeBuffer."Session ID";
            RealBuffer."Transaction ID" := TempChangeBuffer."Transaction ID";
            RealBuffer."Trigger Source" := TempChangeBuffer."Trigger Source";
            RealBuffer."Client Type" := TempChangeBuffer."Client Type";
            RealBuffer."Is Temporary Table" := TempChangeBuffer."Is Temporary Table";
            RealBuffer.SetOldData(TempChangeBuffer.GetOldData());
            RealBuffer.SetNewData(TempChangeBuffer.GetNewData());
            RealBuffer.SetCallStack(TempChangeBuffer.GetCallStack());
            RealBuffer.Insert(); // "Entry No." assigned explicitly above
        until TempChangeBuffer.Next() = 0;
    end;

    /// <summary>
    /// Deletes all previously captured change entries so a fresh recording starts clean.
    /// Safe to call between runs; blocked while a recording is active.
    /// </summary>
    procedure ClearCapturedData()
    var
        ChangeBuffer: Record "Data Debugger Change Buffer";
    begin
        if IsActive() then
            Error('Stop the current recording before clearing captured data.');

        ChangeBuffer.Reset();
        ChangeBuffer.DeleteAll();

        TempChangeBuffer.Reset();
        TempChangeBuffer.DeleteAll();
        LastTempEntryNo := 0;
    end;

    local procedure GetTotalChangeCount(RunId: Guid): Integer
    var
        ChangeBuffer: Record "Data Debugger Change Buffer";
    begin
        ChangeBuffer.SetRange("Run ID", RunId);
        exit(ChangeBuffer.Count());
    end;

    procedure GetChanges(var TempBuffer: Record "Data Debugger Change Buffer" temporary)
    var
        ChangeBuffer: Record "Data Debugger Change Buffer";
        State: Record "DD Recording State";
    begin
        TempBuffer.Reset();
        TempBuffer.DeleteAll();

        EnsureCacheFresh();
        // While a rollback-safe run is active the captures live only in memory (not yet flushed),
        // so read them from there; otherwise read the persisted table for this run.
        if CachedIsRecording and CachedRollbackSafe then begin
            TempChangeBuffer.Reset();
            if TempChangeBuffer.FindSet() then
                repeat
                    TempBuffer := TempChangeBuffer;
                    TempBuffer.Insert();
                until TempChangeBuffer.Next() = 0;
            exit;
        end;

        State := State.GetState();
        ChangeBuffer.SetRange("Run ID", State."Run ID");
        if ChangeBuffer.FindSet() then
            repeat
                // Load BLOBs so they are carried by the assignment into the temporary buffer.
                ChangeBuffer.CalcFields("Old Data", "New Data", "Call Stack");
                TempBuffer := ChangeBuffer;
                TempBuffer.Insert();
            until ChangeBuffer.Next() = 0;
    end;

    procedure GetLiveStatistics(): Record "Data Debugger Live Stats"
    var
        Stats: Record "Data Debugger Live Stats";
        State: Record "DD Recording State";
        ChangeBuffer: Record "Data Debugger Change Buffer";
        Duration: Duration;
        TotalChanges: Integer;
        ChangesPerSecond: Decimal;
        LastCaptureTime: DateTime;
        LastCaptureTable: Text;
    begin
        Stats.Init();

        State := State.GetState();
        if State."Is Recording" and (State."Start Time" <> 0DT) then begin
            if State."Rollback-Safe Capture" then begin
                // Captures are still in memory during the run.
                TempChangeBuffer.Reset();
                TotalChanges := TempChangeBuffer.Count();
                TempChangeBuffer.SetCurrentKey("Entry No.");
                if TempChangeBuffer.FindLast() then begin
                    LastCaptureTime := TempChangeBuffer.Timestamp1;
                    LastCaptureTable := TempChangeBuffer."Table Name";
                end;
            end else begin
                ChangeBuffer.SetCurrentKey("Run ID", Timestamp1);
                ChangeBuffer.SetRange("Run ID", State."Run ID");
                TotalChanges := ChangeBuffer.Count();
                if ChangeBuffer.FindLast() then begin
                    LastCaptureTime := ChangeBuffer.Timestamp1;
                    LastCaptureTable := ChangeBuffer."Table Name";
                end;
            end;

            Duration := CurrentDateTime() - State."Start Time";

            Stats."Total Changes" := TotalChanges;
            Stats."Start Time" := State."Start Time";
            Stats."Last Capture Time" := LastCaptureTime;

            // Calculate changes per second
            if Duration > 0 then
                ChangesPerSecond := TotalChanges / (Duration / 1000)
            else
                ChangesPerSecond := 0;
            Stats."Changes Per Second" := ChangesPerSecond;

            // Format duration
            Stats."Duration Text" := FormatDuration(Duration);

            // Last capture info
            if LastCaptureTime <> 0DT then
                Stats."Last Capture Info" := StrSubstNo('%1 (%2)', LastCaptureTable, Format(LastCaptureTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>'))
            else
                Stats."Last Capture Info" := 'No captures yet';
        end;

        exit(Stats);
    end;

    procedure GetCurrentSessionData(var TempBuffer: Record "Data Debugger Change Buffer" temporary)
    begin
        GetChanges(TempBuffer);
    end;

    procedure ShowResults()
    var
        State: Record "DD Recording State";
        TempBuffer: Record "Data Debugger Change Buffer" temporary;
        DataDebuggerResults: Page "Data Debugger Results";
    begin
        State := State.GetState();
        GetChanges(TempBuffer);
        DataDebuggerResults.SetData(TempBuffer, State."Run ID", State."Start Time");
        DataDebuggerResults.RunModal();
    end;

    procedure GetSessionStartTime(): DateTime
    var
        State: Record "DD Recording State";
    begin
        State := State.GetState();
        exit(State."Start Time");
    end;

    internal procedure IsStateActive(): Boolean
    var
        State: Record "DD Recording State";
    begin
        if State.Get('') then
            exit(State."Is Recording");
        exit(false);
    end;

    local procedure EnsureCacheFresh()
    var
        State: Record "DD Recording State";
    begin
        if CacheValid then
            exit;
        if CacheTime <> 0DT then
            if ((CurrentDateTime() - CacheTime) < 1000) then
                exit;

        if State.Get('') then begin
            CachedIsRecording := State."Is Recording";
            CachedRunId := State."Run ID";
            CachedRecUserSecId := State."Recorded User Security ID";
            CachedRollbackSafe := State."Rollback-Safe Capture";
        end else begin
            CachedIsRecording := false;
            Clear(CachedRunId);
            Clear(CachedRecUserSecId);
            CachedRollbackSafe := false;
        end;
        CacheValid := true;
        CacheTime := CurrentDateTime();
    end;

    local procedure InvalidateCache()
    begin
        CacheValid := false;
    end;

    local procedure FormatDuration(Duration: Duration): Text
    var
        TotalSeconds: Integer;
        Hours: Integer;
        Minutes: Integer;
        Seconds: Integer;
    begin
        TotalSeconds := Duration div 1000;
        Hours := TotalSeconds div 3600;
        Minutes := (TotalSeconds mod 3600) div 60;
        Seconds := TotalSeconds mod 60;

        if Hours > 0 then
            exit(StrSubstNo('%1h %2m %3s', Hours, Minutes, Seconds))
        else if Minutes > 0 then
            exit(StrSubstNo('%1m %2s', Minutes, Seconds))
        else
            exit(StrSubstNo('%1s', Seconds));
    end;
}
