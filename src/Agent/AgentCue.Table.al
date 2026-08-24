table 50008 "DD Agent Cue"
{
    Caption = 'Data Debugger Agent Cue';
    DataClassification = SystemMetadata;
    Extensible = false; // Required: this table backs a ConfigurationDialog page.

    // Cue source for the agent Role Center Activities part. A singleton row whose FlowFields
    // count the persisted Change Buffer, so the cue tiles ("queues") show live totals.
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Total Changes"; Integer)
        {
            Caption = 'Total Captured Changes';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = count("Data Debugger Change Buffer");
        }
        field(3; "Error Changes"; Integer)
        {
            Caption = 'Captured Errors';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = count("Data Debugger Change Buffer" where("Change Type" = const(Error)));
        }
        field(4; "Temporary Table Changes"; Integer)
        {
            Caption = 'Temporary Table Changes';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = count("Data Debugger Change Buffer" where("Is Temporary Table" = const(true)));
        }
        field(10; "User Security ID"; Guid)
        {
            // Required on agent setup/summary pages: the runtime writes the agent's user id here
            // when the page is opened during agent creation/configuration.
            Caption = 'User Security ID';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure InitCue()
    begin
        Reset();
        if not Get('') then begin
            Init();
            "Primary Key" := '';
            Insert();
        end;
    end;
}
