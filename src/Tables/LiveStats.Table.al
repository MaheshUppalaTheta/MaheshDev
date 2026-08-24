table 72930453 "Live Stats_TSA_TSL"
{
    Caption = 'Troubleshooting Assistance Live Stats';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Total Changes"; Integer)
        {
            Caption = 'Total Changes';
        }
        field(11; "Changes Per Second"; Decimal)
        {
            Caption = 'Changes Per Second';
            DecimalPlaces = 2 : 2;
        }
        field(12; "Duration Text"; Text[50])
        {
            Caption = 'Duration Text';
        }
        field(13; "Last Capture Info"; Text[100])
        {
            Caption = 'Last Capture Info';
        }
        field(14; "Start Time"; DateTime)
        {
            Caption = 'Start Time';
        }
        field(15; "Last Capture Time"; DateTime)
        {
            Caption = 'Last Capture Time';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
