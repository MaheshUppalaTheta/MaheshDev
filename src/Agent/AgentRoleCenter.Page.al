page 50011 "DD Agent Role Center"
{
    Caption = 'Data Debugger Agent';
    PageType = RoleCenter;

    // Dedicated, minimal Role Center for the Data Debugger Agent. Keeping the surface small reduces
    // contextual noise for the agent and — because agents navigate only via available actions and
    // links (no Tell Me) — guarantees the agent can reach the Data Debugger Changes list.
    layout
    {
        area(RoleCenter)
        {
            part(Activities; "DD Agent Activities")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        // Embedding links are the primary navigation an agent traverses from the Role Center.
        area(Embedding)
        {
            action(ChangesEmbed)
            {
                Caption = 'Data Debugger Changes';
                ToolTip = 'View the database changes captured by the Data Debugger.';
                RunObject = page "DD Change Entry Preview";
                ApplicationArea = All;
            }
        }

        area(Sections)
        {
            group(DataDebugger)
            {
                Caption = 'Data Debugger';

                action(Changes)
                {
                    Caption = 'Data Debugger Changes';
                    ToolTip = 'View the database changes captured by the Data Debugger.';
                    RunObject = page "DD Change Entry Preview";
                    ApplicationArea = All;
                }
                action(ControlPanel)
                {
                    Caption = 'Data Debugger';
                    ToolTip = 'Open the Data Debugger recording control panel.';
                    RunObject = page "Data Debugger";
                    ApplicationArea = All;
                }
            }
        }
    }
}
