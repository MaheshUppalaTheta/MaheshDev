page 72930461 "Agent Activities_TSA_TSL"
{
    Caption = 'Troubleshooting Assistance Activities';
    PageType = CardPart;
    SourceTable = "Agent Cue_TSA_TSL";
    Editable = false;
    ApplicationArea = All;

    // Activities part for the agent Role Center. Each cue ("queue") shows a live count and drills
    // into the Troubleshooting Assistance Changes list, mirroring the standard "Sales Order Activities" pattern.
    layout
    {
        area(Content)
        {
            cuegroup("Captured Changes")
            {
                Caption = 'Captured Changes';

                field("Total Changes"; Rec."Total Changes")
                {
                    Caption = 'All Changes';
                    ToolTip = 'Total number of captured changes. Click to open the full list.';
                    DrillDownPageId = "Change Entry Preview_TSA_TSL";
                }
                field("Error Changes"; Rec."Error Changes")
                {
                    Caption = 'Errors';
                    ToolTip = 'Captured entries of type Error. Click to open the list.';
                    DrillDownPageId = "Change Entry Preview_TSA_TSL";
                    StyleExpr = ErrorStyle;
                }
                field("Temporary Table Changes"; Rec."Temporary Table Changes")
                {
                    Caption = 'Temporary Table Changes';
                    ToolTip = 'Captured changes made on temporary tables. Click to open the list.';
                    DrillDownPageId = "Change Entry Preview_TSA_TSL";
                }
            }
        }
    }

    var
        ErrorStyle: Text;

    trigger OnOpenPage()
    begin
        Rec.InitCue();
    end;

    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Total Changes", "Error Changes", "Temporary Table Changes");
        if Rec."Error Changes" > 0 then
            ErrorStyle := 'Unfavorable'
        else
            ErrorStyle := 'Favorable';
    end;
}
