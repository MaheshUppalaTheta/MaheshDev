codeunit 50009 "DD Agent Install"
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
        Setup: Record "Data Debugger Setup";
        State: Record "DD Recording State";
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
    end;

    local procedure RegisterCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
        LearnMoreUrlTxt: Label 'https://github.com/MaheshUppalaTheta/MaheshDev/blob/main/docs/getting-started.md', Locked = true;
    begin
        // Make the Data Debugger agent visible on the Copilot & AI Capabilities page so an admin can
        // turn it on. Registration is idempotent.
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Data Debugger Agent") then
            CopilotCapability.RegisterCapability(
                Enum::"Copilot Capability"::"Data Debugger Agent",
                Enum::"Copilot Availability"::Preview,
                Enum::"Copilot Billing Type"::"Microsoft Billed",
                LearnMoreUrlTxt);
    end;
}
