page 50011 "DD Record Comparison"
{
    Caption = 'Record Comparison';
    PageType = Card;
    SourceTable = "Data Debugger Change Buffer";
    SourceTableTemporary = true;
    Editable = false;
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(RecordInfo)
            {
                Caption = 'Record Information';
                Visible = HasData;

                field(TableNameDisplay; TableNameDisplay)
                {
                    Caption = 'Table';
                    Editable = false;
                    ApplicationArea = All;
                }

                field(PrimaryKeyDisplay; PrimaryKeyDisplay)
                {
                    Caption = 'Primary Key';
                    Editable = false;
                    ApplicationArea = All;
                }

                field(ChangeTypeDisplay; ChangeTypeDisplay)
                {
                    Caption = 'Change Type';
                    Editable = false;
                    ApplicationArea = All;
                }

                field(TimestampDisplay; TimestampDisplay)
                {
                    Caption = 'Timestamp';
                    Editable = false;
                    ApplicationArea = All;
                }
            }

            usercontrol(ComparisonViewer; "Data Debugger Record Comparison")
            {
                ApplicationArea = All;

                trigger OnFieldSelected(fieldInfo: Text)
                begin
                    HandleFieldSelection(fieldInfo);
                end;

                trigger OnViewRelatedRecords(relationInfo: Text)
                begin
                    HandleRelatedRecords(relationInfo);
                end;

                trigger OnExportReady(exportData: Text)
                begin
                    HandleExportData(exportData);
                end;

                trigger OnFiltersChanged(filterCriteria: Text)
                begin
                    HandleFilterChange(filterCriteria);
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LoadFromChangeBuffer)
            {
                Caption = 'Load Comparison';
                ToolTip = 'Load comparison data from the change buffer';
                Image = Import;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    LoadComparisonData();
                end;
            }

            action(RefreshView)
            {
                Caption = 'Refresh';
                ToolTip = 'Refresh the comparison view';
                Image = Refresh;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    RefreshComparisonView();
                end;
            }

            action(ExportComparison)
            {
                Caption = 'Export';
                ToolTip = 'Export comparison data';
                Image = Export;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    CurrPage.ComparisonViewer.ExportComparison('html');
                end;
            }

            action(ShowFieldDetails)
            {
                Caption = 'Field Details';
                ToolTip = 'Show detailed field comparison';
                Image = ViewDetails;
                ApplicationArea = All;
                Enabled = HasSelectedField;

                trigger OnAction()
                begin
                    ShowFieldDetailsPage();
                end;
            }
        }
    }

    var
        HasData: Boolean;
        HasSelectedField: Boolean;
        TableNameDisplay: Text[250];
        PrimaryKeyDisplay: Text[500];
        ChangeTypeDisplay: Text[20];
        TimestampDisplay: Text[50];
        SelectedFieldName: Text[100];
        SelectedFieldInfo: Text;
        CurrentOldData: Text;
        CurrentNewData: Text;
        CurrentMetadata: Text;

    trigger OnOpenPage()
    begin
        InitializePage();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        UpdateDisplayFields();
    end;

    local procedure InitializePage()
    var
        Config: JsonObject;
    begin
        // Initialize the control add-in
        Config.Add('title', 'Data Debugger - Record Comparison');
        Config.Add('theme', 'modern');
        Config.Add('enableDrillDown', true);

        CurrPage.ComparisonViewer.Initialize(Format(Config));

        HasData := false;
        HasSelectedField := false;
    end;

    local procedure UpdateDisplayFields()
    begin
        if Rec."Entry No." = 0 then begin
            HasData := false;
            exit;
        end;

        TableNameDisplay := Rec."Table Name";
        PrimaryKeyDisplay := Rec."Primary Key";
        ChangeTypeDisplay := Format(Rec."Change Type");
        TimestampDisplay := Format(Rec.Timestamp1, 0, '<Day,2>-<Month,2>-<Year4> <Hours24,2>:<Minutes,2>:<Seconds,2>');

        HasData := true;
        LoadComparisonFromCurrentRecord();
    end;

    local procedure LoadComparisonFromCurrentRecord()
    var
        OldDataText: Text;
        NewDataText: Text;
        Metadata: JsonObject;
        FieldsMetadata: JsonObject;
        TableMetadata: Record "Table Metadata";
        FieldMetadata: Record "Field";
    begin
        if Rec."Entry No." = 0 then
            exit;

        // Ensure BLOB fields are loaded
        Rec.CalcFields("Old Data", "New Data");

        OldDataText := Rec.GetOldData();
        NewDataText := Rec.GetNewData();
        CurrentOldData := OldDataText;
        CurrentNewData := NewDataText;

        // Build metadata for fields
        if TableMetadata.Get(Rec."Table ID") then begin
            FieldMetadata.SetRange(TableNo, Rec."Table ID");
            FieldMetadata.SetRange(ObsoleteState, FieldMetadata.ObsoleteState::No);
            if FieldMetadata.FindSet() then
                repeat
                    AddFieldMetadata(FieldsMetadata, FieldMetadata);
                until FieldMetadata.Next() = 0;
        end;

        Metadata.Add('tableName', Rec."Table Name");
        Metadata.Add('tableId', Rec."Table ID");
        Metadata.Add('primaryKey', Rec."Primary Key");
        Metadata.Add('changeType', Format(Rec."Change Type"));
        Metadata.Add('fields', FieldsMetadata);

        CurrentMetadata := Format(Metadata);

        // Load data into the control add-in
        CurrPage.ComparisonViewer.LoadComparison(OldDataText, NewDataText, CurrentMetadata);
    end;

    local procedure AddFieldMetadata(var FieldsMetadata: JsonObject; FieldRec: Record Field)
    var
        FieldInfo: JsonObject;
        TypeName: Text;
    begin
        // Convert field type to readable name
        case FieldRec.Type of
            FieldRec.Type::Boolean:
                TypeName := 'Boolean';
            FieldRec.Type::Integer:
                TypeName := 'Integer';
            FieldRec.Type::BigInteger:
                TypeName := 'BigInteger';
            FieldRec.Type::Decimal:
                TypeName := 'Decimal';
            FieldRec.Type::Text:
                TypeName := 'Text';
            FieldRec.Type::Code:
                TypeName := 'Code';
            FieldRec.Type::Date:
                TypeName := 'Date';
            FieldRec.Type::Time:
                TypeName := 'Time';
            FieldRec.Type::DateTime:
                TypeName := 'DateTime';
            FieldRec.Type::DateFormula:
                TypeName := 'DateFormula';
            FieldRec.Type::Option:
                TypeName := 'Option';
            FieldRec.Type::Blob:
                TypeName := 'Blob';
            FieldRec.Type::Media:
                TypeName := 'Media';
            FieldRec.Type::MediaSet:
                TypeName := 'MediaSet';
            FieldRec.Type::Guid:
                TypeName := 'GUID';
            else
                TypeName := 'Unknown';
        end;

        FieldInfo.Add('caption', FieldRec."Field Caption");
        FieldInfo.Add('type', TypeName);
        FieldInfo.Add('length', FieldRec.Len);
        FieldInfo.Add('tooltip', FieldRec."Field Caption");

        FieldsMetadata.Add(FieldRec.FieldName, FieldInfo);
    end;

    local procedure LoadComparisonData()
    var
        ChangeBuffer: Record "Data Debugger Change Buffer";
        ComparisonSelection: Page "DD Record Comparison Selection";
    begin
        ComparisonSelection.SetSourceTable(ChangeBuffer);
        if ComparisonSelection.RunModal() = Action::OK then begin
            ComparisonSelection.GetSelectedRecord(ChangeBuffer);
            if ChangeBuffer."Entry No." <> 0 then begin
                Rec := ChangeBuffer;
                CurrPage.Update(false);
            end;
        end;
    end;

    local procedure RefreshComparisonView()
    begin
        if HasData then
            LoadComparisonFromCurrentRecord();
    end;

    local procedure HandleFieldSelection(FieldInfoJson: Text)
    var
        FieldInfo: JsonObject;
        ActionToken: JsonToken;
        FieldNameToken: JsonToken;
        ActionText: Text;
    begin
        if not FieldInfo.ReadFrom(FieldInfoJson) then
            exit;

        if FieldInfo.Get('action', ActionToken) then
            ActionText := ActionToken.AsValue().AsText();

        if FieldInfo.Get('fieldName', FieldNameToken) then
            SelectedFieldName := FieldNameToken.AsValue().AsText();

        SelectedFieldInfo := FieldInfoJson;
        HasSelectedField := SelectedFieldName <> '';

        case ActionText of
            'drill-down':
                ShowFieldDetailsPage();
            'select':
                begin
                    Message('Field selected: %1', SelectedFieldName);
                    // Additional selection logic can be added here
                end;
        end;
    end;

    local procedure ShowFieldDetailsPage()
    var
        FieldDetailsPage: Page "DD Field Comparison Details";
    begin
        if (SelectedFieldName = '') or (SelectedFieldInfo = '') then begin
            Message('Please select a field first.');
            exit;
        end;

        FieldDetailsPage.SetFieldComparisonData(SelectedFieldName, SelectedFieldInfo, CurrentOldData, CurrentNewData, CurrentMetadata);
        FieldDetailsPage.RunModal();
    end;

    local procedure HandleRelatedRecords(RelationInfo: Text)
    begin
        // Handle related record viewing - can be extended
        Message('Related records functionality: %1', RelationInfo);
    end;

    local procedure HandleExportData(ExportData: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        FileManagement: Codeunit "File Management";
        OutStream: OutStream;
        FileName: Text;
    begin
        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(ExportData);

        FileName := StrSubstNo('RecordComparison_%1_%2.html', Rec."Table Name", Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2>_<Hours24><Minutes,2><Seconds,2>'));

        FileManagement.BLOBExport(TempBlob, FileName, true);
        Message('Comparison data exported successfully to %1', FileName);
    end;

    local procedure HandleFilterChange(FilterCriteria: Text)
    begin
        // Handle filter changes - can be used for logging or additional processing
    end;

    procedure SetComparisonRecord(var ChangeBuffer: Record "Data Debugger Change Buffer")
    begin
        Rec := ChangeBuffer;
        HasData := true;
        CurrPage.Update(false);
    end;
}
