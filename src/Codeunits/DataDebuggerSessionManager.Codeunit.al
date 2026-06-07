codeunit 50000 "Data Debugger Session Manager"
{
    SingleInstance = true;

    var
        TempChangeBuffer: Record "Data Debugger Change Buffer";
        CurrentRunId: Guid;
        IsRecordingActive: Boolean;
        SessionStartTime: DateTime;
        LastCaptureTime: DateTime;
        LastCaptureTable: Text;

    procedure StartRecording(): Guid
    var
        ContextManager: Codeunit "Data Debugger Context Manager";
        FilterManager: Codeunit "Data Debugger Filter Manager";
    begin
        // Pick up any setup changes made since the client session started.
        FilterManager.ReloadSetup();

        // Clear any existing buffer
        TempChangeBuffer.Reset();
        TempChangeBuffer.DeleteAll();

        // Generate new run ID and start recording
        CurrentRunId := CreateGuid();
        IsRecordingActive := true;
        SessionStartTime := CurrentDateTime();

        // Start new transaction context
        ContextManager.StartNewTransaction();

        Message('Data Debugger recording started. Run ID: %1', CurrentRunId);
        exit(CurrentRunId);
    end;

    procedure StopRecording()
    var
        DataDebuggerResults: Page "Data Debugger Results";
        ContextManager: Codeunit "Data Debugger Context Manager";
    begin
        if not IsRecordingActive then begin
            Message('No active recording session found.');
            exit;
        end;

        IsRecordingActive := false;

        // End transaction context
        ContextManager.EndTransaction();

        Message('Data Debugger recording stopped. Captured %1 changes.', GetTotalChangeCount());

        // Open results page with captured data
        DataDebuggerResults.SetData(TempChangeBuffer, CurrentRunId, SessionStartTime);
        DataDebuggerResults.RunModal();

        // Data is now persisted and kept after the session ends.
        // It is wiped at the start of the next recording (see StartRecording).
        Clear(CurrentRunId);
    end;

    procedure IsActive(): Boolean
    begin
        exit(IsRecordingActive);
    end;

    procedure GetCurrentRunId(): Guid
    begin
        exit(CurrentRunId);
    end;

    procedure AddChange(TableId: Integer; ChangeType: Enum "Data Debugger Change Type"; PrimaryKey: Text; OldDataJson: Text; NewDataJson: Text)
    begin
        AddChange(TableId, ChangeType, PrimaryKey, OldDataJson, NewDataJson, false);
    end;

    procedure AddChange(TableId: Integer; ChangeType: Enum "Data Debugger Change Type"; PrimaryKey: Text; OldDataJson: Text; NewDataJson: Text; IsTemporaryTable: Boolean)
    var
        TableMetadata: Record "Table Metadata";
        ContextManager: Codeunit "Data Debugger Context Manager";
    begin
        if not IsRecordingActive then
            exit;

        TempChangeBuffer.Init();
        TempChangeBuffer."Entry No." := TempChangeBuffer.Count() + 1;
        // "Entry No." is AutoIncrement on this persisted table - let the platform assign it.
        TempChangeBuffer."Run ID" := CurrentRunId;
        TempChangeBuffer.Timestamp1 := CurrentDateTime();
        TempChangeBuffer."Table ID" := TableId;
        TempChangeBuffer."Change Type" := ChangeType;
        TempChangeBuffer."Primary Key" := CopyStr(PrimaryKey, 1, MaxStrLen(TempChangeBuffer."Primary Key"));
        TempChangeBuffer."Is Temporary Table" := IsTemporaryTable;

        // Get table name with temporary indicator
        if TableMetadata.Get(TableId) then begin
            if IsTemporaryTable then
                TempChangeBuffer."Table Name" := TableMetadata.Name + ' (Temp)'
            else
                TempChangeBuffer."Table Name" := TableMetadata.Name;
        end else begin
            if IsTemporaryTable then
                TempChangeBuffer."Table Name" := Format(TableId) + ' (Temp)'
            else
                TempChangeBuffer."Table Name" := Format(TableId);
        end;

        TempChangeBuffer.SetOldData(OldDataJson);
        TempChangeBuffer.SetNewData(NewDataJson);

        // Capture enhanced context information
        ContextManager.CaptureUserContext(TempChangeBuffer);
        ContextManager.CaptureTransactionContext(TempChangeBuffer);
        ContextManager.CaptureCallStack(TempChangeBuffer);

        // Update live statistics
        LastCaptureTime := CurrentDateTime();
        LastCaptureTable := TempChangeBuffer."Table Name";

        TempChangeBuffer.Insert();
    end;

    local procedure GetTotalChangeCount(): Integer
    begin
        TempChangeBuffer.Reset();
        exit(TempChangeBuffer.Count());
    end;

    procedure GetChanges(var TempBuffer: Record "Data Debugger Change Buffer" temporary)
    begin
        TempBuffer.Reset();
        TempBuffer.DeleteAll();

        TempChangeBuffer.Reset();
        if TempChangeBuffer.FindSet() then
            repeat
                // Load BLOBs so they are carried by the assignment into the temporary buffer.
                TempChangeBuffer.CalcFields("Old Data", "New Data", "Call Stack");
                TempBuffer := TempChangeBuffer;
                TempBuffer.Insert();
            until TempChangeBuffer.Next() = 0;
    end;

    procedure GetLiveStatistics(): Record "Data Debugger Live Stats"
    var
        Stats: Record "Data Debugger Live Stats";
        Duration: Duration;
        TotalChanges: Integer;
        ChangesPerSecond: Decimal;
    begin
        Stats.Init();

        if IsRecordingActive and (SessionStartTime <> 0DT) then begin
            TotalChanges := GetTotalChangeCount();
            Duration := CurrentDateTime() - SessionStartTime;

            Stats."Total Changes" := TotalChanges;
            Stats."Start Time" := SessionStartTime;
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
        DataDebuggerResults: Page "Data Debugger Results";
    begin
        if not IsRecordingActive then begin
            Message('No active recording session found.');
            exit;
        end;

        DataDebuggerResults.SetData(TempChangeBuffer, CurrentRunId, SessionStartTime);
        DataDebuggerResults.RunModal();
    end;

    procedure GetSessionStartTime(): DateTime
    begin
        exit(SessionStartTime);
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