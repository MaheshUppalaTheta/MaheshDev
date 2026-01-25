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

                field("Enable Table Filtering"; Rec."Enable Table Filtering")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable custom table include/exclude filtering';
                }

                field("Table Filter Mode"; Rec."Table Filter Mode")
                {
                    ApplicationArea = All;
                    ToolTip = 'Include Only: Capture only tables marked as Include. Exclude Only: Capture all tables except those marked as Exclude.';
                    Enabled = Rec."Enable Table Filtering";
                }
            }

            group(FieldFiltering)
            {
                Caption = 'Field Filtering';

                field("Enable Field Filtering"; Rec."Enable Field Filtering")
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable field-level filtering for captured data';
                }
            }

            group(ChangeThreshold)
            {
                Caption = 'Change Threshold';

                field("Enable Change Threshold"; Rec."Enable Change Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Only capture modifications that change a minimum number of fields';
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
