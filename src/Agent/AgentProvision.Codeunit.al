codeunit 50010 "DD Agent Provision"
{
    // Layer B: programmatically create + activate the Data Debugger Agent in one click. Requires the
    // Custom Agent / Data Debugger Agent Copilot capability to be enabled and billing to be set up
    // (an admin gate Microsoft enforces; an extension cannot bypass it). Once enabled, this creates a
    // fully configured instance from the registered agent type — no manual setup needed.
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    procedure CreateDataDebuggerAgent()
    var
        Agent: Codeunit Agent;
        TempAgentAccessControl: Record "Agent Access Control" temporary;
        ModuleInfo: ModuleInfo;
        AgentUserName: Code[50];
        AgentDisplayName: Text[80];
        AgentSecId: Guid;
        InstructionsSecret: SecretText;
    begin
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        AgentUserName := 'DATADEBUGGER';
        AgentDisplayName := 'Data Debugger Agent';

        // The human(s) allowed to configure/interact with the agent (start with the current user).
        TempAgentAccessControl.Init();
        TempAgentAccessControl."User Security ID" := UserSecurityId();
        TempAgentAccessControl."Can Configure Agent" := true;
        TempAgentAccessControl.Insert();

        AgentSecId := Agent.Create(
            Enum::"Agent Metadata Provider"::"Data Debugger Agent",
            AgentUserName,
            AgentDisplayName,
            TempAgentAccessControl);

        Agent.SetProfile(AgentSecId, 'DD Agent Profile', ModuleInfo.Id());

        InstructionsSecret := GetInstructions();
        Agent.SetInstructions(AgentSecId, InstructionsSecret);

        Agent.Activate(AgentSecId);

        Message('The Data Debugger Agent has been created and activated.');
    end;

    local procedure GetInstructions(): Text
    begin
        exit(
            'You are the Data Debugger Agent for Business Central. After a process is recorded with the Data Debugger, ' +
            'open the Data Debugger Change Entries page from your role center and review the entries for the latest run. ' +
            'First look for any Change Type = Error entries and the "Session Runtime Error" entry (Table ID 0); if present, ' +
            'quote the error message and read its Call Stack. Then find the first change that caused the failure or unexpected ' +
            'value (compare Old Values vs New Values), and identify the first non-Microsoft frame in the Call Stack as the likely ' +
            'root cause. Report concisely: SUMMARY / ERROR / WHERE / WHAT CHANGED / ROOT CAUSE / EVIDENCE / RECOMMENDATION. ' +
            'Back every finding with specific Entry No.s and call-stack lines. Do not guess.');
    end;
}
