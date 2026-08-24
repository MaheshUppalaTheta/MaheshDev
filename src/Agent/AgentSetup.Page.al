page 50013 "DD Agent Setup"
{
    PageType = ConfigurationDialog;
    Extensible = false;
    Caption = 'Data Debugger Agent Setup';
    SourceTable = "DD Agent Cue";
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Info)
            {
                Caption = 'Data Debugger Agent';
                InstructionalText = 'This agent reviews the database changes captured by the Data Debugger and diagnoses why a process failed. It reads the Data Debugger Change Entries page from its role center. Defaults (role center, permissions, instructions) are already configured.';
            }
            group(Stats)
            {
                Caption = 'Captured so far';

                field("Total Changes"; Rec."Total Changes")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total captured change entries available to the agent.';
                }
                field("Error Changes"; Rec."Error Changes")
                {
                    ApplicationArea = All;
                    ToolTip = 'Captured entries of type Error.';
                }
                field("User Security ID"; Rec."User Security ID")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.InitCue();
        Rec.CalcFields("Total Changes", "Error Changes");
    end;
}
