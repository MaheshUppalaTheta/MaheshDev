page 72930460 "Agent Role Center_TSA_TSL"
{
    Caption = 'Troubleshooting Assistant Agent';
    PageType = RoleCenter;

    // Dedicated, minimal Role Center for the Troubleshooting Assistant Agent. Keeping the surface small reduces
    // contextual noise for the agent and — because agents navigate only via available actions and
    // links (no Tell Me) — guarantees the agent can reach the Troubleshooting Assistant Changes list.
    layout
    {
        area(RoleCenter)
        {
            part(Activities; "Agent Activities_TSA_TSL")
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
                Caption = 'Troubleshooting Assistant Changes';
                ToolTip = 'View the database changes captured by Troubleshooting Assistant.';
                RunObject = page "Change Entry Preview_TSA_TSL";
                ApplicationArea = All;
            }
        }

        area(Sections)
        {
            group(TroubleshootingAssistant)
            {
                Caption = 'Troubleshooting Assistant';

                action(Changes)
                {
                    Caption = 'Troubleshooting Assistant Changes';
                    ToolTip = 'View the database changes captured by Troubleshooting Assistant.';
                    RunObject = page "Change Entry Preview_TSA_TSL";
                    ApplicationArea = All;
                }
                action(ControlPanel)
                {
                    Caption = 'Troubleshooting Assistant';
                    ToolTip = 'Open the Troubleshooting Assistant recording control panel.';
                    RunObject = page "Troubleshooting_TSA_TSL";
                    ApplicationArea = All;
                }
            }
        }
    }
}
