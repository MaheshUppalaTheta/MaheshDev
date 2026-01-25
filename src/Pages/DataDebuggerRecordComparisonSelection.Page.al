page 50013 "DD Record Comparison Selection"
{
    Caption = 'Select Record for Comparison';
    PageType = List;
    SourceTable = "Data Debugger Change Buffer";
    Editable = false;
    UsageCategory = None;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entry number of the change record';
                }

                field(Timestamp1; Rec.Timestamp1)
                {
                    ApplicationArea = All;
                    ToolTip = 'When the change occurred';
                }

                field("Table Name"; Rec."Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the table that was changed';
                }

                field("Change Type"; Rec."Change Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Type of change that occurred';
                    Style = Attention;
                    StyleExpr = Rec."Change Type" <> Rec."Change Type"::Modify;
                }

                field("Primary Key"; Rec."Primary Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Primary key of the changed record';
                }

                field("User Name"; Rec."User Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'User who made the change';
                }

                field("Session ID"; Rec."Session ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Session ID where the change occurred';
                }

                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Company where the change occurred';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Select)
            {
                Caption = 'Select Record';
                ToolTip = 'Select this record for comparison';
                Image = SelectEntries;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    CurrPage.Close();
                end;
            }

            action(ViewDetails)
            {
                Caption = 'View Change Details';
                ToolTip = 'View detailed change information for this record';
                Image = ViewDetails;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    ShowChangeDetails();
                end;
            }

            action(CompareRecord)
            {
                Caption = 'Compare This Record';
                ToolTip = 'Open comparison view for this record';
                Image = View;
                ApplicationArea = All;

                trigger OnAction()
                var
                    RecordComparisonPage: Page "DD Record Comparison";
                begin
                    RecordComparisonPage.SetComparisonRecord(Rec);
                    RecordComparisonPage.Run();
                end;
            }
        }

        area(Navigation)
        {
            action(FilterByTable)
            {
                Caption = 'Filter by Table';
                ToolTip = 'Filter records by the current table';
                Image = FilterLines;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Rec.SetRange("Table ID", Rec."Table ID");
                    CurrPage.Update(false);
                end;
            }

            action(FilterByUser)
            {
                Caption = 'Filter by User';
                ToolTip = 'Filter records by the current user';
                Image = User;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Rec.SetRange("User ID", Rec."User ID");
                    CurrPage.Update(false);
                end;
            }

            action(ClearFilters)
            {
                Caption = 'Clear Filters';
                ToolTip = 'Clear all applied filters';
                Image = ClearFilter;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    Rec.Reset();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        // Set default sorting by timestamp descending
        Rec.SetCurrentKey("Run ID", Timestamp1);
        Rec.Ascending(false);
    end;

    local procedure ShowChangeDetails()
    var
        DetailsText: TextBuilder;
        OldData: Text;
        NewData: Text;
        CallStack: Text;
    begin
        // Ensure BLOB fields are loaded
        Rec.CalcFields("Old Data", "New Data", "Call Stack");

        OldData := Rec.GetOldData();
        NewData := Rec.GetNewData();
        CallStack := Rec.GetCallStack();

        DetailsText.AppendLine('CHANGE RECORD DETAILS');
        DetailsText.AppendLine('====================');
        DetailsText.AppendLine('');
        DetailsText.AppendLine(StrSubstNo('Entry No: %1', Rec."Entry No."));
        DetailsText.AppendLine(StrSubstNo('Timestamp: %1', Format(Rec.Timestamp1, 0, '<Day,2>-<Month,2>-<Year4> <Hours24,2>:<Minutes,2>:<Seconds,2>')));
        DetailsText.AppendLine(StrSubstNo('Table: %1 (ID: %2)', Rec."Table Name", Rec."Table ID"));
        DetailsText.AppendLine(StrSubstNo('Change Type: %1', Format(Rec."Change Type")));
        DetailsText.AppendLine(StrSubstNo('Primary Key: %1', Rec."Primary Key"));
        DetailsText.AppendLine(StrSubstNo('User: %1 (%2)', Rec."User Name", Rec."User ID"));
        DetailsText.AppendLine(StrSubstNo('Session: %1', Rec."Session ID"));
        DetailsText.AppendLine(StrSubstNo('Company: %1', Rec."Company Name"));
        DetailsText.AppendLine(StrSubstNo('Client Type: %1', Rec."Client Type"));
        DetailsText.AppendLine(StrSubstNo('Is Temporary: %1', Rec."Is Temporary Table"));
        DetailsText.AppendLine('');

        if OldData <> '' then begin
            DetailsText.AppendLine('OLD DATA:');
            DetailsText.AppendLine('---------');
            if StrLen(OldData) > 500 then begin
                DetailsText.AppendLine(CopyStr(OldData, 1, 500));
                DetailsText.AppendLine('... (truncated)');
            end else
                DetailsText.AppendLine(OldData);
            DetailsText.AppendLine('');
        end;

        if NewData <> '' then begin
            DetailsText.AppendLine('NEW DATA:');
            DetailsText.AppendLine('---------');
            if StrLen(NewData) > 500 then begin
                DetailsText.AppendLine(CopyStr(NewData, 1, 500));
                DetailsText.AppendLine('... (truncated)');
            end else
                DetailsText.AppendLine(NewData);
            DetailsText.AppendLine('');
        end;

        if CallStack <> '' then begin
            DetailsText.AppendLine('CALL STACK:');
            DetailsText.AppendLine('-----------');
            if StrLen(CallStack) > 1000 then begin
                DetailsText.AppendLine(CopyStr(CallStack, 1, 1000));
                DetailsText.AppendLine('... (truncated)');
            end else
                DetailsText.AppendLine(CallStack);
        end;

        Message(DetailsText.ToText());
    end;

    procedure SetSourceTable(var SourceChangeBuffer: Record "Data Debugger Change Buffer")
    begin
        // Copy source data to current table
        Rec.Reset();
        Rec.DeleteAll();

        SourceChangeBuffer.Reset();
        if SourceChangeBuffer.FindSet() then
            repeat
                Rec := SourceChangeBuffer;
                Rec.Insert();
            until SourceChangeBuffer.Next() = 0;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    procedure GetSelectedRecord(var SelectedRecord: Record "Data Debugger Change Buffer")
    begin
        SelectedRecord := Rec;
    end;
}
