codeunit 72930460 "Agent Provision_TSA_TSL"
{
    // Agent lifecycle for the Troubleshooting Assistant Agent: creating an instance, keeping its
    // instructions current, and supplying those instructions to the other creation paths.
    //
    // Three callers reach this codeunit:
    //   1. The "Create Troubleshooting Assistant Agent" action on the Troubleshooting page (interactive).
    //   2. "Agent Install_TSA_TSL" at install/upgrade time (unattended) via EnsureAgentProvisioned().
    //   3. "Agent Setup_TSA_TSL" when an admin creates the agent from the platform Agents page,
    //      which calls GetInstructions() so that path is not left with blank instructions.
    //
    // Creating an agent requires the Troubleshooting Assistant Agent Copilot capability to be enabled
    // and billing to be set up — an admin gate Microsoft enforces that an extension cannot bypass.
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        AgentUserNameTok: Label 'TROUBLESHOOTINGASSISTANCE', Locked = true;
        AgentDisplayNameLbl: Label 'Troubleshooting Assistant Agent';
        InstructionsResourceTok: Label 'Instructions.txt', Locked = true;
        AgentCreatedMsg: Label 'The Troubleshooting Assistant Agent has been created and activated.';
        AgentExistsMsg: Label 'The Troubleshooting Assistant Agent already exists. Its instructions have been refreshed.';

    /// <summary>
    /// Interactive creation from the Troubleshooting page. Creates the agent if it does not exist yet,
    /// otherwise refreshes the instructions of the existing one.
    /// </summary>
    procedure CreateTroubleshootingAgent()
    var
        Agent: Codeunit Agent;
        AgentSetup: Codeunit "Agent Setup";
        ExistingAgentSecId: Guid;
    begin
        if AgentSetup.FindAgentByUserName(AgentUserNameTok, ExistingAgentSecId) then begin
            Agent.SetInstructions(ExistingAgentSecId, GetInstructions());
            if GuiAllowed() then
                Message(AgentExistsMsg);
            exit;
        end;

        CreateAgent();

        if GuiAllowed() then
            Message(AgentCreatedMsg);
    end;

    /// <summary>
    /// Unattended provisioning, called from the install trigger. Creates and activates the agent when the
    /// Copilot capability is already enabled; refreshes instructions when the agent exists. Never surfaces
    /// an error, so a failure here cannot block the app install.
    /// </summary>
    internal procedure EnsureAgentProvisioned()
    begin
        if not TryEnsureAgentProvisioned() then
            ClearLastError();
    end;

    [TryFunction]
    local procedure TryEnsureAgentProvisioned()
    var
        Agent: Codeunit Agent;
        AgentSetup: Codeunit "Agent Setup";
        CopilotCapability: Codeunit "Copilot Capability";
        ExistingAgentSecId: Guid;
    begin
        // An agent already exists: re-apply the instructions so an app update ships the latest guidance
        // to agents that were created by an earlier version.
        if AgentSetup.FindAgentByUserName(AgentUserNameTok, ExistingAgentSecId) then begin
            Agent.SetInstructions(ExistingAgentSecId, GetInstructions());
            exit;
        end;

        // Creating an agent consumes billed capacity, so only do it once an admin has switched the
        // capability on. Until then the capability registration is the only footprint we leave.
        if not CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::"Troubleshoot Agent_TSA_TSL") then
            exit;

        CreateAgent();
    end;

    local procedure CreateAgent(): Guid
    var
        Agent: Codeunit Agent;
        TempAgentAccessControl: Record "Agent Access Control" temporary;
        ModuleInfo: ModuleInfo;
        AgentUserName: Code[50];
        AgentDisplayName: Text[80];
        AgentSecId: Guid;
    begin
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        AgentUserName := AgentUserNameTok;
        AgentDisplayName := AgentDisplayNameLbl;

        // The human(s) allowed to configure/interact with the agent (start with the current user).
        TempAgentAccessControl.Init();
        TempAgentAccessControl."User Security ID" := UserSecurityId();
        TempAgentAccessControl."Can Configure Agent" := true;
        TempAgentAccessControl.Insert();

        AgentSecId := Agent.Create(
            Enum::"Agent Metadata Provider"::"Troubleshoot Agent_TSA_TSL",
            AgentUserName,
            AgentDisplayName,
            TempAgentAccessControl);

        Agent.SetProfile(AgentSecId, 'Agent Profile_TSA_TSL', ModuleInfo.Id());
        Agent.SetInstructions(AgentSecId, GetInstructions());
        Agent.Activate(AgentSecId);

        exit(AgentSecId);
    end;

    /// <summary>
    /// The agent's instructions, loaded from the embedded Instructions.txt resource declared under
    /// "resourceFolders" in app.json. Falls back to a condensed inline copy if the resource cannot be
    /// read, so the agent is never left without guidance.
    /// </summary>
    [NonDebuggable]
    internal procedure GetInstructions(): SecretText
    var
        Instructions: Text;
    begin
        Instructions := NavApp.GetResourceAsText(InstructionsResourceTok, TextEncoding::UTF8);

        if Instructions.Trim() = '' then
            Instructions := GetFallbackInstructions();

        exit(Instructions);
    end;

    local procedure GetFallbackInstructions(): Text
    begin
        exit(
            'You are the Troubleshooting Assistant Agent for Business Central. After a process is recorded with Troubleshooting Assistant, ' +
            'open the Troubleshooting Assistant Change Entries page from your role center and review the entries for the latest run. ' +
            'First look for any Change Type = Error entries and the "Session Runtime Error" entry (Table ID 0); if present, ' +
            'quote the error message and read its Call Stack. Then find the first change that caused the failure or unexpected ' +
            'value (compare Old Values vs New Values), and identify the first non-Microsoft frame in the Call Stack as the likely ' +
            'root cause. Report concisely: SUMMARY / ERROR / WHERE / WHAT CHANGED / ROOT CAUSE / EVIDENCE / RECOMMENDATION. ' +
            'Back every finding with specific Entry No.s and call-stack lines. Do not guess.');
    end;
}
