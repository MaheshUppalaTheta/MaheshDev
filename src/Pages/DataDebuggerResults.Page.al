page 50001 "Data Debugger Results"
{
    Caption = 'Data Debugger Results';
    PageType = List;
    SourceTable = "Data Debugger Change Buffer";
    Editable = true;
    SourceTableTemporary = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Summary)
            {
                Caption = 'Session Summary';

                field(RunIdField; CurrentRunId)
                {
                    Caption = 'Run ID';
                    Editable = false;
                }

                field(StartTimeField; SessionStartTime)
                {
                    Caption = 'Started At';
                    Editable = false;
                }

                field(TotalChangesField; TotalChanges)
                {
                    Caption = 'Filtered Results';
                    Editable = false;
                    Style = Strong;
                }

                field(OriginalTotalField; OriginalTotal)
                {
                    Caption = 'Total Captured';
                    Editable = false;
                    Visible = HasActiveFilters;
                }
            }

            group(Filters)
            {
                Caption = 'Filters';

                field(TableFilterField; TableFilter)
                {
                    Caption = 'Table Filter';
                    ToolTip = 'Filter by table name (use * for wildcards)';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }

                field(ChangeTypeFilterField; ChangeTypeFilter)
                {
                    Caption = 'Change Type Filter';
                    ToolTip = 'Filter by change type';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }

                field(UserFilterField; UserFilter)
                {
                    Caption = 'User Filter';
                    ToolTip = 'Filter by user name';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }

                field(SearchTextField; SearchText)
                {
                    Caption = 'Search';
                    ToolTip = 'Search in table names, primary keys, and user names';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }

                field(TableTypeFilterField; TableTypeFilter)
                {
                    Caption = 'Table Type';
                    ToolTip = 'Filter by temporary tables, real tables, or show all';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }
            }

            repeater(Changes)
            {
                field("Table Name"; Rec."Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the table that was changed';
                }

                field("Change Type"; Rec."Change Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Type of change (Insert, Modify, Delete, Rename)';
                }

                field("Is Temporary Table"; Rec."Is Temporary Table")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if this change was made on a temporary table or real database table';
                }

                field(Timestamp; Rec.Timestamp1)
                {
                    ApplicationArea = All;
                    ToolTip = 'When the change occurred';
                }

                field("Primary Key"; Rec."Primary Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Primary key of the changed record';
                }

                field("Record Count"; Rec."Record Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of records changed';
                }

                field("User Name"; Rec."User Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'User who made the change';
                }

                field("Transaction ID"; Rec."Transaction ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Transaction that grouped this change';
                }

                field("Trigger Source"; Rec."Trigger Source")
                {
                    ApplicationArea = All;
                    ToolTip = 'What triggered this change';
                }

                field(ViewComparison; ViewComparisonText)
                {
                    ApplicationArea = All;
                    Caption = 'Record Comparison';
                    ToolTip = 'Click to open visual record comparison';
                    Editable = false;
                    Style = StandardAccent;
                    StyleExpr = true;

                    trigger OnDrillDown()
                    begin
                        OpenRecordComparison();
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewDetails)
            {
                Caption = 'View Field Changes';
                ToolTip = 'View detailed field-by-field changes for this record';
                Image = ViewDetails;
                ApplicationArea = all;
                trigger OnAction()
                var
                    FieldChangesPage: Page "Data Debugger Field Changes";
                begin
                    // CalcFields to load BLOB data before passing to the page
                    Rec.CalcFields("Old Data", "New Data");
                    FieldChangesPage.SetChangeRecord(Rec);
                    FieldChangesPage.RunModal();
                end;
            }

            action(GroupByTable)
            {
                Caption = 'Group by Table';
                ToolTip = 'Group results by table name';
                Image = Group;
                ApplicationArea = all;
                trigger OnAction()
                var
                    TableSummaryPage: Page "Data Debugger Table Summary";
                begin
                    TableSummaryPage.SetData(Rec, CurrentRunId);
                    TableSummaryPage.RunModal();
                end;
            }

            action(ViewCallStack)
            {
                Caption = 'View Call Stack';
                ToolTip = 'View detailed call stack and context information';
                Image = Info;
                ApplicationArea = all;
                trigger OnAction()
                var
                    ContextPage: Page "Data Debugger Context Details";
                begin
                    // CalcFields to load BLOB data before passing to the page
                    Rec.CalcFields("Call Stack");
                    ContextPage.SetChangeRecord(Rec);
                    ContextPage.RunModal();
                end;
            }

            action(GroupByTransaction)
            {
                Caption = 'Group by Transaction';
                ToolTip = 'Group changes by transaction to see related operations';
                Image = TransferOrder;
                ApplicationArea = all;
                trigger OnAction()
                var
                    TransactionPage: Page "Data Debugger Transactions";
                begin
                    TransactionPage.SetData(Rec, CurrentRunId);
                    TransactionPage.RunModal();
                end;
            }

            action(ExportToExcel)
            {
                Caption = 'Export to Excel';
                ToolTip = 'Export filtered results to Excel';
                Image = ExportToExcel;
                ApplicationArea = all;
                trigger OnAction()
                begin
                    ExportResultsToExcel();
                end;
            }

            action(ExportToJSON)
            {
                Caption = 'Export to JSON';
                ToolTip = 'Export filtered results to JSON format';
                Image = Export;
                ApplicationArea = all;
                trigger OnAction()
                begin
                    ExportResultsToJSON();
                end;
            }

            action(ClearFilters)
            {
                Caption = 'Clear Filters';
                ToolTip = 'Clear all filters and show all results';
                Image = ClearFilter;
                ApplicationArea = all;
                trigger OnAction()
                begin
                    ClearAllFilters();
                end;
            }

            action(AdvancedAnalysis)
            {
                Caption = 'Advanced Analysis';
                ToolTip = 'Perform advanced analysis on the captured data changes';
                Image = AnalysisView;
                ApplicationArea = all;
                trigger OnAction()
                var
                    AdvancedAnalysisPage: Page "DD Advanced Analysis";
                begin
                    AdvancedAnalysisPage.SetSourceData(Rec);
                    AdvancedAnalysisPage.RunModal();
                end;
            }
        }
    }

    var
        CurrentRunId: Guid;
        SessionStartTime: DateTime;
        TotalChanges: Integer;
        TableFilter: Text[50];
        ChangeTypeFilter: Option " ",Insert,Modify,Delete,Rename;
        UserFilter: Text[50];
        SearchText: Text[100];
        TableTypeFilter: Option " ","Real Tables Only","Temporary Tables Only";
        OriginalBuffer: Record "Data Debugger Change Buffer" temporary;
        OriginalTotal: Integer;
        HasActiveFilters: Boolean;
        ViewComparisonText: Text[30];

    trigger OnAfterGetRecord()
    begin
        ViewComparisonText := 'Click to View';
    end;

    procedure SetData(var TempBuffer: Record "Data Debugger Change Buffer" temporary; RunId: Guid; StartTime: DateTime)
    begin
        CurrentRunId := RunId;
        SessionStartTime := StartTime;

        // Clear both buffers
        Rec.Reset();
        Rec.DeleteAll();
        OriginalBuffer.Reset();
        OriginalBuffer.DeleteAll();

        // Copy data to both display and original buffers
        TempBuffer.Reset();
        if TempBuffer.FindSet() then
            repeat
                Rec := TempBuffer;
                Rec.Insert();
                OriginalBuffer := TempBuffer;
                OriginalBuffer.Insert();
            until TempBuffer.Next() = 0;

        TotalChanges := Rec.Count();
        OriginalTotal := OriginalBuffer.Count();
        HasActiveFilters := false;

        // Clear filters
        TableFilter := '';
        ChangeTypeFilter := ChangeTypeFilter::" ";
        UserFilter := '';
        SearchText := '';

        if Rec.FindFirst() then;
    end;

    local procedure ApplyFilters()
    var
        FilteredBuffer: Record "Data Debugger Change Buffer";
    begin
        Rec.Reset();
        Rec.DeleteAll();

        OriginalBuffer.Reset();
        if OriginalBuffer.FindSet() then begin
            repeat
                if MatchesFilters(OriginalBuffer) then begin
                    Rec := OriginalBuffer;
                    Rec.Insert();
                end;
            until OriginalBuffer.Next() = 0;
        end;

        TotalChanges := Rec.Count();
        HasActiveFilters := (TableFilter <> '') or (ChangeTypeFilter <> ChangeTypeFilter::" ") or (UserFilter <> '') or (SearchText <> '') or (TableTypeFilter <> TableTypeFilter::" ");
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure MatchesFilters(ChangeBuffer: Record "Data Debugger Change Buffer"): Boolean
    var
        ChangeTypeEnum: Enum "Data Debugger Change Type";
    begin
        // Table filter
        if TableFilter <> '' then
            if not (ChangeBuffer."Table Name".ToUpper().Contains(TableFilter.ToUpper().Replace('*', ''))) then
                exit(false);

        // Change type filter
        if ChangeTypeFilter <> ChangeTypeFilter::" " then begin
            case ChangeTypeFilter of
                ChangeTypeFilter::Insert:
                    if ChangeBuffer."Change Type" <> ChangeTypeEnum::Insert then
                        exit(false);
                ChangeTypeFilter::Modify:
                    if ChangeBuffer."Change Type" <> ChangeTypeEnum::Modify then
                        exit(false);
                ChangeTypeFilter::Delete:
                    if ChangeBuffer."Change Type" <> ChangeTypeEnum::Delete then
                        exit(false);
                ChangeTypeFilter::Rename:
                    if ChangeBuffer."Change Type" <> ChangeTypeEnum::Rename then
                        exit(false);
            end;
        end;

        // User filter
        if UserFilter <> '' then
            if not (ChangeBuffer."User Name".ToUpper().Contains(UserFilter.ToUpper())) then
                exit(false);

        // Table type filter
        if TableTypeFilter <> TableTypeFilter::" " then begin
            case TableTypeFilter of
                TableTypeFilter::"Real Tables Only":
                    if ChangeBuffer."Is Temporary Table" then
                        exit(false);
                TableTypeFilter::"Temporary Tables Only":
                    if not ChangeBuffer."Is Temporary Table" then
                        exit(false);
            end;
        end;

        // Search text (searches in table name, primary key, and user name)
        if SearchText <> '' then begin
            if not (ChangeBuffer."Table Name".ToUpper().Contains(SearchText.ToUpper()) or
                    ChangeBuffer."Primary Key".ToUpper().Contains(SearchText.ToUpper()) or
                    ChangeBuffer."User Name".ToUpper().Contains(SearchText.ToUpper())) then
                exit(false);
        end;

        exit(true);
    end;

    local procedure ClearAllFilters()
    begin
        TableFilter := '';
        ChangeTypeFilter := ChangeTypeFilter::" ";
        UserFilter := '';
        SearchText := '';
        TableTypeFilter := TableTypeFilter::" ";
        HasActiveFilters := false;
        ApplyFilters();
    end;

    local procedure ExportResultsToExcel()
    var
        ExcelBuffer: Record "Excel Buffer" temporary;
        TempBlob: Codeunit "Temp Blob";
        FileManagement: Codeunit "File Management";
        RowNo: Integer;
    begin
        ExcelBuffer.Reset();
        ExcelBuffer.DeleteAll();

        // Headers
        RowNo := 1;
        ExcelBuffer.NewRow();
        ExcelBuffer.AddColumn('Table Name', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Change Type', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Is Temporary', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Timestamp', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Primary Key', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('User Name', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Transaction ID', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Trigger Source', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);

        // Data rows
        if Rec.FindSet() then begin
            repeat
                ExcelBuffer.NewRow();
                ExcelBuffer.AddColumn(Rec."Table Name", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Format(Rec."Change Type"), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Format(Rec."Is Temporary Table"), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Format(Rec.Timestamp1), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Rec."Primary Key", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Rec."User Name", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Format(Rec."Transaction ID"), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Rec."Trigger Source", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
            until Rec.Next() = 0;
        end;

        ExcelBuffer.CreateNewBook('Data Debugger Results');
        ExcelBuffer.WriteSheet('Results', CompanyName(), UserId());
        ExcelBuffer.CloseBook();
        ExcelBuffer.SetFriendlyFilename('DataDebuggerResults_' + Format(CurrentRunId));
        ExcelBuffer.OpenExcel();

        Message('Results exported to Excel successfully.');
    end;

    local procedure ExportResultsToJSON()
    var
        JsonArray: JsonArray;
        JsonObject: JsonObject;
        JsonText: Text;
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
        FileName: Text;
    begin
        if Rec.FindSet() then begin
            repeat
                // CalcFields to load BLOB data
                Rec.CalcFields("Old Data", "New Data");

                Clear(JsonObject);
                JsonObject.Add('TableName', Rec."Table Name");
                JsonObject.Add('ChangeType', Format(Rec."Change Type"));
                JsonObject.Add('Timestamp', Format(Rec.Timestamp1, 0, 9));
                JsonObject.Add('PrimaryKey', Rec."Primary Key");
                JsonObject.Add('UserName', Rec."User Name");
                JsonObject.Add('TransactionId', Format(Rec."Transaction ID"));
                JsonObject.Add('TriggerSource', Rec."Trigger Source");
                JsonObject.Add('OldData', Rec.GetOldData());
                JsonObject.Add('NewData', Rec.GetNewData());
                JsonArray.Add(JsonObject);
            until Rec.Next() = 0;
        end;

        JsonArray.WriteTo(JsonText);

        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(JsonText);
        TempBlob.CreateInStream(InStream);

        FileName := StrSubstNo('DataDebuggerResults_%1.json', Format(CurrentRunId));
        DownloadFromStream(InStream, 'Export Results', '', 'JSON Files (*.json)|*.json', FileName);

        Message('Results exported to JSON successfully.');
    end;

    local procedure OpenRecordComparison()
    var
        RecordComparisonPage: Page "DD Record Comparison";
        TempChangeBuffer: Record "Data Debugger Change Buffer" temporary;
    begin
        if Rec."Entry No." = 0 then begin
            Message('No record selected for comparison.');
            exit;
        end;

        // CalcFields to load BLOB data before copying
        Rec.CalcFields("Old Data", "New Data");

        // Create a temporary record with the current record data
        TempChangeBuffer := Rec;
        TempChangeBuffer.Insert();

        // Open the record comparison page
        RecordComparisonPage.SetComparisonRecord(TempChangeBuffer);
        RecordComparisonPage.RunModal();
    end;
}