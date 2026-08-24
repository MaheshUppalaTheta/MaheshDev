codeunit 72930454 "Analysis Engine_TSA_TSL"
{
    procedure AnalyzeChanges(var ChangeBuffer: Record "Change Buffer_TSA_TSL"; var AnalysisBuffer: Record "Analysis Buffer_TSA_TSL")
    begin
        AnalysisBuffer.Reset();
        AnalysisBuffer.DeleteAll();

        PerformImpactAnalysis(ChangeBuffer, AnalysisBuffer);
        PerformPerformanceAnalysis(ChangeBuffer, AnalysisBuffer);
        PerformPatternDetection(ChangeBuffer, AnalysisBuffer);
        PerformRelationshipMapping(ChangeBuffer, AnalysisBuffer);
        PerformTableTypeAnalysis(ChangeBuffer, AnalysisBuffer);
    end;

    local procedure PerformImpactAnalysis(var ChangeBuffer: Record "Change Buffer_TSA_TSL"; var AnalysisBuffer: Record "Analysis Buffer_TSA_TSL")
    var
        TableStats: Dictionary of [Integer, Integer];
        UserStats: Dictionary of [Text, Integer];
        TransactionStats: Dictionary of [Guid, Integer];
        TableId: Integer;
        UserName: Text;
        TransactionId: Guid;
        ChangeCount: Integer;
        EntryNo: Integer;
    begin
        EntryNo := AnalysisBuffer.Count();

        // Analyze table impact
        ChangeBuffer.Reset();
        if ChangeBuffer.FindSet() then begin
            repeat
                TableId := ChangeBuffer."Table ID";
                if TableStats.ContainsKey(TableId) then
                    TableStats.Set(TableId, TableStats.Get(TableId) + 1)
                else
                    TableStats.Add(TableId, 1);

                UserName := ChangeBuffer."User Name";
                if UserName <> '' then begin
                    if UserStats.ContainsKey(UserName) then
                        UserStats.Set(UserName, UserStats.Get(UserName) + 1)
                    else
                        UserStats.Add(UserName, 1);
                end;

                TransactionId := ChangeBuffer."Transaction ID";
                if not IsNullGuid(TransactionId) then begin
                    if TransactionStats.ContainsKey(TransactionId) then
                        TransactionStats.Set(TransactionId, TransactionStats.Get(TransactionId) + 1)
                    else
                        TransactionStats.Add(TransactionId, 1);
                end;
            until ChangeBuffer.Next() = 0;
        end;

        // Add table impact results
        foreach TableId in TableStats.Keys() do begin
            ChangeCount := TableStats.Get(TableId);
            EntryNo += 1;
            AnalysisBuffer.Init();
            AnalysisBuffer."Entry No." := EntryNo;
            AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Impact Analysis";
            AnalysisBuffer."Category" := 'Table Impact';
            AnalysisBuffer."Related Table ID" := TableId;
            AnalysisBuffer."Related Table Name" := GetTableName(TableId);
            AnalysisBuffer."Value" := ChangeCount;
            AnalysisBuffer."Value Text" := Format(ChangeCount) + ' changes';
            AnalysisBuffer."Description" := StrSubstNo('Table %1 had %2 changes', AnalysisBuffer."Related Table Name", ChangeCount);

            if ChangeCount > 100 then
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Critical
            else if ChangeCount > 20 then
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Warning
            else
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;

            AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();
            AnalysisBuffer.Insert();
        end;

        // Add user impact results
        foreach UserName in UserStats.Keys() do begin
            ChangeCount := UserStats.Get(UserName);
            EntryNo += 1;
            AnalysisBuffer.Init();
            AnalysisBuffer."Entry No." := EntryNo;
            AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Impact Analysis";
            AnalysisBuffer."Category" := 'User Impact';
            AnalysisBuffer."Value" := ChangeCount;
            AnalysisBuffer."Value Text" := UserName;
            AnalysisBuffer."Description" := StrSubstNo('User %1 made %2 changes', UserName, ChangeCount);

            if ChangeCount > 50 then
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Warning
            else
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;

            AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();
            AnalysisBuffer.Insert();
        end;
    end;

    local procedure PerformPerformanceAnalysis(var ChangeBuffer: Record "Change Buffer_TSA_TSL"; var AnalysisBuffer: Record "Analysis Buffer_TSA_TSL")
    var
        PrevTimestamp: DateTime;
        CurrentTimestamp: DateTime;
        TimeDiff: Duration;
        TotalDuration: Duration;
        ChangeCount: Integer;
        MaxGap: Duration;
        MinGap: Duration;
        AvgChangesPerSecond: Decimal;
        EntryNo: Integer;
    begin
        EntryNo := AnalysisBuffer.Count();

        ChangeBuffer.Reset();
        ChangeBuffer.SetCurrentKey("Run ID", Timestamp1);
        if ChangeBuffer.FindSet() then begin
            PrevTimestamp := ChangeBuffer.Timestamp1;
            MinGap := 999999999; // Large initial value

            repeat
                ChangeCount += 1;
                CurrentTimestamp := ChangeBuffer.Timestamp1;

                if ChangeCount > 1 then begin
                    TimeDiff := CurrentTimestamp - PrevTimestamp;
                    if TimeDiff > MaxGap then
                        MaxGap := TimeDiff;
                    if TimeDiff < MinGap then
                        MinGap := TimeDiff;
                end;

                PrevTimestamp := CurrentTimestamp;
            until ChangeBuffer.Next() = 0;
        end;

        if ChangeCount > 1 then begin
            ChangeBuffer.FindFirst();
            TotalDuration := PrevTimestamp - ChangeBuffer.Timestamp1;

            if TotalDuration > 0 then
                AvgChangesPerSecond := ChangeCount / (TotalDuration / 1000);

            // Add performance metrics
            EntryNo += 1;
            AnalysisBuffer.Init();
            AnalysisBuffer."Entry No." := EntryNo;
            AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Performance Metric";
            AnalysisBuffer."Category" := 'Change Rate';
            AnalysisBuffer."Value" := AvgChangesPerSecond;
            AnalysisBuffer."Value Text" := Format(AvgChangesPerSecond, 0, '<Precision,2:2>') + ' changes/sec';
            AnalysisBuffer."Description" := 'Average changes per second during recording';
            AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;
            AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();
            AnalysisBuffer.Insert();

            EntryNo += 1;
            AnalysisBuffer.Init();
            AnalysisBuffer."Entry No." := EntryNo;
            AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Performance Metric";
            AnalysisBuffer."Category" := 'Max Gap';
            AnalysisBuffer."Value" := MaxGap / 1000; // Convert to seconds
            AnalysisBuffer."Value Text" := FormatDuration(MaxGap);
            AnalysisBuffer."Description" := 'Longest time between consecutive changes';

            if (MaxGap / 1000) > 60 then
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Warning
            else
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;

            AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();
            AnalysisBuffer.Insert();
        end;
    end;

    local procedure PerformPatternDetection(var ChangeBuffer: Record "Change Buffer_TSA_TSL"; var AnalysisBuffer: Record "Analysis Buffer_TSA_TSL")
    var
        TableChangeTypes: Dictionary of [Text, Integer];
        PatternKey: Text;
        PatternCount: Integer;
        EntryNo: Integer;
        BurstCount: Integer;
        PrevTimestamp: DateTime;
        TimeDiff: Duration;
        InBurst: Boolean;
    begin
        EntryNo := AnalysisBuffer.Count();

        // Detect change type patterns per table
        ChangeBuffer.Reset();
        if ChangeBuffer.FindSet() then begin
            repeat
                PatternKey := StrSubstNo('%1_%2', ChangeBuffer."Table Name", Format(ChangeBuffer."Change Type"));
                if TableChangeTypes.ContainsKey(PatternKey) then
                    TableChangeTypes.Set(PatternKey, TableChangeTypes.Get(PatternKey) + 1)
                else
                    TableChangeTypes.Add(PatternKey, 1);
            until ChangeBuffer.Next() = 0;
        end;

        // Report unusual patterns
        foreach PatternKey in TableChangeTypes.Keys() do begin
            PatternCount := TableChangeTypes.Get(PatternKey);

            if PatternCount > 50 then begin
                EntryNo += 1;
                AnalysisBuffer.Init();
                AnalysisBuffer."Entry No." := EntryNo;
                AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Pattern Detection";
                AnalysisBuffer."Category" := 'High Volume Pattern';
                AnalysisBuffer."Value" := PatternCount;
                AnalysisBuffer."Value Text" := PatternKey;
                AnalysisBuffer."Description" := StrSubstNo('High volume detected: %1 (%2 occurrences)', PatternKey, PatternCount);

                if PatternCount > 200 then
                    AnalysisBuffer.Severity := AnalysisBuffer.Severity::Critical
                else
                    AnalysisBuffer.Severity := AnalysisBuffer.Severity::Warning;

                AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();
                AnalysisBuffer.Insert();
            end;
        end;

        // Detect burst patterns (rapid successive changes)
        ChangeBuffer.Reset();
        ChangeBuffer.SetCurrentKey("Run ID", Timestamp1);
        if ChangeBuffer.FindSet() then begin
            PrevTimestamp := ChangeBuffer.Timestamp1;
            BurstCount := 1;
            InBurst := false;

            while ChangeBuffer.Next() <> 0 do begin
                TimeDiff := ChangeBuffer.Timestamp1 - PrevTimestamp;

                if TimeDiff < 1000 then begin // Less than 1 second
                    BurstCount += 1;
                    InBurst := true;
                end else begin
                    if InBurst and (BurstCount >= 10) then begin
                        EntryNo += 1;
                        AnalysisBuffer.Init();
                        AnalysisBuffer."Entry No." := EntryNo;
                        AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Pattern Detection";
                        AnalysisBuffer."Category" := 'Burst Pattern';
                        AnalysisBuffer."Value" := BurstCount;
                        AnalysisBuffer."Value Text" := Format(BurstCount) + ' rapid changes';
                        AnalysisBuffer."Description" := StrSubstNo('Burst of %1 rapid changes detected', BurstCount);
                        AnalysisBuffer.Severity := AnalysisBuffer.Severity::Warning;
                        AnalysisBuffer."Analysis Timestamp" := PrevTimestamp;
                        AnalysisBuffer.Insert();
                    end;
                    BurstCount := 1;
                    InBurst := false;
                end;

                PrevTimestamp := ChangeBuffer.Timestamp1;
            end;
        end;
    end;

    local procedure PerformRelationshipMapping(var ChangeBuffer: Record "Change Buffer_TSA_TSL"; var AnalysisBuffer: Record "Analysis Buffer_TSA_TSL")
    var
        TransactionTables: Dictionary of [Guid, List of [Integer]];
        TransactionId: Guid;
        TableList: List of [Integer];
        TableId: Integer;
        EntryNo: Integer;
        RelationshipDetails: TextBuilder;
    begin
        EntryNo := AnalysisBuffer.Count();

        // Group tables by transaction to identify relationships
        ChangeBuffer.Reset();
        if ChangeBuffer.FindSet() then begin
            repeat
                TransactionId := ChangeBuffer."Transaction ID";
                if not IsNullGuid(TransactionId) then begin
                    TableId := ChangeBuffer."Table ID";

                    if TransactionTables.ContainsKey(TransactionId) then
                        TableList := TransactionTables.Get(TransactionId)
                    else
                        Clear(TableList);

                    if not TableList.Contains(TableId) then begin
                        TableList.Add(TableId);
                        TransactionTables.Set(TransactionId, TableList);
                    end;
                end;
            until ChangeBuffer.Next() = 0;
        end;

        // Report multi-table transactions as relationships
        foreach TransactionId in TransactionTables.Keys() do begin
            TableList := TransactionTables.Get(TransactionId);

            if TableList.Count() > 1 then begin
                RelationshipDetails.Clear();
                foreach TableId in TableList do begin
                    if RelationshipDetails.Length() > 0 then
                        RelationshipDetails.Append(' → ');
                    RelationshipDetails.Append(GetTableName(TableId));
                end;

                EntryNo += 1;
                AnalysisBuffer.Init();
                AnalysisBuffer."Entry No." := EntryNo;
                AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Relationship Mapping";
                AnalysisBuffer."Category" := 'Transaction Relationship';
                AnalysisBuffer."Value" := TableList.Count();
                AnalysisBuffer."Value Text" := Format(TableList.Count()) + ' tables';
                AnalysisBuffer."Description" := StrSubstNo('Transaction involves %1 related tables', TableList.Count());
                AnalysisBuffer.SetDetails(RelationshipDetails.ToText());
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;
                AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();
                AnalysisBuffer.Insert();
            end;
        end;
    end;

    local procedure GetTableName(TableId: Integer): Text
    var
        TableMetadata: Record "Table Metadata";
    begin
        if TableMetadata.Get(TableId) then
            exit(TableMetadata.Name);
        exit(Format(TableId));
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

    local procedure PerformTableTypeAnalysis(var ChangeBuffer: Record "Change Buffer_TSA_TSL"; var AnalysisBuffer: Record "Analysis Buffer_TSA_TSL")
    var
        TempTableCount: Integer;
        RealTableCount: Integer;
        TotalCount: Integer;
        TempTablePercentage: Decimal;
        RealTablePercentage: Decimal;
        EntryNo: Integer;
        TempTableIds: Dictionary of [Integer, Integer];
        RealTableIds: Dictionary of [Integer, Integer];
        TableId: Integer;
        TempCount: Integer;
        RealCount: Integer;
        Keys: List of [Integer];
        TempTableId: Integer;
    begin
        EntryNo := AnalysisBuffer.Count();
        TempTableCount := 0;
        RealTableCount := 0;

        // Count temporary vs real table operations
        ChangeBuffer.Reset();
        if ChangeBuffer.FindSet() then begin
            repeat
                TableId := ChangeBuffer."Table ID";

                if ChangeBuffer."Is Temporary Table" then begin
                    TempTableCount += 1;
                    if TempTableIds.ContainsKey(TableId) then
                        TempTableIds.Set(TableId, TempTableIds.Get(TableId) + 1)
                    else
                        TempTableIds.Add(TableId, 1);
                end else begin
                    RealTableCount += 1;
                    if RealTableIds.ContainsKey(TableId) then
                        RealTableIds.Set(TableId, RealTableIds.Get(TableId) + 1)
                    else
                        RealTableIds.Add(TableId, 1);
                end;
            until ChangeBuffer.Next() = 0;
        end;

        TotalCount := TempTableCount + RealTableCount;

        if TotalCount > 0 then begin
            TempTablePercentage := Round((TempTableCount * 100.0) / TotalCount, 0.1);
            RealTablePercentage := Round((RealTableCount * 100.0) / TotalCount, 0.1);

            // Overall distribution analysis
            EntryNo += 1;
            AnalysisBuffer.Init();
            AnalysisBuffer."Entry No." := EntryNo;
            AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Impact Analysis";
            AnalysisBuffer.Category := 'Table Type Distribution';
            AnalysisBuffer.Description := 'Distribution of changes between temporary and real tables';
            AnalysisBuffer."Value Text" := StrSubstNo('Temp: %1%% (%2), Real: %3%% (%4)',
                TempTablePercentage, TempTableCount, RealTablePercentage, RealTableCount);
            AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();

            if TempTablePercentage > 70 then begin
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Warning;
                AnalysisBuffer.SetDetails('High percentage of temporary table operations detected. ' +
                    'This might indicate heavy use of temporary processing or potential performance optimization opportunities.');
            end else if RealTablePercentage > 90 then begin
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;
                AnalysisBuffer.SetDetails('Primarily real table operations. This indicates direct database modifications ' +
                    'with minimal temporary processing.');
            end else begin
                AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;
                AnalysisBuffer.SetDetails('Balanced mix of temporary and real table operations.');
            end;
            AnalysisBuffer.Insert();

            // Most active temporary tables
            if TempTableIds.Count() > 0 then begin
                Keys := TempTableIds.Keys();
                foreach TempTableId in Keys do begin
                    TempCount := TempTableIds.Get(TempTableId);
                    if TempCount > 10 then begin // Only report tables with significant activity
                        EntryNo += 1;
                        AnalysisBuffer.Init();
                        AnalysisBuffer."Entry No." := EntryNo;
                        AnalysisBuffer."Analysis Type" := AnalysisBuffer."Analysis Type"::"Pattern Detection";
                        AnalysisBuffer.Category := 'High Temp Table Activity';
                        AnalysisBuffer.Description := StrSubstNo('High activity on temporary table %1', TempTableId);
                        AnalysisBuffer."Value Text" := Format(TempCount) + ' changes';
                        AnalysisBuffer."Related Table ID" := TempTableId;
                        AnalysisBuffer."Analysis Timestamp" := CurrentDateTime();

                        if TempCount > 50 then
                            AnalysisBuffer.Severity := AnalysisBuffer.Severity::Warning
                        else
                            AnalysisBuffer.Severity := AnalysisBuffer.Severity::Info;

                        AnalysisBuffer.SetDetails('Temporary table showing high change volume. ' +
                            'Consider reviewing the business logic for optimization opportunities.');
                        AnalysisBuffer.Insert();
                    end;
                end;
            end;
        end;
    end;
}
