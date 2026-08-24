page 72930460 "Agent Role Center_TSA_TSL"
{
    Caption = 'Troubleshooting Assistance Agent';
    PageType = RoleCenter;

    // Dedicated, minimal Role Center for the Troubleshooting Assistance Agent. Keeping the surface small reduces
    // contextual noise for the agent and — because agents navigate only via available actions and
    // links (no Tell Me) — guarantees the agent can reach the Troubleshooting Assistance Changes list.
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
                Caption = 'Troubleshooting Assistance Changes';
                ToolTip = 'View the database changes captured by Troubleshooting Assistance.';
                RunObject = page "Change Entry Preview_TSA_TSL";
                ApplicationArea = All;
            }
        }

        area(Sections)
        {
            group(TroubleshootingAssistance)
            {
                Caption = 'Troubleshooting Assistance';

                action(Changes)
                {
                    Caption = 'Troubleshooting Assistance Changes';
                    ToolTip = 'View the database changes captured by Troubleshooting Assistance.';
                    RunObject = page "Change Entry Preview_TSA_TSL";
                    ApplicationArea = All;
                }
                action(ControlPanel)
                {
                    Caption = 'Troubleshooting Assistance';
                    ToolTip = 'Open the Troubleshooting Assistance recording control panel.';
                    RunObject = page "Troubleshooting_TSA_TSL";
                    ApplicationArea = All;
                }
            }
        }
    }
}
