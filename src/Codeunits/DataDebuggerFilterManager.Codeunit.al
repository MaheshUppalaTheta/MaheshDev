codeunit 50002 "Data Debugger Filter Manager"
{
    SingleInstance = true;

    var
        Setup: Record "Data Debugger Setup";
        IsSetupLoaded: Boolean;
        LastCaptureTime: DateTime;
        CaptureCount: Integer;
        LastSecond: Integer;

    procedure IsTableAllowed(TableId: Integer): Boolean
    var
        TableFilter: Record "Data Debugger Table Filter";
    begin
        LoadSetup();

        // First check basic system table exclusions (always apply)
        if IsSystemTableExcluded(TableId) then
            exit(false);

        // If table filtering is not enabled, allow all non-system tables
        if not Setup."Enable Table Filtering" then
            exit(true);

        // Check if this specific table has a filter entry
        TableFilter.SetRange("Table ID", TableId);
        TableFilter.SetRange(Enabled, true);
        if TableFilter.FindFirst() then begin
            // Table is in filter list - check against mode
            case Setup."Table Filter Mode" of
                Setup."Table Filter Mode"::"Include Only":
                    exit(TableFilter."Filter Type" = TableFilter."Filter Type"::Include);
                Setup."Table Filter Mode"::"Exclude Only":
                    exit(TableFilter."Filter Type" <> TableFilter."Filter Type"::Exclude);
            end;
        end else begin
            // Table not in filter list - apply mode default
            case Setup."Table Filter Mode" of
                Setup."Table Filter Mode"::"Include Only":
                    exit(false); // Not in include list, reject
                Setup."Table Filter Mode"::"Exclude Only":
                    exit(true); // Not in exclude list, allow
            end;
        end;

        exit(true);
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
        TableFilter: Record "Data Debugger Table Filter";
        FieldList: List of [Text];
        FieldName: Text;
        Keys: List of [Text];
        KeyText: Text;
        TempJsonObj: JsonObject;
        JsonToken: JsonToken;
    begin
        LoadSetup();

        // If field filtering is not enabled, return original object
        if not Setup."Enable Field Filtering" then
            exit;

        // Get field filters for this table
        TableFilter.SetRange("Table ID", TableId);
        TableFilter.SetRange(Enabled, true);
        TableFilter.SetFilter("Field Filters", '<>%1', '');
        if not TableFilter.FindFirst() then
            exit; // No field filters defined

        // Parse field filter list
        FieldList := TableFilter."Field Filters".Split(',');

        // Filter the JSON object
        Clear(TempJsonObj);
        Keys := JsonObj.Keys();

        foreach KeyText in Keys do begin
            JsonObj.Get(KeyText, JsonToken);

            case TableFilter."Filter Type" of
                TableFilter."Filter Type"::Include:
                    begin
                        // Include only specified fields
                        foreach FieldName in FieldList do begin
                            if KeyText.ToLower() = DelChr(FieldName.ToLower(), '<>', ' ') then begin
                                TempJsonObj.Add(KeyText, JsonToken);
                                break;
                            end;
                        end;
                    end;
                TableFilter."Filter Type"::Exclude:
                    begin
                        // Exclude specified fields
                        if not IsFieldInList(KeyText, FieldList) then
                            TempJsonObj.Add(KeyText, JsonToken);
                    end;
            end;
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

    local procedure LoadSetup()
    begin
        if not IsSetupLoaded then begin
            Setup := Setup.GetSetup();
            IsSetupLoaded := true;
        end;
    end;

    local procedure IsSystemTableExcluded(TableId: Integer): Boolean
    var
        ExcludedTables: array[15] of Integer;
        i: Integer;
    begin
        // Exclude system tables (TableId < 50000 for custom objects)
        // if TableId < 50000 then
        //     exit(true);

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

        // Exclude Data Debugger's own tables to prevent recursive recording
        ExcludedTables[11] := Database::"Data Debugger Change Buffer";
        ExcludedTables[12] := Database::"Data Debugger Setup";
        ExcludedTables[13] := Database::"Data Debugger Table Filter";
        ExcludedTables[14] := Database::"Data Debugger Live Stats";
        ExcludedTables[15] := Database::"Data Debugger Analysis Buffer";

        // Check if the table is in the excluded list
        for i := 1 to ArrayLen(ExcludedTables) do begin
            if ExcludedTables[i] = TableId then
                exit(true);
        end;

        exit(false);
    end;

    local procedure IsFieldInList(FieldName: Text; FieldList: List of [Text]): Boolean
    var
        Field: Text;
    begin
        foreach Field in FieldList do begin
            if FieldName.ToLower() = DelChr(Field.ToLower(), '<>', ' ') then
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
