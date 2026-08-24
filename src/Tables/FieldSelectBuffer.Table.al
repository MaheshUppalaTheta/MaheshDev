table 50005 "DD Field Selection Buffer"
{
    Caption = 'Data Debugger Table Filter Field';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            Caption = 'Table ID';
        }
        field(2; "Field No."; Integer)
        {
            Caption = 'Field No.';
        }
        field(3; "Field Name"; Text[30])
        {
            Caption = 'Field Name';
        }
        field(4; "Field Caption"; Text[80])
        {
            Caption = 'Caption';
        }
        field(5; "Type Name"; Text[30])
        {
            Caption = 'Type';
        }
        field(6; Selected; Boolean)
        {
            Caption = 'Selected';
        }
    }

    keys
    {
        key(PK; "Table ID", "Field No.")
        {
            Clustered = true;
        }
    }
}
