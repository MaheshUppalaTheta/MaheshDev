page 50005 "Data Debugger Table Filters"
{
    Caption = 'Data Debugger Table Filters';
    PageType = List;
    SourceTable = "Data Debugger Table Filter";
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Filters)
            {
                field("Table ID"; Rec."Table ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'The ID of the table to filter';
                }

                field("Table Name"; Rec."Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The name of the table';
                }

                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Whether this filter rule is active';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SelectFields)
            {
                Caption = 'Select Fields';
                ToolTip = 'Pick which fields of this table to capture. Leave none selected to capture all fields. Re-opening shows your current selection so you can add or remove fields.';
                Image = SelectField;

                trigger OnAction()
                var
                    FieldSelection: Page "DD Field Selection";
                begin
                    if Rec."Table ID" = 0 then begin
                        Message('Enter a Table ID first, then pick its fields.');
                        exit;
                    end;
                    FieldSelection.SetTableId(Rec."Table ID");
                    FieldSelection.RunModal();
                end;
            }
            action(AddSystemTables)
            {
                Caption = 'Add Common System Tables';
                ToolTip = 'Add commonly noisy system tables to this list. Useful with the "All Except Selected Tables" capture scope to keep them out of recordings.';
                Image = AddWatch;

                trigger OnAction()
                begin
                    AddCommonSystemTables();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(SelectFields_Promoted; SelectFields) { }
                actionref(AddSystemTables_Promoted; AddSystemTables) { }
            }
        }
    }

    local procedure AddCommonSystemTables()
    var
        TableFilter: Record "Data Debugger Table Filter";
        SystemTables: array[10] of Integer;
        i: Integer;
    begin
        // Initialize common system tables to exclude
        SystemTables[1] := 497;  // Change Log Entry
        SystemTables[2] := 498;  // Change Log Setup
        SystemTables[3] := 2000000053; // Change Log Entry (Archive)
        SystemTables[4] := 2000000110; // Activity Log
        SystemTables[5] := 2000000112; // Delete Log
        SystemTables[6] := 2000000001; // Session Event
        SystemTables[7] := 2000000168; // System Change Log
        SystemTables[8] := 2000000111; // User Session Log
        SystemTables[9] := 2000000067; // Scheduled Task
        SystemTables[10] := 50000; // Data Debugger Change Buffer

        for i := 1 to ArrayLen(SystemTables) do begin
            if SystemTables[i] <> 0 then begin
                TableFilter.Reset();
                TableFilter.SetRange("Table ID", SystemTables[i]);
                if not TableFilter.FindFirst() then begin
                    TableFilter.Init();
                    TableFilter."Table ID" := SystemTables[i];
                    TableFilter.Enabled := true;
                    TableFilter.Insert(true);
                end;
            end;
        end;

        Message('Common system tables added to exclusion list.');
        CurrPage.Update();
    end;
}
