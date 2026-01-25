page 50007 "Data Debugger Transactions"
{
    Caption = 'Changes Grouped by Transaction';
    PageType = List;
    SourceTable = "Name/Value Buffer";
    SourceTableTemporary = true;
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Transactions)
            {
                field(Name; Rec.Name)
                {
                    Caption = 'Transaction ID';
                    ApplicationArea = All;
                }

                field(Value; Rec.Value)
                {
                    Caption = 'Change Count';
                    ApplicationArea = All;
                }

                field("Value Long"; Rec."Value Long")
                {
                    Caption = 'First User';
                    ApplicationArea = All;
                }

                field("Value BLOB"; TransactionTime)
                {
                    Caption = 'Time Range';
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewTransactionChanges)
            {
                Caption = 'View Changes';
                ToolTip = 'View all changes in this transaction';
                Image = ViewDetails;

                trigger OnAction()
                var
                    FilteredResultsPage: Page "Data Debugger Results";
                    TempFilteredBuffer: Record "Data Debugger Change Buffer" temporary;
                    SourceBuffer: Record "Data Debugger Change Buffer";
                    TransactionGuid: Guid;
                begin
                    if Rec.Name = '' then
                        exit;

                    if not Evaluate(TransactionGuid, Rec.Name) then
                        exit;

                    // Copy filtered data to temporary buffer
                    SourceBuffer.SetRange("Transaction ID", TransactionGuid);
                    if SourceBuffer.FindSet() then
                        repeat
                            TempFilteredBuffer := SourceBuffer;
                            TempFilteredBuffer.Insert();
                        until SourceBuffer.Next() = 0;

                    FilteredResultsPage.SetData(TempFilteredBuffer, CurrentRunId, SessionStartTime);
                    FilteredResultsPage.RunModal();
                end;
            }
        }
    }

    var
        CurrentRunId: Guid;
        SessionStartTime: DateTime;
        TransactionTime: Text;

    procedure SetData(var SourceBuffer: Record "Data Debugger Change Buffer"; RunId: Guid)
    var
        TransactionBuffer: Record "Data Debugger Change Buffer";
        TransactionId: Guid;
        ChangeCount: Integer;
        FirstUser: Text;
        MinTime: DateTime;
        MaxTime: DateTime;
        TimeRange: Text;
    begin
        CurrentRunId := RunId;

        Rec.Reset();
        Rec.DeleteAll();

        // Group by Transaction ID
        TransactionBuffer.SetRange("Run ID", RunId);
        if TransactionBuffer.FindSet() then begin
            repeat
                TransactionId := TransactionBuffer."Transaction ID";

                if not IsNullGuid(TransactionId) then begin
                    // Check if we already processed this transaction
                    Rec.SetRange(Name, Format(TransactionId));
                    if not Rec.FindFirst() then begin
                        // Count changes and get details for this transaction
                        ChangeCount := 0;
                        FirstUser := '';
                        Clear(MinTime);
                        Clear(MaxTime);

                        TransactionBuffer.SetRange("Transaction ID", TransactionId);
                        if TransactionBuffer.FindSet() then begin
                            repeat
                                ChangeCount += 1;
                                if FirstUser = '' then
                                    FirstUser := TransactionBuffer."User Name";
                                if (MinTime = 0DT) or (TransactionBuffer.Timestamp1 < MinTime) then
                                    MinTime := TransactionBuffer.Timestamp1;
                                if (MaxTime = 0DT) or (TransactionBuffer.Timestamp1 > MaxTime) then
                                    MaxTime := TransactionBuffer.Timestamp1;
                            until TransactionBuffer.Next() = 0;
                        end;

                        // Build time range string
                        if MinTime = MaxTime then
                            TimeRange := Format(MinTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>')
                        else
                            TimeRange := Format(MinTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>') + ' - ' +
                                        Format(MaxTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>');

                        // Add summary record
                        Rec.Init();
                        Rec.ID := Rec.Count() + 1;
                        Rec.Name := Format(TransactionId);
                        Rec.Value := Format(ChangeCount);
                        Rec."Value Long" := FirstUser;
                        Rec.Insert();

                        TransactionTime := TimeRange;
                    end;
                    TransactionBuffer.SetRange("Transaction ID");
                end;
            until TransactionBuffer.Next() = 0;
        end;

        if Rec.FindFirst() then;
    end;
}
