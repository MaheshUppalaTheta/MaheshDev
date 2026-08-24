table 72930456 "Table Pick Buffer_TSA_TSL"
{
    Caption = 'Troubleshooting Assistant Table Pick Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            Caption = 'Table ID';
        }
        field(2; "Table Name"; Text[250])
        {
            Caption = 'Table Name';
        }
        field(3; "Change Count"; Integer)
        {
            Caption = 'Operations';
        }
    }

    keys
    {
        key(PK; "Table ID")
        {
            Clustered = true;
        }
        key(ByName; "Table Name")
        {
        }
    }
}
