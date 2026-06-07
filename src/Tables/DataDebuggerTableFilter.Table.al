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

    trigger OnDelete()
    var
        FieldSel: Record "DD Field Selection Buffer";
        OtherFilter: Record "Data Debugger Table Filter";
    begin
        // Remove this table's stored field selections, unless another filter row
        // still references the same Table ID.
        OtherFilter.SetRange("Table ID", "Table ID");
        OtherFilter.SetFilter("Entry No.", '<>%1', "Entry No.");
        if not OtherFilter.IsEmpty() then
            exit;

        FieldSel.SetRange("Table ID", "Table ID");
        FieldSel.DeleteAll();
    end;

    local procedure UpdateTableName()
    var
        AllObj: Record AllObjWithCaption;
    begin
        if AllObj.Get(AllObj."Object Type"::Table, "Table ID") then
            "Table Name" := AllObj."Object Name";
    end;
}
