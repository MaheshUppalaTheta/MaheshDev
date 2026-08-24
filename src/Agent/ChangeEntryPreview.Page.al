page 50110 "DD Change Entry Preview"
{
    // The agent-facing list of captured changes, surfaced from the DD Agent Role Center.
    // Old/New values and the call stack are exposed as COLUMNS (populated in OnAfterGetRecord),
    // not as actions, so the agent can read them directly without invoking an action per row.
    PageType = List;
    Caption = 'Data Debugger Change Entries';
    SourceTable = "Data Debugger Change Buffer";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;
    SourceTableView = sorting("Entry No.") order(descending);
    AboutTitle = 'Data Debugger Change Entries';
    AboutText = 'Database changes captured by the Data Debugger, including user/session context and the old/new values and call stack as readable columns.';

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Auto-assigned entry number.';
                }
                field("Run ID"; Rec."Run ID")
                {
                    ToolTip = 'The recording session this change belongs to.';
                }
                field(Timestamp1; Rec.Timestamp1)
                {
                    Caption = 'Timestamp';
                    ToolTip = 'When the change was captured.';
                }
                field("Change Type"; Rec."Change Type")
                {
                    ToolTip = 'Insert, Modify, Delete, Rename, or Error.';
                }
                field("Table ID"; Rec."Table ID")
                {
                    ToolTip = 'ID of the changed table.';
                }
                field("Table Name"; Rec."Table Name")
                {
                    ToolTip = 'Name of the changed table.';
                }
                field("Primary Key"; Rec."Primary Key")
                {
                    ToolTip = 'Primary key value(s) of the changed record.';
                }
                field("Record Count"; Rec."Record Count")
                {
                    ToolTip = 'Number of records affected.';
                }
                field("User ID"; Rec."User ID")
                {
                    ToolTip = 'The user (login) who made the change.';
                }
                field("User Name"; Rec."User Name")
                {
                    ToolTip = 'The full name of the user who made the change.';
                }
                field("Company Name"; Rec."Company Name")
                {
                    ToolTip = 'The company in which the change occurred.';
                }
                field("Session ID"; Rec."Session ID")
                {
                    ToolTip = 'The session that made the change.';
                }
                field("Transaction ID"; Rec."Transaction ID")
                {
                    ToolTip = 'Transaction grouping for related changes.';
                }
                field("Client Type"; Rec."Client Type")
                {
                    ToolTip = 'The client type of the session.';
                }
                field("Trigger Source"; Rec."Trigger Source")
                {
                    ToolTip = 'Derived source of the database trigger.';
                }
                field("Is Temporary Table"; Rec."Is Temporary Table")
                {
                    ToolTip = 'Whether the change was on a temporary table instance.';
                }
                field(OldValues; OldData)
                {
                    Caption = 'Old Values';
                    ToolTip = 'The captured record values before the change, as JSON.';
                }
                field(NewValues; NewData)
                {
                    Caption = 'New Values';
                    ToolTip = 'The captured record values after the change, as JSON.';
                }
                field(CallStackText; CallStack)
                {
                    Caption = 'Call Stack';
                    ToolTip = 'The captured AL call stack (for Error entries, the error-origin stack).';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DiagnoseWithAgent)
            {
                Caption = 'Diagnose Latest Run with Agent';
                ToolTip = 'Create an agent task asking the Data Debugger Agent to analyze the most recent recording run and report the likely root cause.';
                Image = Sparkle;
                ApplicationArea = All;

                trigger OnAction()
                var
                    AgentDiagnose: Codeunit "DD Agent Diagnose";
                begin
                    AgentDiagnose.DiagnoseLatestRun();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(DiagnoseWithAgent_Promoted; DiagnoseWithAgent) { }
            }
        }
    }

    var
        OldData: Text;
        NewData: Text;
        CallStack: Text;

    trigger OnAfterGetRecord()
    begin
        // Extract the BLOB payloads into the field variables so they render as columns.
        OldData := Rec.GetOldData();
        NewData := Rec.GetNewData();
        CallStack := Rec.GetCallStack();
    end;
}
