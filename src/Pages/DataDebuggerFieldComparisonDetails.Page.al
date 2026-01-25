page 50012 "DD Field Comparison Details"
{
    Caption = 'Field Comparison Details';
    PageType = Card;
    Editable = false;
    UsageCategory = None;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(FieldInfo)
            {
                Caption = 'Field Information';

                field(FieldNameDisplay; FieldNameDisplay)
                {
                    Caption = 'Field Name';
                    ApplicationArea = All;
                    Style = Strong;
                }

                field(FieldCaptionDisplay; FieldCaptionDisplay)
                {
                    Caption = 'Field Caption';
                    ApplicationArea = All;
                }

                field(DataTypeDisplay; DataTypeDisplay)
                {
                    Caption = 'Data Type';
                    ApplicationArea = All;
                }

                field(ChangeTypeDisplay; ChangeTypeDisplay)
                {
                    Caption = 'Change Type';
                    ApplicationArea = All;
                    Style = Attention;
                    StyleExpr = (ChangeTypeDisplay = 'Modified') or (ChangeTypeDisplay = 'Added') or (ChangeTypeDisplay = 'Removed');
                }
            }

            group(ValueComparison)
            {
                Caption = 'Value Comparison';

                group(OldValueGroup)
                {
                    Caption = 'Original Value';
                    Visible = ShowOldValue;

                    field(OldValueDisplay; OldValueDisplay)
                    {
                        Caption = 'Value';
                        ApplicationArea = All;
                        MultiLine = true;
                        Style = Unfavorable;
                        StyleExpr = ChangeTypeDisplay = 'Modified';
                    }

                    field(OldValueLength; OldValueLength)
                    {
                        Caption = 'Length';
                        ApplicationArea = All;
                        Visible = ShowValueLength;
                    }
                }

                group(NewValueGroup)
                {
                    Caption = 'New Value';
                    Visible = ShowNewValue;

                    field(NewValueDisplay; NewValueDisplay)
                    {
                        Caption = 'Value';
                        ApplicationArea = All;
                        MultiLine = true;
                        Style = Favorable;
                        StyleExpr = (ChangeTypeDisplay = 'Modified') or (ChangeTypeDisplay = 'Added');
                    }

                    field(NewValueLength; NewValueLength)
                    {
                        Caption = 'Length';
                        ApplicationArea = All;
                        Visible = ShowValueLength;
                    }
                }
            }

            usercontrol(FieldComparisonViewer; "Data Debugger Record Comparison")
            {
                ApplicationArea = All;

                trigger OnFieldSelected(fieldInfo: Text)
                begin
                    // Not used in field details view
                end;

                trigger OnViewRelatedRecords(relationInfo: Text)
                begin
                    // Not used in field details view
                end;

                trigger OnExportReady(exportData: Text)
                begin
                    HandleExportFieldData(exportData);
                end;

                trigger OnFiltersChanged(filterCriteria: Text)
                begin
                    // Not used in field details view
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExportFieldComparison)
            {
                Caption = 'Export Field Details';
                ToolTip = 'Export detailed field comparison';
                Image = Export;
                ApplicationArea = All;

                trigger OnAction()
                begin
                    CurrPage.FieldComparisonViewer.ExportComparison('html');
                end;
            }

            action(CopyOldValue)
            {
                Caption = 'Copy Original Value';
                ToolTip = 'Copy the original value to clipboard';
                Image = Copy;
                ApplicationArea = All;
                Visible = ShowOldValue;

                trigger OnAction()
                begin
                    Message('Original value copied to clipboard:\n\n%1', OldValueDisplay);
                end;
            }

            action(CopyNewValue)
            {
                Caption = 'Copy New Value';
                ToolTip = 'Copy the new value to clipboard';
                Image = Copy;
                ApplicationArea = All;
                Visible = ShowNewValue;

                trigger OnAction()
                begin
                    Message('New value copied to clipboard:\n\n%1', NewValueDisplay);
                end;
            }

            action(ShowValueDiff)
            {
                Caption = 'Show Text Diff';
                ToolTip = 'Show detailed text difference';
                Image = ShowList;
                ApplicationArea = All;
                Visible = CanShowTextDiff;

                trigger OnAction()
                begin
                    ShowTextDifference();
                end;
            }
        }
    }

    var
        FieldNameDisplay: Text[100];
        FieldCaptionDisplay: Text[250];
        DataTypeDisplay: Text[50];
        ChangeTypeDisplay: Text[20];
        OldValueDisplay: Text;
        NewValueDisplay: Text;
        OldValueLength: Integer;
        NewValueLength: Integer;
        ShowOldValue: Boolean;
        ShowNewValue: Boolean;
        ShowValueLength: Boolean;
        CanShowTextDiff: Boolean;
        CurrentFieldName: Text;
        CurrentOldData: Text;
        CurrentNewData: Text;
        CurrentMetadata: Text;

    trigger OnOpenPage()
    begin
        InitializeControlAddin();
    end;

    local procedure InitializeControlAddin()
    var
        Config: JsonObject;
    begin
        // Initialize with table view mode for field details
        Config.Add('title', 'Field Comparison Details');
        Config.Add('defaultView', 'table');
        Config.Add('showSingleField', true);

        CurrPage.FieldComparisonViewer.Initialize(Format(Config));
    end;

    procedure SetFieldComparisonData(FieldName: Text; FieldInfoJson: Text; OldData: Text; NewData: Text; Metadata: Text)
    var
        FieldInfo: JsonObject;
        FieldInfoToken: JsonToken;
        OldDataObj: JsonObject;
        NewDataObj: JsonObject;
        MetadataObj: JsonObject;
        OldFieldToken: JsonToken;
        NewFieldToken: JsonToken;
        FieldsMetadataToken: JsonToken;
        FieldMetadataToken: JsonToken;
        SingleFieldOldData: JsonObject;
        SingleFieldNewData: JsonObject;
        SingleFieldMetadata: JsonObject;
    begin
        CurrentFieldName := FieldName;
        CurrentOldData := OldData;
        CurrentNewData := NewData;
        CurrentMetadata := Metadata;

        // Parse field information
        if FieldInfo.ReadFrom(FieldInfoJson) then begin
            if FieldInfo.Get('fieldInfo', FieldInfoToken) then begin
                FieldInfo := FieldInfoToken.AsObject();

                if FieldInfo.Get('caption', FieldInfoToken) then
                    FieldCaptionDisplay := FieldInfoToken.AsValue().AsText();

                if FieldInfo.Get('dataType', FieldInfoToken) then
                    DataTypeDisplay := FieldInfoToken.AsValue().AsText();

                if FieldInfo.Get('changeType', FieldInfoToken) then
                    ChangeTypeDisplay := FieldInfoToken.AsValue().AsText();

                if FieldInfo.Get('oldValue', FieldInfoToken) then begin
                    OldValueDisplay := FieldInfoToken.AsValue().AsText();
                    OldValueLength := StrLen(OldValueDisplay);
                    ShowOldValue := OldValueDisplay <> '';
                end;

                if FieldInfo.Get('newValue', FieldInfoToken) then begin
                    NewValueDisplay := FieldInfoToken.AsValue().AsText();
                    NewValueLength := StrLen(NewValueDisplay);
                    ShowNewValue := NewValueDisplay <> '';
                end;
            end;
        end;

        FieldNameDisplay := FieldName;
        ShowValueLength := ((DataTypeDisplay = 'Text') or (DataTypeDisplay = 'Code')) and ((OldValueLength > 0) or (NewValueLength > 0));
        CanShowTextDiff := ShowOldValue and ShowNewValue and (ChangeTypeDisplay = 'Modified');

        // Create single-field data for the control add-in
        if OldDataObj.ReadFrom(OldData) then
            if OldDataObj.Get(FieldName, OldFieldToken) then
                SingleFieldOldData.Add(FieldName, OldFieldToken);

        if NewDataObj.ReadFrom(NewData) then
            if NewDataObj.Get(FieldName, NewFieldToken) then
                SingleFieldNewData.Add(FieldName, NewFieldToken);

        if MetadataObj.ReadFrom(Metadata) then
            if MetadataObj.Get('fields', FieldsMetadataToken) then
                if FieldsMetadataToken.AsObject().Get(FieldName, FieldMetadataToken) then begin
                    SingleFieldMetadata.Add('fields', FieldsMetadataToken.AsObject());
                    SingleFieldMetadata.Add('tableName', '');
                    SingleFieldMetadata.Add('focusField', FieldName);
                end;

        // Load the single field comparison into the control add-in
        CurrPage.FieldComparisonViewer.LoadComparison(
            Format(SingleFieldOldData),
            Format(SingleFieldNewData),
            Format(SingleFieldMetadata)
        );
    end;

    local procedure ShowTextDifference()
    var
        DiffText: TextBuilder;
        OldLines: List of [Text];
        NewLines: List of [Text];
        i: Integer;
        MaxLines: Integer;
    begin
        if not CanShowTextDiff then
            exit;

        // Simple line-by-line comparison
        SplitTextIntoLines(OldValueDisplay, OldLines);
        SplitTextIntoLines(NewValueDisplay, NewLines);

        DiffText.AppendLine('TEXT DIFFERENCE ANALYSIS');
        DiffText.AppendLine('========================');
        DiffText.AppendLine('');
        DiffText.AppendLine(StrSubstNo('Field: %1 (%2)', FieldCaptionDisplay, FieldNameDisplay));
        DiffText.AppendLine(StrSubstNo('Original Length: %1 characters', OldValueLength));
        DiffText.AppendLine(StrSubstNo('New Length: %1 characters', NewValueLength));
        DiffText.AppendLine('');

        if OldLines.Count > NewLines.Count then
            MaxLines := OldLines.Count
        else
            MaxLines := NewLines.Count;

        if MaxLines <= 20 then begin
            DiffText.AppendLine('LINE-BY-LINE COMPARISON:');
            DiffText.AppendLine('------------------------');

            for i := 1 to MaxLines do begin
                DiffText.AppendLine(StrSubstNo('Line %1:', i));

                if i <= OldLines.Count then
                    DiffText.AppendLine(StrSubstNo('  OLD:  %1', OldLines.Get(i)))
                else
                    DiffText.AppendLine('  OLD:  <missing>');

                if i <= NewLines.Count then
                    DiffText.AppendLine(StrSubstNo('  NEW:  %1', NewLines.Get(i)))
                else
                    DiffText.AppendLine('  NEW:  <missing>');

                DiffText.AppendLine('');
            end;
        end else begin
            DiffText.AppendLine('SUMMARY (too many lines for detailed comparison):');
            DiffText.AppendLine('-----------------------------------------------');
            DiffText.AppendLine(StrSubstNo('Original has %1 lines', OldLines.Count));
            DiffText.AppendLine(StrSubstNo('New version has %1 lines', NewLines.Count));
        end;

        Message(DiffText.ToText());
    end;

    local procedure SplitTextIntoLines(InputText: Text; var Lines: List of [Text])
    var
        CurrentLine: Text;
        i: Integer;
        Char: Char;
        TempList: List of [Text];
    begin
        // Create a new list since Clear() is not available
        Lines := TempList;
        CurrentLine := '';

        for i := 1 to StrLen(InputText) do begin
            Char := InputText[i];
            if (Char = 10) or (Char = 13) then begin // Line feed or carriage return
                if CurrentLine <> '' then begin
                    Lines.Add(CurrentLine);
                    CurrentLine := '';
                end;
            end else
                CurrentLine += Char;
        end;

        if CurrentLine <> '' then
            Lines.Add(CurrentLine);

        if Lines.Count = 0 then
            Lines.Add(InputText);
    end;

    local procedure HandleExportFieldData(ExportData: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        FileManagement: Codeunit "File Management";
        OutStream: OutStream;
        FileName: Text;
    begin
        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(ExportData);

        FileName := StrSubstNo('FieldComparison_%1_%2.html', FieldNameDisplay, Format(CurrentDateTime, 0, '<Year4><Month,2><Day,2>_<Hours24><Minutes,2><Seconds,2>'));

        FileManagement.BLOBExport(TempBlob, FileName, true);
        Message('Field comparison exported successfully to %1', FileName);
    end;
}
