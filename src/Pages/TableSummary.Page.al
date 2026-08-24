page 72930453 "Table Summary_TSA_TSL"
{
    Caption = 'Changes by Table';
    PageType = List;
    SourceTable = "Name/Value Buffer";
    SourceTableTemporary = true;
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Tables)
            {
                field(Name; Rec.Name)
                {
                    Caption = 'Table Name';
                    ApplicationArea = All;
                }

                field(Value; Rec.Value)
                {
                    Caption = 'Total Changes';
                    ApplicationArea = All;
                }

                field("Value Long"; Rec."Value Long")
                {
                    Caption = 'Change Types';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewTableChanges)
            {
                Caption = 'View Changes';
                ToolTip = 'View all changes for this table';
                Image = ViewDetails;

                trigger OnAction()
                var
                    FilteredResultsPage: Page "Results_TSA_TSL";
                    TempFilteredBuffer: Record "Change Buffer_TSA_TSL" temporary;
                begin
                    // Filter original data by selected table
                    OriginalData.Reset();
                    OriginalData.SetRange("Table Name", Rec.Name);

                    if OriginalData.FindSet() then
                        repeat
                            TempFilteredBuffer := OriginalData;
                            TempFilteredBuffer.Insert();
                        until OriginalData.Next() = 0;

                    FilteredResultsPage.SetData(TempFilteredBuffer, CurrentRunId, 0DT);
                    FilteredResultsPage.RunModal();
                end;
            }
        }
    }

    var
        OriginalData: Record "Change Buffer_TSA_TSL" temporary;
        CurrentRunId: Guid;

    procedure SetData(var ChangeBuffer: Record "Change Buffer_TSA_TSL"; RunId: Guid)
    begin
        OriginalData.Copy(ChangeBuffer, true);
        CurrentRunId := RunId;

        BuildTableSummary();

        if Rec.FindFirst() then;
    end;

    local procedure BuildTableSummary()
    var
        TempSummary: Record "Name/Value Buffer" temporary;
        TableName: Text;
        ChangeCount: Integer;
        ChangeTypes: Text;
    begin
        Rec.Reset();
        Rec.DeleteAll();

        OriginalData.Reset();
        OriginalData.SetCurrentKey("Run ID", "Table ID", "Change Type");

        if OriginalData.FindSet() then
            repeat
                if TableName <> OriginalData."Table Name" then begin
                    // Save previous table summary
                    if TableName <> '' then begin
                        Rec.Init();
                        Rec.ID := Rec.Count() + 1;
                        Rec.Name := CopyStr(TableName, 1, MaxStrLen(Rec.Name));
                        Rec.Value := CopyStr(Format(ChangeCount), 1, MaxStrLen(Rec.Value));
                        Rec."Value Long" := CopyStr(ChangeTypes, 1, MaxStrLen(Rec."Value Long"));
                        Rec.Insert();
                    end;

                    // Start new table
                    TableName := OriginalData."Table Name";
                    ChangeCount := 0;
                    ChangeTypes := '';
                end;

                ChangeCount += 1;
                if StrPos(ChangeTypes, Format(OriginalData."Change Type")) = 0 then begin
                    if ChangeTypes <> '' then
                        ChangeTypes += ', ';
                    ChangeTypes += Format(OriginalData."Change Type");
                end;
            until OriginalData.Next() = 0;

        // Add final table
        if TableName <> '' then begin
            Rec.Init();
            Rec.ID := Rec.Count() + 1;
            Rec.Name := CopyStr(TableName, 1, MaxStrLen(Rec.Name));
            Rec.Value := CopyStr(Format(ChangeCount), 1, MaxStrLen(Rec.Value));
            Rec."Value Long" := CopyStr(ChangeTypes, 1, MaxStrLen(Rec."Value Long"));
            Rec.Insert();
        end;
    end;
}