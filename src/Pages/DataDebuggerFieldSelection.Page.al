page 50111 "DD Field Selection"
{
    PageType = List;
    Caption = 'Select Fields';
    SourceTable = "DD Field Selection Buffer";
    ApplicationArea = All;
    UsageCategory = None;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(Selected; Rec.Selected)
                {
                    Caption = 'Selected';
                    ToolTip = 'Tick the fields you want to capture for this table. Changes are saved immediately.';
                }
                field("Field No."; Rec."Field No.")
                {
                    Caption = 'Field No.';
                    Editable = false;
                    ToolTip = 'The field number.';
                }
                field("Field Name"; Rec."Field Name")
                {
                    Caption = 'Field Name';
                    Editable = false;
                    ToolTip = 'The field name that gets captured.';
                }
                field("Field Caption"; Rec."Field Caption")
                {
                    Caption = 'Caption';
                    Editable = false;
                    ToolTip = 'The display caption of the field.';
                }
                field("Type Name"; Rec."Type Name")
                {
                    Caption = 'Type';
                    Editable = false;
                    ToolTip = 'The data type of the field.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SelectAll)
            {
                Caption = 'Select All';
                ToolTip = 'Tick every field.';
                Image = AllLines;

                trigger OnAction()
                begin
                    SetAllSelected(true);
                end;
            }
            action(ClearAll)
            {
                Caption = 'Clear All';
                ToolTip = 'Untick every field.';
                Image = RemoveLine;

                trigger OnAction()
                begin
                    SetAllSelected(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(SelectAll_Promoted; SelectAll) { }
                actionref(ClearAll_Promoted; ClearAll) { }
            }
        }
    }

    var
        TableNo: Integer;

    procedure SetTableId(NewTableNo: Integer)
    begin
        // No DB writes here - the caller must not open a write transaction before RunModal.
        TableNo := NewTableNo;
    end;

    trigger OnOpenPage()
    begin
        PopulateFields();

        // Show only this table's fields, and lock the filter so it can't be cleared.
        Rec.FilterGroup(2);
        Rec.SetRange("Table ID", TableNo);
        Rec.FilterGroup(0);
    end;

    local procedure PopulateFields()
    var
        Fld: Record Field;
        FieldSel: Record "DD Field Selection Buffer";
    begin
        if TableNo = 0 then
            exit;

        // Make sure a row exists for every capturable field of the table,
        // preserving any previously stored Selected values.
        Fld.SetRange(TableNo, TableNo);
        Fld.SetRange(Class, Fld.Class::Normal);
        Fld.SetRange(Enabled, true);
        Fld.SetFilter(Type, '<>%1', Fld.Type::BLOB);
        if Fld.FindSet() then
            repeat
                if not FieldSel.Get(TableNo, Fld."No.") then begin
                    FieldSel.Init();
                    FieldSel."Table ID" := TableNo;
                    FieldSel."Field No." := Fld."No.";
                    FieldSel."Field Name" := Fld.FieldName;
                    FieldSel."Field Caption" := Fld."Field Caption";
                    FieldSel."Type Name" := Fld."Type Name";
                    FieldSel.Selected := true; // default to capturing all fields; user unticks to exclude
                    FieldSel.Insert();
                end;
            until Fld.Next() = 0;
    end;

    local procedure SetAllSelected(NewValue: Boolean)
    begin
        if Rec.FindSet() then
            repeat
                Rec.Selected := NewValue;
                Rec.Modify();
            until Rec.Next() = 0;
        CurrPage.Update(false);
    end;
}
