page 72930462 "Agent Setup_TSA_TSL"
{
    // First-time setup and ongoing configuration dialog for the Troubleshooting Assistant Agent,
    // returned by both IAgentFactory.GetFirstTimeSetupPageId and IAgentMetadata.GetSetupPageId.
    //
    // Hosting the platform "Agent Setup Part" gives the standard name/state/access-control UI and,
    // more importantly, tells us whether this is a brand-new agent. When it is, we apply the
    // Troubleshooting Assistant instructions — otherwise an agent created from the platform Agents
    // page would start with none, since IAgentFactory has no instructions hook.
    PageType = ConfigurationDialog;
    Extensible = false;
    Caption = 'Troubleshooting Assistant Agent Setup';
    SourceTable = "Agent Cue_TSA_TSL";
    ApplicationArea = All;
    IsPreview = true;
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            group(Info)
            {
                Caption = 'Troubleshooting Assistant Agent';
                InstructionalText = 'This agent reviews the database changes captured by Troubleshooting Assistant and diagnoses why a process failed. It reads the Troubleshooting Assistant Change Entries page from its role center. Defaults (role center, permissions, instructions) are configured for you.';
            }

            group(Configuration)
            {
                ShowCaption = false;

                // Standard agent configuration: user name, display name, state, and access control.
                part(AgentSetupPart; "Agent Setup Part")
                {
                    ApplicationArea = All;
                    UpdatePropagation = Both;
                }
            }

            group(Stats)
            {
                Caption = 'Captured so far';

                field("Total Changes"; Rec."Total Changes")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Total captured change entries available to the agent.';
                }
                field("Error Changes"; Rec."Error Changes")
                {
                    ApplicationArea = All;
                    Editable = false;
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

    actions
    {
        area(SystemActions)
        {
            systemaction(OK)
            {
                Caption = 'Update';
                Enabled = IsUpdated;
                ToolTip = 'Apply the changes to the agent setup.';
            }
            systemaction(Cancel)
            {
                Caption = 'Cancel';
                ToolTip = 'Discard the changes and close the setup page.';
            }
        }
    }

    var
        AgentSetupBuffer: Record "Agent Setup Buffer";
        AzureOpenAI: Codeunit "Azure OpenAI";
        IsUpdated: Boolean;
        AgentUserNameTok: Label 'TROUBLESHOOTINGASSISTANCE', Locked = true;
        AgentDisplayNameLbl: Label 'Troubleshooting Assistant Agent';
        AgentSummaryLbl: Label 'Diagnoses why a Business Central process failed by reviewing the database changes captured by Troubleshooting Assistant.';
        CapabilityNotEnabledErr: Label 'The Troubleshooting Assistant Agent capability is not enabled in Copilot capabilities.\\Enable the capability before setting up the agent.';

    trigger OnOpenPage()
    begin
        if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::"Troubleshoot Agent_TSA_TSL") then
            Error(CapabilityNotEnabledErr);

        Rec.InitCue();
        Rec.CalcFields("Total Changes", "Error Changes");
        InitializePage();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        IsUpdated := IsUpdated or CurrPage.AgentSetupPart.Page.GetChangesMade();
    end;

    trigger OnModifyRecord(): Boolean
    begin
        IsUpdated := true;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        Agent: Codeunit Agent;
        AgentSetup: Codeunit "Agent Setup";
        AgentProvision: Codeunit "Agent Provision_TSA_TSL";
        AgentSecId: Guid;
        IsNewAgent: Boolean;
    begin
        if CloseAction = CloseAction::Cancel then
            exit(true);

        CurrPage.AgentSetupPart.Page.GetAgentSetupBuffer(AgentSetupBuffer);

        // A null user security ID before saving means the platform is about to create the agent, so this
        // is the one moment we may set instructions without overwriting an admin's later edits.
        IsNewAgent := IsNullGuid(AgentSetupBuffer."User Security ID");

        if AgentSetup.GetChangesMade(AgentSetupBuffer) then begin
            AgentSecId := AgentSetup.SaveChanges(AgentSetupBuffer);

            if IsNewAgent and not IsNullGuid(AgentSecId) then
                Agent.SetInstructions(AgentSecId, AgentProvision.GetInstructions());
        end;

        exit(true);
    end;

    local procedure InitializePage()
    var
        AgentSetup: Codeunit "Agent Setup";
    begin
        CurrPage.AgentSetupPart.Page.GetAgentSetupBuffer(AgentSetupBuffer);

        if AgentSetupBuffer.IsEmpty() then
            AgentSetup.GetSetupRecord(
                AgentSetupBuffer,
                Rec."User Security ID",
                Enum::"Agent Metadata Provider"::"Troubleshoot Agent_TSA_TSL",
                AgentUserNameTok,
                AgentDisplayNameLbl,
                AgentSummaryLbl);

        CurrPage.AgentSetupPart.Page.SetAgentSetupBuffer(AgentSetupBuffer);
        CurrPage.AgentSetupPart.Page.Update(false);

        IsUpdated := IsUpdated or CurrPage.AgentSetupPart.Page.GetChangesMade();
    end;
}
