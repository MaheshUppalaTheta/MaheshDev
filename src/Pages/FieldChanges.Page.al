page 72930452 "Field Changes_TSA_TSL"
{
    Caption = 'Field Changes Detail';
    PageType = List;
    SourceTable = "Name/Value Buffer";
    SourceTableTemporary = true;
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Header)
            {
                Caption = 'Change Information';

                field(TableNameField; ChangeRecord."Table Name")
                {
                    Caption = 'Table';
                    Editable = false;
                }

                field(ChangeTypeField; ChangeRecord."Change Type")
                {
                    Caption = 'Change Type';
                    Editable = false;
                }

                field(PrimaryKeyField; ChangeRecord."Primary Key")
                {
                    Caption = 'Primary Key';
                    Editable = false;
                }

                field(TimestampField; ChangeRecord.Timestamp1)
                {
                    Caption = 'Timestamp';
                    Editable = false;
                }

                field(ChangedFieldsCountField; ChangedFieldsCount)
                {
                    Caption = 'Changed Fields';
                    Editable = false;
                    Style = Strong;
                    StyleExpr = ChangedFieldsCount > 0;
                }

                field(ShowOnlyChangedField; ShowOnlyChanged)
                {
                    Caption = 'Show Only Changed';
                    ToolTip = 'When enabled, shows only fields that have different values between old and new data';

                    trigger OnValidate()
                    begin
                        ApplyFilter();
                    end;
                }
            }

            repeater(Fields)
            {
                field(Name; Rec.Name)
                {
                    Caption = 'Field Name';
                    ApplicationArea = All;
                }

                field(Value; Rec.Value)
                {
                    Caption = 'Old Value';
                    ApplicationArea = All;
                }

                field("Value Long"; Rec."Value Long")
                {
                    Caption = 'New Value';
                    ApplicationArea = All;
                }

                field(IsChanged; GetChangedIndicator())
                {
                    Caption = 'Changed';
                    ApplicationArea = All;
                    Width = 5;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ShowOnlyChangedFields)
            {
                Caption = 'Show Only Changed Fields';
                ToolTip = 'Filter to show only fields that have different values';
                Image = FilterLines;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    ShowOnlyChanged := true;
                    ApplyFilter();
                    CurrPage.Update(false);
                end;
            }

            action(ShowAllFields)
            {
                Caption = 'Show All Fields';
                ToolTip = 'Show all fields including unchanged ones';
                Image = ClearFilter;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    ShowOnlyChanged := false;
                    ApplyFilter();
                    CurrPage.Update(false);
                end;
            }

            action(RefreshView)
            {
                Caption = 'Refresh';
                ToolTip = 'Reload the field changes';
                Image = Refresh;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    LoadFieldChanges();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        ChangeRecord: Record "Change Buffer_TSA_TSL";
        OriginalBuffer: Record "Name/Value Buffer" temporary;
        ShowOnlyChanged: Boolean;
        ChangedFieldsCount: Integer;

    procedure SetChangeRecord(var ChangeRec: Record "Change Buffer_TSA_TSL")
    begin
        // Ensure BLOB fields are loaded
        ChangeRec.CalcFields("Old Data", "New Data");

        ChangeRecord := ChangeRec;
        LoadFieldChanges();
    end;

    local procedure LoadFieldChanges()
    var
        OldDataJson: JsonObject;
        NewDataJson: JsonObject;
        OldDataText: Text;
        NewDataText: Text;
        FieldName: Text;
        JsonToken: JsonToken;
    begin
        Rec.Reset();
        Rec.DeleteAll();
        OriginalBuffer.Reset();
        OriginalBuffer.DeleteAll();
        ChangedFieldsCount := 0;

        OldDataText := ChangeRecord.GetOldData();
        NewDataText := ChangeRecord.GetNewData();

        // Parse old data
        if OldDataText <> '' then
            OldDataJson.ReadFrom(OldDataText);

        // Parse new data
        if NewDataText <> '' then
            NewDataJson.ReadFrom(NewDataText);

        // Compare fields
        if NewDataJson.Keys().Count() > 0 then begin
            foreach FieldName in NewDataJson.Keys() do begin
                Rec.Init();
                Rec.ID := Rec.Count() + 1;
                Rec.Name := CopyStr(FieldName, 1, MaxStrLen(Rec.Name));

                // Get old value
                if OldDataJson.Get(FieldName, JsonToken) then
                    Rec.Value := CopyStr(GetJsonTokenValue(JsonToken), 1, MaxStrLen(Rec.Value))
                else
                    Rec.Value := '';

                // Get new value
                if NewDataJson.Get(FieldName, JsonToken) then
                    Rec."Value Long" := CopyStr(GetJsonTokenValue(JsonToken), 1, MaxStrLen(Rec."Value Long"))
                else
                    Rec."Value Long" := '';

                // Count changed fields
                if IsFieldChanged(Rec.Value, Rec."Value Long") then
                    ChangedFieldsCount += 1;

                Rec.Insert();

                // Store in original buffer for filtering
                OriginalBuffer := Rec;
                OriginalBuffer.Insert();
            end;
        end;

        // Apply initial filter if needed
        ApplyFilter();
    end;

    local procedure GetJsonTokenValue(JsonToken: JsonToken): Text
    begin
        if JsonToken.IsValue() then begin
            if JsonToken.AsValue().IsNull() then
                exit('<null>');
            exit(Format(JsonToken.AsValue().AsText()));
        end;
        exit('<complex>');
    end;

    local procedure IsFieldChanged(OldValue: Text; NewValue: Text): Boolean
    begin
        // Consider null/empty as equal
        if (OldValue = '') and (NewValue = '') then
            exit(false);

        if (OldValue = '<null>') and (NewValue = '') then
            exit(false);

        if (OldValue = '') and (NewValue = '<null>') then
            exit(false);

        // Compare values
        exit(OldValue <> NewValue);
    end;

    local procedure ApplyFilter()
    begin
        Rec.Reset();
        Rec.DeleteAll();

        OriginalBuffer.Reset();
        if OriginalBuffer.FindSet() then begin
            repeat
                // Apply filter logic
                if (not ShowOnlyChanged) or IsFieldChanged(OriginalBuffer.Value, OriginalBuffer."Value Long") then begin
                    Rec := OriginalBuffer;
                    Rec.Insert();
                end;
            until OriginalBuffer.Next() = 0;
        end;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure GetChangedIndicator(): Text
    begin
        if IsFieldChanged(Rec.Value, Rec."Value Long") then
            exit('●')  // Bullet point to indicate changed
        else
            exit('');
    end;
}
