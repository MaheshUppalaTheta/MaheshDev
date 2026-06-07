page 50100 "DD Change Entry API"
{
    PageType = API;
    Caption = 'Data Debugger Change Entry';
    APIPublisher = 'theta';
    APIGroup = 'dataDebugger';
    APIVersion = 'v1.0';
    EntityName = 'changeEntry';
    EntitySetName = 'changeEntries';
    SourceTable = "Data Debugger Change Buffer";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    AboutText = 'API endpoint exposing change entries captured by the Data Debugger. Each entry represents a change to a record in the system, including metadata such as the user who made the change, the time of change, and the old/new values.';
    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(entryNo; Rec."Entry No.")
                {
                    Caption = 'Entry No.';
                }
                field(runId; Rec."Run ID")
                {
                    Caption = 'Run ID';
                }
                field(timestamp; Rec.Timestamp1)
                {
                    Caption = 'Timestamp';
                }
                field(tableId; Rec."Table ID")
                {
                    Caption = 'Table ID';
                }
                field(tableName; Rec."Table Name")
                {
                    Caption = 'Table Name';
                }
                field(changeType; Rec."Change Type")
                {
                    Caption = 'Change Type';
                }
                field(primaryKey; Rec."Primary Key")
                {
                    Caption = 'Primary Key';
                }
                field(recordCount; Rec."Record Count")
                {
                    Caption = 'Record Count';
                }
                field(userId; Rec."User ID")
                {
                    Caption = 'User ID';
                }
                field(userName; Rec."User Name")
                {
                    Caption = 'User Name';
                }
                field(companyName; Rec."Company Name")
                {
                    Caption = 'Company Name';
                }
                field(sessionId; Rec."Session ID")
                {
                    Caption = 'Session ID';
                }
                field(transactionId; Rec."Transaction ID")
                {
                    Caption = 'Transaction ID';
                }
                field(triggerSource; Rec."Trigger Source")
                {
                    Caption = 'Trigger Source';
                }
                field(clientType; Rec."Client Type")
                {
                    Caption = 'Client Type';
                }
                field(isTemporaryTable; Rec."Is Temporary Table")
                {
                    Caption = 'Is Temporary Table';
                }
                field(oldData; OldDataJson)
                {
                    Caption = 'Old Data';
                }
                field(newData; NewDataJson)
                {
                    Caption = 'New Data';
                }
                field(callStack; CallStackText)
                {
                    Caption = 'Call Stack';
                }
            }
        }
    }

    var
        OldDataJson: Text;
        NewDataJson: Text;
        CallStackText: Text;

    trigger OnAfterGetRecord()
    begin
        // BLOB fields are surfaced as text for MCP/AI consumption.
        OldDataJson := Rec.GetOldData();
        NewDataJson := Rec.GetNewData();
        CallStackText := Rec.GetCallStack();
    end;
}
