table 50001 "Data Debugger Setup"
{
    Caption = 'Data Debugger Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(12; "Table Capture Scope"; Enum "DD Capture Scope")
        {
            Caption = 'Table Capture Scope';
            InitValue = "All Tables";
            ToolTip = 'All Tables: capture every table. Only Selected Tables: capture only the tables listed in Table Filters (whitelist). All Except Selected Tables: capture everything except the tables listed in Table Filters (blacklist).';
        }
        field(30; "Enable Change Threshold"; Boolean)
        {
            Caption = 'Enable Change Threshold';
        }
        field(31; "Min Field Changes Required"; Integer)
        {
            Caption = 'Min Field Changes Required';
            InitValue = 1;
            MinValue = 1;
        }
        field(40; "Max Records Per Session"; Integer)
        {
            Caption = 'Max Records Per Session';
            InitValue = 10000;
            MinValue = 100;
        }
        field(50; "Enable Performance Throttling"; Boolean)
        {
            Caption = 'Enable Performance Throttling';
        }
        field(51; "Max Captures Per Second"; Integer)
        {
            Caption = 'Max Captures Per Second';
            InitValue = 100;
            MinValue = 1;
        }
        field(60; "Direct Database Capture"; Boolean)
        {
            Caption = 'Direct Database Capture';
            InitValue = false;
            // Default OFF = rollback-safe (in-memory) capture, which is also what an existing Setup
            // record reports for this newly added boolean field, so the safe behavior is the default
            // everywhere without an upgrade step.
            ToolTip = 'Off (default): changes are buffered in memory and survive a process error/rollback; results are written when you Stop Recording (records your OWN current session). On: changes are written directly to the table (supports recording another user) but are rolled back if the recorded process errors.';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetSetup(): Record "Data Debugger Setup"
    var
        Setup: Record "Data Debugger Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup."Primary Key" := '';
            Setup."Table Capture Scope" := Setup."Table Capture Scope"::"All Tables";
            Setup."Enable Change Threshold" := false;
            Setup."Min Field Changes Required" := 1;
            Setup."Max Records Per Session" := 10000;
            Setup."Enable Performance Throttling" := false;
            Setup."Max Captures Per Second" := 100;
            Setup."Direct Database Capture" := false; // default to rollback-safe in-memory capture
            Setup.Insert();
        end;
        exit(Setup);
    end;
}
