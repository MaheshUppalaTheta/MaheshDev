page 50004 "Data Debugger Setup"
{
    Caption = 'Data Debugger Setup';
    PageType = Card;
    SourceTable = "Data Debugger Setup";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(TableFiltering)
            {
                Caption = 'Table Filtering';

                field("Table Capture Scope"; Rec."Table Capture Scope")
                {
                    ApplicationArea = All;
                    ToolTip = 'Choose what to capture. All Tables: everything. Only Selected Tables: only the tables in Table Filters (whitelist). All Except Selected Tables: everything except the tables in Table Filters (blacklist).';

                    trigger OnValidate()
                    var
                        TableFilterPage: Page "Data Debugger Table Filters";
                    begin
                        // A whitelist/blacklist scope needs a configured table list, so jump straight
                        // to Table Filters. "All Tables" needs no list. Existing rows are kept either way.
                        if Rec."Table Capture Scope" in [Rec."Table Capture Scope"::"Only Selected Tables",
                                                         Rec."Table Capture Scope"::"All Except Selected Tables"] then begin
                            CurrPage.SaveRecord();
                            // Commit the saved scope so the write lock is released: RunModal (opening the
                            // Table Filters page) is not allowed while a write transaction is open.
                            Commit();
                            TableFilterPage.RunModal();
                        end;
                    end;
                }

                field("Direct Database Capture"; Rec."Direct Database Capture")
                {
                    ApplicationArea = All;
                    ToolTip = 'Off (default): changes are buffered in memory and survive a process error/rollback; results are written when you Stop Recording (records your OWN current session). On: changes are written directly to the table (supports recording another user) but roll back if the recorded process errors.';
                }
            }

            group(ChangeThreshold)
            {
                Caption = 'Change Threshold';

                field("Enable Change Threshold"; Rec."Enable Change Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Disabled: change-threshold filtering is not currently supported and is locked off to prevent capture errors during modifications.';
                    Editable = false;
                }

                field("Min Field Changes Required"; Rec."Min Field Changes Required")
                {
                    ApplicationArea = All;
                    ToolTip = 'Minimum number of field changes required to capture a modification';
                    Enabled = Rec."Enable Change Threshold";
                }
            }

            group(Performance)
            {
                Caption = 'Performance Settings';

                field("Max Records Per Session"; Rec."Max Records Per Session")
                {
                    ApplicationArea = All;
                    ToolTip = 'Maximum number of records to capture in a single session';
                }

                field("Enable Performance Throttling"; Rec."Enable Performance Throttling")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable throttling to limit capture rate during high-volume operations';
                }

                field("Max Captures Per Second"; Rec."Max Captures Per Second")
                {
                    ApplicationArea = All;
                    ToolTip = 'Maximum number of captures per second when throttling is enabled';
                    Enabled = Rec."Enable Performance Throttling";
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TableFilters)
            {
                Caption = 'Table Filters';
                ToolTip = 'Configure which tables to include or exclude';
                Image = FilterLines;

                trigger OnAction()
                var
                    TableFilterPage: Page "Data Debugger Table Filters";
                begin
                    TableFilterPage.RunModal();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get('') then begin
            Rec := Rec.GetSetup();
            Rec.Modify();
        end;
    end;
}
