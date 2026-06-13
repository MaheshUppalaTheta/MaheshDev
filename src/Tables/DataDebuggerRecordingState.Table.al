table 50007 "DD Recording State"
{
    Caption = 'Data Debugger Recording State';
    DataClassification = SystemMetadata;

    // Singleton holding the cross-session recording state. Because capture now runs in the
    // recorded user's own session (automatic global-trigger subscribers, not a session-bound
    // BindSubscription), the active flag, run id and target user must live in the database so
    // every session can read them.
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Is Recording"; Boolean)
        {
            Caption = 'Is Recording';
        }
        field(3; "Run ID"; Guid)
        {
            Caption = 'Run ID';
        }
        field(4; "Recorded User Security ID"; Guid)
        {
            Caption = 'Recorded User Security ID';
        }
        field(5; "Recorded User ID"; Code[50])
        {
            Caption = 'Recorded User ID';
        }
        field(6; "Recorded User Name"; Text[80])
        {
            Caption = 'Recorded User Name';
        }
        field(7; "Start Time"; DateTime)
        {
            Caption = 'Start Time';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetState(): Record "DD Recording State"
    var
        State: Record "DD Recording State";
    begin
        if not State.Get('') then begin
            State.Init();
            State."Primary Key" := '';
            State.Insert();
        end;
        exit(State);
    end;
}
