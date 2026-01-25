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
        field(10; "Enable Table Filtering"; Boolean)
        {
            Caption = 'Enable Table Filtering';
        }
        field(11; "Table Filter Mode"; Enum "DD Table Filter Mode")
        {
            Caption = 'Table Filter Mode';
        }
        field(20; "Enable Field Filtering"; Boolean)
        {
            Caption = 'Enable Field Filtering';
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
            Setup."Enable Table Filtering" := false;
            Setup."Table Filter Mode" := Setup."Table Filter Mode"::"Exclude Only";
            Setup."Enable Field Filtering" := false;
            Setup."Enable Change Threshold" := false;
            Setup."Min Field Changes Required" := 1;
            Setup."Max Records Per Session" := 10000;
            Setup."Enable Performance Throttling" := false;
            Setup."Max Captures Per Second" := 100;
            Setup.Insert();
        end;
        exit(Setup);
    end;
}
