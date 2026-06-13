codeunit 50000 "Data Debugger Session Manager"
{
    SingleInstance = true;

    var
        // Per-session cache of the recording state. Capture-path code (which can run in any
        // user's session on every database write) reads these instead of hitting the database
        // each time. The cache is refreshed at most once per second.
        CacheValid: Boolean;
        CacheTime: DateTime;
        CachedIsRecording: Boolean;
        CachedRunId: Guid;
        CachedRecUserSecId: Guid;

    procedure StartRecording(RecUserSecurityId: Guid; RecUserId: Code[50]; RecUserName: Text): Guid
    var
        State: Record "DD Recording State";
        ChangeBuffer: Record "Data Debugger Change Buffer";
        ContextManager: Codeunit "Data Debugger Context Manager";
        FilterManager: Codeunit "Data Debugger Filter Manager";
        NewRunId: Guid;
    begin
        if IsNullGuid(RecUserSecurityId) then
            Error('Select a user to record before starting.');

        // Pick up any setup changes made since the client session started.
        FilterManager.ReloadSetup();

        // Clear any existing captured data from the previous run.
        ChangeBuffer.Reset();
        ChangeBuffer.DeleteAll();

        NewRunId := CreateGuid();

        State := State.GetState();
        State."Is Recording" := true;
        State."Run ID" := NewRunId;
        State."Recorded User Security ID" := RecUserSecurityId;
        State."Recorded User ID" := RecUserId;
        State."Recorded User Name" := CopyStr(RecUserName, 1, MaxStrLen(State."Recorded User Name"));
        State."Start Time" := CurrentDateTime();
        State.Modify();

        // Start a fresh transaction context for the recording session.
        ContextManager.StartNewTransaction();

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
    var
        ChangeBuffer: Record "Data Debugger Change Buffer";
        TableMetadata: Record "Table Metadata";
        ContextManager: Codeunit "Data Debugger Context Manager";
    begin
        EnsureCacheFresh();
        if not CachedIsRecording then
            exit;

        ChangeBuffer.Init();
        // "Entry No." is AutoIncrement - let the platform assign it.
        ChangeBuffer."Run ID" := CachedRunId;
        ChangeBuffer.Timestamp1 := CurrentDateTime();
        ChangeBuffer."Table ID" := TableId;
        ChangeBuffer."Change Type" := ChangeType;
        ChangeBuffer."Primary Key" := CopyStr(PrimaryKey, 1, MaxStrLen(ChangeBuffer."Primary Key"));
        ChangeBuffer."Is Temporary Table" := IsTemporaryTable;

        // Get table name with temporary indicator
        if TableMetadata.Get(TableId) then begin
            if IsTemporaryTable then
                ChangeBuffer."Table Name" := TableMetadata.Name + ' (Temp)'
            else
                ChangeBuffer."Table Name" := TableMetadata.Name;
        end else begin
            if IsTemporaryTable then
                ChangeBuffer."Table Name" := Format(TableId) + ' (Temp)'
            else
                ChangeBuffer."Table Name" := Format(TableId);
        end;

        ChangeBuffer.SetOldData(OldDataJson);
        ChangeBuffer.SetNewData(NewDataJson);

        // Capture enhanced context information. These run in the recorded user's own session,
        // so the user/session/call-stack context reflects that user.
        ContextManager.CaptureUserContext(ChangeBuffer);
        ContextManager.CaptureTransactionContext(ChangeBuffer);
        ContextManager.CaptureCallStack(ChangeBuffer);

        ChangeBuffer.Insert();
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
            ChangeBuffer.SetCurrentKey("Run ID", Timestamp1);
            ChangeBuffer.SetRange("Run ID", State."Run ID");
            TotalChanges := ChangeBuffer.Count();
            if ChangeBuffer.FindLast() then begin
                LastCaptureTime := ChangeBuffer.Timestamp1;
                LastCaptureTable := ChangeBuffer."Table Name";
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
        end else begin
            CachedIsRecording := false;
            Clear(CachedRunId);
            Clear(CachedRecUserSecId);
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
