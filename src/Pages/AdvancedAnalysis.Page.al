page 72930458 "Advanced Analysis_TSA_TSL"
{
    Caption = 'Advanced Analysis';
    PageType = List;
    SourceTable = "Analysis Buffer_TSA_TSL";
    SourceTableTemporary = true;
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(Summary)
            {
                Caption = 'Analysis Summary';

                field(TotalIssuesField; TotalIssues)
                {
                    Caption = 'Total Issues';
                    Editable = false;
                    Style = Strong;
                    StyleExpr = TotalIssues > 0;
                }

                field(CriticalIssuesField; CriticalIssues)
                {
                    Caption = 'Critical Issues';
                    Editable = false;
                    Style = Unfavorable;
                    StyleExpr = CriticalIssues > 0;
                }

                field(WarningIssuesField; WarningIssues)
                {
                    Caption = 'Warnings';
                    Editable = false;
                    Style = Attention;
                    StyleExpr = WarningIssues > 0;
                }

                field(AnalysisTimeField; AnalysisTime)
                {
                    Caption = 'Analysis Time';
                    Editable = false;
                }
            }

            group(Filters)
            {
                Caption = 'Analysis Filters';

                field(AnalysisTypeFilterField; AnalysisTypeFilter)
                {
                    Caption = 'Analysis Type';
                    ToolTip = 'Filter by analysis type';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }

                field(SeverityFilterField; SeverityFilter)
                {
                    Caption = 'Severity Filter';
                    ToolTip = 'Filter by severity level';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }

                field(CategoryFilterField; CategoryFilter)
                {
                    Caption = 'Category Filter';
                    ToolTip = 'Filter by category';

                    trigger OnValidate()
                    begin
                        ApplyFilters();
                    end;
                }
            }

            repeater(Analysis)
            {
                field("Analysis Type"; Rec."Analysis Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Type of analysis performed';
                }

                field(Category; Rec.Category)
                {
                    ApplicationArea = All;
                    ToolTip = 'Analysis category';
                }

                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    ToolTip = 'Severity level of the finding';
                    Style = Unfavorable;
                    StyleExpr = Rec.Severity = Rec.Severity::Critical;
                }

                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Description of the analysis result';
                }

                field("Value Text"; Rec."Value Text")
                {
                    ApplicationArea = All;
                    ToolTip = 'Value or metric found';
                }

                field("Related Table Name"; Rec."Related Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Related table if applicable';
                }

                field("Analysis Timestamp"; Rec."Analysis Timestamp")
                {
                    ApplicationArea = All;
                    ToolTip = 'When this analysis was performed';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshAnalysis)
            {
                Caption = 'Refresh Analysis';
                ToolTip = 'Re-run the advanced analysis';
                Image = Refresh;
                ApplicationArea = all;

                trigger OnAction()
                begin
                    RunAnalysis();
                end;
            }

            action(ViewDetails)
            {
                Caption = 'View Details';
                ToolTip = 'View detailed information about this analysis result';
                Image = ViewDetails;
                ApplicationArea = all;

                trigger OnAction()
                begin
                    ViewAnalysisDetails();
                end;
            }

            action(ExportAnalysis)
            {
                Caption = 'Export Analysis';
                ToolTip = 'Export analysis results to Excel';
                Image = ExportToExcel;
                ApplicationArea = all;

                trigger OnAction()
                begin
                    ExportAnalysisToExcel();
                end;
            }

            action(ViewRecommendations)
            {
                Caption = 'Show Recommendations';
                ToolTip = 'Show recommendations based on analysis results';
                Image = Suggest;
                ApplicationArea = all;

                trigger OnAction()
                begin
                    ViewRecommendationDetails();
                end;
            }
        }
    }

    var
        SourceChangeBuffer: Record "Change Buffer_TSA_TSL" temporary;
        OriginalAnalysisBuffer: Record "Analysis Buffer_TSA_TSL" temporary;
        AnalysisEngine: Codeunit "Analysis Engine_TSA_TSL";
        TotalIssues: Integer;
        CriticalIssues: Integer;
        WarningIssues: Integer;
        AnalysisTime: Text;
        AnalysisTypeFilter: Option " ","Impact Analysis","Performance Metric","Pattern Detection","Relationship Mapping";
        SeverityFilter: Option " ","Info","Warning","Critical";
        CategoryFilter: Text[50];

    procedure SetSourceData(var ChangeBuffer: Record "Change Buffer_TSA_TSL")
    begin
        SourceChangeBuffer.Reset();
        SourceChangeBuffer.DeleteAll();

        ChangeBuffer.Reset();
        if ChangeBuffer.FindSet() then
            repeat
                SourceChangeBuffer := ChangeBuffer;
                SourceChangeBuffer.Insert();
            until ChangeBuffer.Next() = 0;

        RunAnalysis();
    end;

    local procedure RunAnalysis()
    var
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime();

        Rec.Reset();
        Rec.DeleteAll();
        OriginalAnalysisBuffer.Reset();
        OriginalAnalysisBuffer.DeleteAll();

        AnalysisEngine.AnalyzeChanges(SourceChangeBuffer, OriginalAnalysisBuffer);

        // Copy results to display buffer
        if OriginalAnalysisBuffer.FindSet() then
            repeat
                Rec := OriginalAnalysisBuffer;
                Rec.Insert();
            until OriginalAnalysisBuffer.Next() = 0;

        UpdateSummary();
        AnalysisTime := FormatElapsedTime(CurrentDateTime() - StartTime);

        ApplyFilters();
        CurrPage.Update(false);
    end;

    local procedure FormatElapsedTime(ElapsedDuration: Duration): Text
    var
        TotalSeconds: Integer;
        Hours: Integer;
        Minutes: Integer;
        Seconds: Integer;
    begin
        TotalSeconds := ElapsedDuration div 1000;
        Hours := TotalSeconds div 3600;
        Minutes := (TotalSeconds mod 3600) div 60;
        Seconds := TotalSeconds mod 60;
        exit(StrSubstNo('%1:%2:%3', PadZero(Hours), PadZero(Minutes), PadZero(Seconds)));
    end;

    local procedure PadZero(Value: Integer): Text
    begin
        if Value < 10 then
            exit('0' + Format(Value));
        exit(Format(Value));
    end;

    local procedure UpdateSummary()
    begin
        TotalIssues := 0;
        CriticalIssues := 0;
        WarningIssues := 0;

        OriginalAnalysisBuffer.Reset();
        if OriginalAnalysisBuffer.FindSet() then
            repeat
                TotalIssues += 1;
                case OriginalAnalysisBuffer.Severity of
                    OriginalAnalysisBuffer.Severity::Critical:
                        CriticalIssues += 1;
                    OriginalAnalysisBuffer.Severity::Warning:
                        WarningIssues += 1;
                end;
            until OriginalAnalysisBuffer.Next() = 0;
    end;

    local procedure ApplyFilters()
    var
        AnalysisTypeEnum: Option " ","Impact Analysis","Performance Metric","Pattern Detection","Relationship Mapping";
        SeverityEnum: Option " ","Info","Warning","Critical";
    begin
        Rec.Reset();
        Rec.DeleteAll();

        OriginalAnalysisBuffer.Reset();
        if OriginalAnalysisBuffer.FindSet() then begin
            repeat
                if MatchesFilters(OriginalAnalysisBuffer) then begin
                    Rec := OriginalAnalysisBuffer;
                    Rec.Insert();
                end;
            until OriginalAnalysisBuffer.Next() = 0;
        end;

        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure MatchesFilters(AnalysisRec: Record "Analysis Buffer_TSA_TSL"): Boolean
    begin
        // Analysis type filter
        if AnalysisTypeFilter <> AnalysisTypeFilter::" " then begin
            case AnalysisTypeFilter of
                AnalysisTypeFilter::"Impact Analysis":
                    if AnalysisRec."Analysis Type" <> AnalysisRec."Analysis Type"::"Impact Analysis" then
                        exit(false);
                AnalysisTypeFilter::"Performance Metric":
                    if AnalysisRec."Analysis Type" <> AnalysisRec."Analysis Type"::"Performance Metric" then
                        exit(false);
                AnalysisTypeFilter::"Pattern Detection":
                    if AnalysisRec."Analysis Type" <> AnalysisRec."Analysis Type"::"Pattern Detection" then
                        exit(false);
                AnalysisTypeFilter::"Relationship Mapping":
                    if AnalysisRec."Analysis Type" <> AnalysisRec."Analysis Type"::"Relationship Mapping" then
                        exit(false);
            end;
        end;

        // Severity filter
        if SeverityFilter <> SeverityFilter::" " then begin
            case SeverityFilter of
                SeverityFilter::Info:
                    if AnalysisRec.Severity <> AnalysisRec.Severity::Info then
                        exit(false);
                SeverityFilter::Warning:
                    if AnalysisRec.Severity <> AnalysisRec.Severity::Warning then
                        exit(false);
                SeverityFilter::Critical:
                    if AnalysisRec.Severity <> AnalysisRec.Severity::Critical then
                        exit(false);
            end;
        end;

        // Category filter
        if CategoryFilter <> '' then
            if not (AnalysisRec.Category.ToUpper().Contains(CategoryFilter.ToUpper())) then
                exit(false);

        exit(true);
    end;

    local procedure ViewAnalysisDetails()
    var
        DetailsText: Text;
    begin
        DetailsText := Rec.GetDetails();
        if DetailsText = '' then
            DetailsText := 'No additional details available for this analysis result.';

        Message('Analysis Details:\n\n%1\n\nDescription: %2\n\nValue: %3\n\nSeverity: %4',
                DetailsText, Rec.Description, Rec."Value Text", Format(Rec.Severity));
    end;

    local procedure ExportAnalysisToExcel()
    var
        ExcelBuffer: Record "Excel Buffer" temporary;
    begin
        ExcelBuffer.Reset();
        ExcelBuffer.DeleteAll();

        // Headers
        ExcelBuffer.NewRow();
        ExcelBuffer.AddColumn('Analysis Type', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Category', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Severity', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Description', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Value', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Related Table', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Timestamp', false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);

        // Data rows
        if Rec.FindSet() then begin
            repeat
                ExcelBuffer.NewRow();
                ExcelBuffer.AddColumn(Format(Rec."Analysis Type"), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Rec.Category, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Format(Rec.Severity), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Rec.Description, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Rec."Value Text", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Rec."Related Table Name", false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Format(Rec."Analysis Timestamp"), false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
            until Rec.Next() = 0;
        end;

        ExcelBuffer.CreateNewBook('Advanced Analysis Results');
        ExcelBuffer.WriteSheet('Analysis', CompanyName(), UserId());
        ExcelBuffer.CloseBook();
        ExcelBuffer.SetFriendlyFilename('TroubleshootingAssistanceAnalysis_' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2>_<Hours24><Minutes,2>'));
        ExcelBuffer.OpenExcel();

        Message('Analysis results exported to Excel successfully.');
    end;

    local procedure ViewRecommendationDetails()
    var
        Recommendations: TextBuilder;
        HasCritical: Boolean;
        HasWarnings: Boolean;
        HasHighVolume: Boolean;
    begin
        // Analyze current results and build recommendations
        OriginalAnalysisBuffer.Reset();
        if OriginalAnalysisBuffer.FindSet() then begin
            repeat
                case OriginalAnalysisBuffer.Severity of
                    OriginalAnalysisBuffer.Severity::Critical:
                        HasCritical := true;
                    OriginalAnalysisBuffer.Severity::Warning:
                        HasWarnings := true;
                end;

                if OriginalAnalysisBuffer.Category = 'High Volume Pattern' then
                    HasHighVolume := true;
            until OriginalAnalysisBuffer.Next() = 0;
        end;

        Recommendations.AppendLine('RECOMMENDATIONS BASED ON ANALYSIS:');
        Recommendations.AppendLine('');

        if HasCritical then begin
            Recommendations.AppendLine('🔴 CRITICAL ISSUES DETECTED:');
            Recommendations.AppendLine('- Review high-impact table operations immediately');
            Recommendations.AppendLine('- Consider implementing batch processing for bulk operations');
            Recommendations.AppendLine('- Monitor system performance during peak activity');
            Recommendations.AppendLine('');
        end;

        if HasWarnings then begin
            Recommendations.AppendLine('🟡 WARNINGS DETECTED:');
            Recommendations.AppendLine('- Review user activity patterns for optimization opportunities');
            Recommendations.AppendLine('- Consider implementing change throttling for high-frequency operations');
            Recommendations.AppendLine('- Monitor transaction sizes and duration');
            Recommendations.AppendLine('');
        end;

        if HasHighVolume then begin
            Recommendations.AppendLine('📊 HIGH VOLUME PATTERNS:');
            Recommendations.AppendLine('- Implement change log archiving for high-volume tables');
            Recommendations.AppendLine('- Consider performance optimization for frequently changed tables');
            Recommendations.AppendLine('- Review indexing strategy for affected tables');
            Recommendations.AppendLine('');
        end;

        Recommendations.AppendLine('💡 GENERAL RECOMMENDATIONS:');
        Recommendations.AppendLine('- Regular monitoring of change patterns');
        Recommendations.AppendLine('- Implement automated alerts for unusual activity');
        Recommendations.AppendLine('- Consider change impact analysis before major operations');
        Recommendations.AppendLine('- Regular performance baseline reviews');

        Message(Recommendations.ToText());
    end;
}
