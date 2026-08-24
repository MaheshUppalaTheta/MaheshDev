codeunit 72930459 "Agent Install_TSA_TSL"
{
    Subtype = Install;
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    trigger OnInstallAppPerDatabase()
    begin
        RegisterCapability();
    end;

    trigger OnInstallAppPerCompany()
    var
        Setup: Record "Setup_TSA_TSL";
        State: Record "Recording State_TSA_TSL";
        AgentProvision: Codeunit "Agent Provision_TSA_TSL";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            Setup.Insert(false);
        end;
        if not State.Get('') then begin
            State.Init();
            State."Primary Key" := '';
            State.Insert(false);
        end;

        // Create and activate the agent when the capability is already enabled, or refresh the
        // instructions of an agent an earlier version created. Runs per company but is idempotent:
        // the first company provisions, the rest find the existing agent. Never blocks the install.
        AgentProvision.EnsureAgentProvisioned();
    end;

    local procedure RegisterCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
        LearnMoreUrlTxt: Label 'https://github.com/MaheshUppalaTheta/MaheshDev/blob/main/docs/getting-started.md', Locked = true;
    begin
        // Make the Troubleshooting Assistant agent visible on the Copilot & AI Capabilities page so an admin can
        // turn it on. Registration is idempotent.
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Troubleshoot Agent_TSA_TSL") then
            CopilotCapability.RegisterCapability(
                Enum::"Copilot Capability"::"Troubleshoot Agent_TSA_TSL",
                Enum::"Copilot Availability"::Preview,
                Enum::"Copilot Billing Type"::"Microsoft Billed",
                LearnMoreUrlTxt);
    end;
}
