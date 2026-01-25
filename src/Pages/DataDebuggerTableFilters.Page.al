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

                field("Filter Type"; Rec."Filter Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Whether to include or exclude this table';
                }

                field("Field Filters"; Rec."Field Filters")
                {
                    ApplicationArea = All;
                    ToolTip = 'Comma-separated list of field names to include/exclude (leave blank for all fields)';
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
            action(AddSystemTables)
            {
                Caption = 'Add Common System Tables';
                ToolTip = 'Add commonly excluded system tables';
                Image = AddWatch;

                trigger OnAction()
                begin
                    AddCommonSystemTables();
                end;
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
                    TableFilter."Filter Type" := TableFilter."Filter Type"::Exclude;
                    TableFilter.Enabled := true;
                    TableFilter.Insert(true);
                end;
            end;
        end;

        Message('Common system tables added to exclusion list.');
        CurrPage.Update();
    end;
}
