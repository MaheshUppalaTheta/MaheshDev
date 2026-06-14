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
        // Adding a table means "capture everything" by default: pre-select all of its fields.
        // The user can then open Select Fields and untick the ones they don't want.
        PopulateAllFieldsSelected();
    end;

    trigger OnModify()
    begin
        UpdateTableName();
        // Picking a (new) Table ID on an existing row also pre-selects that table's fields.
        PopulateAllFieldsSelected();
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

    local procedure PopulateAllFieldsSelected()
    var
        Fld: Record Field;
        FieldSel: Record "DD Field Selection Buffer";
    begin
        if "Table ID" = 0 then
            exit;

        // Create a row for every capturable field, marked Selected, preserving any rows that
        // already exist (so re-saving the filter row never wipes the user's manual choices).
        Fld.SetRange(TableNo, "Table ID");
        Fld.SetRange(Class, Fld.Class::Normal);
        Fld.SetRange(Enabled, true);
        Fld.SetFilter(Type, '<>%1', Fld.Type::BLOB);
        if Fld.FindSet() then
            repeat
                if not FieldSel.Get("Table ID", Fld."No.") then begin
                    FieldSel.Init();
                    FieldSel."Table ID" := "Table ID";
                    FieldSel."Field No." := Fld."No.";
                    FieldSel."Field Name" := Fld.FieldName;
                    FieldSel."Field Caption" := Fld."Field Caption";
                    FieldSel."Type Name" := Fld."Type Name";
                    FieldSel.Selected := true;
                    FieldSel.Insert();
                end;
            until Fld.Next() = 0;
    end;
}
