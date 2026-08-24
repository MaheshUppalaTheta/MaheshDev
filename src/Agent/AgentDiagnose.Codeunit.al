codeunit 72930455 "Agent Diagnose_TSA_TSL"
{
    // Creates an agent task that asks the Troubleshooting Assistant Agent to diagnose the most recent recording
    // run, using the BC Agent Tasks API (Agent Task Builder). Triggered from a page action so a user
    // can launch the canned "diagnose latest run" task in one click — the code-side equivalent of an
    // agent task template.

    procedure DiagnoseLatestRun()
    var
        AgentTaskBuilder: Codeunit "Agent Task Builder";
        AgentTask: Record "Agent Task";
        AgentSecId: Guid;
        AgentName: Text;
        LatestRunId: Guid;
    begin
        ResolveAgent(AgentSecId, AgentName);
        LatestRunId := GetLatestRunId();

        AgentTask := AgentTaskBuilder
            .Initialize(AgentSecId, 'Diagnose latest captured run')
            .AddTaskMessage('Troubleshooting Assistant', BuildPrompt(LatestRunId))
            .Create();

        Message('Sent a diagnosis task for run %1 to agent ''%2''. Open the agent to review and run it.', LatestRunId, AgentName);
    end;

    local procedure ResolveAgent(var AgentSecId: Guid; var AgentName: Text)
    var
        User: Record User;
        Users: Page Users;
    begin
        // The agent is a user in Business Central. The virtual "Agent" table is OnPrem-scoped (and the
        // cloud-safe Custom Agent enumerator only exists from 28.1), so we let the user pick the agent
        // user from the standard Users lookup — agents appear there like any other user.
        Users.LookupMode(true);
        if Users.RunModal() <> Action::LookupOK then
            Error('Select the agent user to send the diagnosis task to.');

        Users.GetRecord(User);
        AgentSecId := User."User Security ID";
        if User."Full Name" <> '' then
            AgentName := User."Full Name"
        else
            AgentName := User."User Name";
    end;

    local procedure GetLatestRunId(): Guid
    var
        ChangeBuffer: Record "Change Buffer_TSA_TSL";
    begin
        ChangeBuffer.SetCurrentKey("Entry No.");
        if not ChangeBuffer.FindLast() then
            Error('There are no captured changes yet. Record a process with the Troubleshooting Assistant first.');
        exit(ChangeBuffer."Run ID");
    end;

    local procedure BuildPrompt(RunId: Guid): Text
    begin
        exit(
            'Diagnose the most recent Troubleshooting Assistant recording run (Run ID ' + Format(RunId) + '). ' +
            'Open the Troubleshooting Assistant Change Entries page and review all entries for that run. ' +
            'First look for any Change Type = Error entries and the "Session Runtime Error" entry (Table ID 0); ' +
            'if present, quote the exact error message and read its Call Stack. ' +
            'Then walk the entries in time order, find the first change that caused the failure or the unexpected value ' +
            '(compare Old Values vs New Values), and identify the first non-Microsoft frame in the Call Stack as the likely root cause. ' +
            'Report concisely using the SUMMARY / ERROR / WHERE / WHAT CHANGED / ROOT CAUSE / EVIDENCE / RECOMMENDATION format. ' +
            'Back every finding with specific Entry No.s and call-stack lines. Do not guess.');
    end;
}
