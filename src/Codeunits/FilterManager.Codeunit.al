codeunit 72930452 "Filter Manager_TSA_TSL"
{
    SingleInstance = true;

    var
        Setup: Record "Setup_TSA_TSL";
        IsSetupLoaded: Boolean;
        LastCaptureTime: DateTime;
        CaptureCount: Integer;
        LastSecond: Integer;

    procedure IsTableAllowed(TableId: Integer): Boolean
    begin
        LoadSetup();

        // System/self tables are always excluded.
        if IsSystemTableExcluded(TableId) then
            exit(false);

        // A single Capture Scope decides how the Table Filters list is interpreted.
        case Setup."Table Capture Scope" of
            Setup."Table Capture Scope"::"All Tables":
                exit(true);
            Setup."Table Capture Scope"::"Only Selected Tables":
                exit(IsTableInList(TableId)); // whitelist: only listed tables
            Setup."Table Capture Scope"::"All Except Selected Tables":
                exit(not IsTableInList(TableId)); // blacklist: everything except listed tables
        end;

        exit(true);
    end;

    local procedure IsTableInList(TableId: Integer): Boolean
    var
        TableFilter: Record "Table Filter_TSA_TSL";
    begin
        TableFilter.SetRange("Table ID", TableId);
        TableFilter.SetRange(Enabled, true);
        exit(not TableFilter.IsEmpty());
    end;

    procedure ShouldCaptureModification(RecRef: RecordRef; xRecRef: RecordRef): Boolean
    var
        FieldRef: FieldRef;
        xFieldRef: FieldRef;
        ChangedFieldCount: Integer;
        i: Integer;
    begin
        LoadSetup();

        // If change threshold is not enabled, capture all modifications
        if not Setup."Enable Change Threshold" then
            exit(true);

        // Count changed fields
        ChangedFieldCount := 0;
        for i := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(i);
            xFieldRef := xRecRef.FieldIndex(i);

            // Only count normal fields
            if FieldRef.Class() = FieldClass::Normal then begin
                if Format(FieldRef.Value()) <> Format(xFieldRef.Value()) then
                    ChangedFieldCount += 1;
            end;
        end;

        exit(ChangedFieldCount >= Setup."Min Field Changes Required");
    end;

    procedure FilterFields(var JsonObj: JsonObject; TableId: Integer)
    var
        FieldSel: Record "Field Select Buffer_TSA_TSL";
        SelectedNames: List of [Text];
        Keys: List of [Text];
        KeyText: Text;
        TempJsonObj: JsonObject;
        JsonToken: JsonToken;
    begin
        // Field filtering applies per table: only for tables that have selected fields.
        // When fields are selected, we capture ONLY those fields for that table.
        FieldSel.SetRange("Table ID", TableId);
        FieldSel.SetRange(Selected, true);
        if FieldSel.IsEmpty() then
            exit; // No field selection - capture all fields

        FieldSel.FindSet();
        repeat
            SelectedNames.Add(FieldSel."Field Name".ToLower());
        until FieldSel.Next() = 0;

        Clear(TempJsonObj);
        Keys := JsonObj.Keys();
        foreach KeyText in Keys do begin
            JsonObj.Get(KeyText, JsonToken);
            if SelectedNames.Contains(KeyText.ToLower()) then
                TempJsonObj.Add(KeyText, JsonToken);
        end;

        JsonObj := TempJsonObj;
    end;

    procedure CanCaptureNow(): Boolean
    var
        CurrentTime: DateTime;
        CurrentSecond: Integer;
    begin
        LoadSetup();

        // If throttling is not enabled, always allow capture
        if not Setup."Enable Performance Throttling" then
            exit(true);

        CurrentTime := CurrentDateTime();
        CurrentSecond := Time2Seconds(DT2Time(CurrentTime));

        // Reset counter if we're in a new second
        if CurrentSecond <> LastSecond then begin
            CaptureCount := 0;
            LastSecond := CurrentSecond;
        end;

        // Check if we've exceeded the limit
        if CaptureCount >= Setup."Max Captures Per Second" then
            exit(false);

        CaptureCount += 1;
        LastCaptureTime := CurrentTime;
        exit(true);
    end;

    procedure ReloadSetup()
    begin
        // Forces the next LoadSetup() to re-read the Setup record.
        // Called when a recording starts so setup changes take effect without restarting the client.
        IsSetupLoaded := false;
    end;

    local procedure LoadSetup()
    begin
        if not IsSetupLoaded then begin
            Setup := Setup.GetSetup();
            IsSetupLoaded := true;
        end;
    end;

    local procedure IsSystemTableExcluded(TableId: Integer): Boolean
    var
        ExcludedTables: array[100] of Integer;
        i: Integer;
    begin

        // Initialize array with specific change log and system table IDs
        ExcludedTables[1] := Database::"Change Log Entry";
        ExcludedTables[2] := Database::"Change Log Setup (Table)";
        ExcludedTables[3] := 2000000053; // Change Log Entry (Archive)
        ExcludedTables[4] := Database::"Activity Log";
        ExcludedTables[5] := 2000000068; // Record Link
        ExcludedTables[6] := 2000000112; // Delete Log
        ExcludedTables[7] := Database::"Session Event";
        ExcludedTables[8] := 2000000168; // System Change Log
        ExcludedTables[9] := 2000000111; // User Session Log
        ExcludedTables[10] := Database::"Scheduled Task";

        // Exclude Troubleshooting Assistance's own tables to prevent recursive recording
        ExcludedTables[11] := Database::"Change Buffer_TSA_TSL";
        ExcludedTables[12] := Database::"Setup_TSA_TSL";
        ExcludedTables[13] := Database::"Table Filter_TSA_TSL";
        ExcludedTables[14] := Database::"Live Stats_TSA_TSL";
        ExcludedTables[15] := Database::"Analysis Buffer_TSA_TSL";
        ExcludedTables[16] := Database::"Field Select Buffer_TSA_TSL";
        ExcludedTables[17] := Database::"Recording State_TSA_TSL";
        ExcludedTables[18] := Database::"Table Pick Buffer_TSA_TSL";
        ExcludedTables[19] := Database::"Agent Cue_TSA_TSL";

        // Check if the table is in the excluded list
        for i := 1 to ArrayLen(ExcludedTables) do begin
            if ExcludedTables[i] = TableId then
                exit(true);
        end;

        exit(false);
    end;

    local procedure Time2Seconds(TimeValue: Time): Integer
    begin
        // Convert time to seconds since midnight
        exit((TimeValue - 000000T) div 1000);
    end;
}
