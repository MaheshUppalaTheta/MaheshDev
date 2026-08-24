page 72930457 "Transactions_TSA_TSL"
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
                    ToolTip = 'The unique identifier of the database transaction that grouped these changes.';
                }

                field(Value; Rec.Value)
                {
                    Caption = 'Time Range';
                    ApplicationArea = All;
                    ToolTip = 'The time range covered by changes in this transaction.';
                }

                field("Value Long"; Rec."Value Long")
                {
                    Caption = 'Changes / First User';
                    ApplicationArea = All;
                    ToolTip = 'Number of changes and the first user who made a change in this transaction.';
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
                    FilteredResultsPage: Page "Results_TSA_TSL";
                    TempFilteredBuffer: Record "Change Buffer_TSA_TSL" temporary;
                    SourceBuffer: Record "Change Buffer_TSA_TSL";
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

    procedure SetData(var SourceBuffer: Record "Change Buffer_TSA_TSL"; RunId: Guid)
    var
        TransactionBuffer: Record "Change Buffer_TSA_TSL";
        InnerBuffer: Record "Change Buffer_TSA_TSL";
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

                        InnerBuffer.SetRange("Run ID", RunId);
                        InnerBuffer.SetRange("Transaction ID", TransactionId);
                        if InnerBuffer.FindSet() then begin
                            repeat
                                ChangeCount += 1;
                                if FirstUser = '' then
                                    FirstUser := InnerBuffer."User Name";
                                if (MinTime = 0DT) or (InnerBuffer.Timestamp1 < MinTime) then
                                    MinTime := InnerBuffer.Timestamp1;
                                if (MaxTime = 0DT) or (InnerBuffer.Timestamp1 > MaxTime) then
                                    MaxTime := InnerBuffer.Timestamp1;
                            until InnerBuffer.Next() = 0;
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
                        Rec.Value := CopyStr(TimeRange, 1, MaxStrLen(Rec.Value));
                        Rec."Value Long" := CopyStr(Format(ChangeCount) + ' / ' + FirstUser, 1, MaxStrLen(Rec."Value Long"));
                        Rec.Insert();
                    end;
                end;
            until TransactionBuffer.Next() = 0;
        end;

        if Rec.FindFirst() then;
    end;
}
