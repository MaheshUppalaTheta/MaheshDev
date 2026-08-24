codeunit 72930457 "Agent Metadata_TSA_TSL" implements IAgentMetadata
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    procedure GetInitials(AgentUserId: Guid): Text[4]
    begin
        exit('DD');
    end;

    procedure GetSetupPageId(AgentUserId: Guid): Integer
    begin
        exit(Page::"Agent Setup_TSA_TSL");
    end;

    procedure GetSummaryPageId(AgentUserId: Guid): Integer
    begin
        // Hover KPIs for the agent (count cues).
        exit(Page::"Agent Activities_TSA_TSL");
    end;

    procedure GetAgentTaskMessagePageId(AgentUserId: Guid; MessageId: Guid): Integer
    begin
        // 0 = use the platform default task message page.
        exit(0);
    end;

    procedure GetAgentAnnotations(AgentUserId: Guid; var Annotations: Record "Agent Annotation")
    begin
        // No agent-level preconditions to surface.
        Clear(Annotations);
    end;
}
