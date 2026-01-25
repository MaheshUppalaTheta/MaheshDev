table 50002 "Data Debugger Table Filter"
{
    Caption = 'Data Debugger Table Filter';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "Table ID"; Integer)
        {
            Caption = 'Table ID';
            TableRelation = AllObjWithCaption."Object ID" where("Object Type" = const(Table));
        }
        field(11; "Table Name"; Text[250])
        {
            Caption = 'Table Name';
            Editable = false;
        }
        field(20; "Filter Type"; Enum "Data Debugger Filter Type")
        {
            Caption = 'Filter Type';
        }
        field(30; "Field Filters"; Text[2000])
        {
            Caption = 'Field Filters';
            ToolTip = 'Comma-separated list of field names to include/exclude';
        }
        field(40; Enabled; Boolean)
        {
            Caption = 'Enabled';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(TableId; "Table ID")
        {
        }
    }

    trigger OnInsert()
    begin
        UpdateTableName();
    end;

    trigger OnModify()
    begin
        UpdateTableName();
    end;

    local procedure UpdateTableName()
    var
        AllObj: Record AllObjWithCaption;
    begin
        if AllObj.Get(AllObj."Object Type"::Table, "Table ID") then
            "Table Name" := AllObj."Object Name";
    end;
}
