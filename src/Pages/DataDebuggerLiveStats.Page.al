page 50009 "Data Debugger Live Stats"
{
    Caption = 'Live Statistics';
    PageType = Card;
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(LiveMetrics)
            {
                Caption = 'Current Session Metrics';

                field(TotalChangesField; TotalChanges)
                {
                    Caption = 'Total Changes Captured';
                    ToolTip = 'Total number of database changes captured in current session';
                    Style = Strong;
                    StyleExpr = true;
                }

                field(ChangesPerMinuteField; ChangesPerMinute)
                {
                    Caption = 'Changes Per Minute';
                    ToolTip = 'Average number of changes per minute';
                }

                field(MostActiveTableField; MostActiveTable)
                {
                    Caption = 'Most Active Table';
                    ToolTip = 'Table with the highest number of changes';
                }

                field(ActiveUsersField; ActiveUsers)
                {
                    Caption = 'Active Users';
                    ToolTip = 'Number of users making changes';
                }

                field(SessionDurationField; SessionDuration)
                {
                    Caption = 'Session Duration';
                    ToolTip = 'How long the current session has been running';
                }

                field(LastActivityField; LastActivity)
                {
                    Caption = 'Last Activity';
                    ToolTip = 'When the last change was captured';
                }
            }

            group(QuickActions)
            {
                Caption = 'Quick Actions';

                field(AutoRefreshField; AutoRefresh)
                {
                    Caption = 'Auto Refresh (30s)';
                    ToolTip = 'Automatically refresh statistics every 30 seconds';

                    trigger OnValidate()
                    begin
                        if AutoRefresh then
                            RefreshData()
                        else
                            CurrPage.Update(false);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshStats)
            {
                Caption = 'Refresh';
                ToolTip = 'Refresh current statistics';
                Image = Refresh;

                trigger OnAction()
                begin
                    RefreshData();
                end;
            }

            action(ViewDetailedAnalysis)
            {
                Caption = 'Detailed Analysis';
                ToolTip = 'Open advanced analysis of captured data';
                Image = AnalysisView;

                trigger OnAction()
                var
                    ChangeBuffer: Record "Data Debugger Change Buffer" temporary;
                    SessionManager: Codeunit "Data Debugger Session Manager";
                    AnalysisPage: Page "DD Advanced Analysis";
                begin
                    SessionManager.GetCurrentSessionData(ChangeBuffer);
                    AnalysisPage.SetSourceData(ChangeBuffer);
                    AnalysisPage.RunModal();
                end;
            }


        }
    }

    var
        TotalChanges: Integer;
        ChangesPerMinute: Decimal;
        MostActiveTable: Text[100];
        ActiveUsers: Integer;
        SessionDuration: Text[50];
        LastActivity: Text[50];
        AutoRefresh: Boolean;

    trigger OnOpenPage()
    begin
        RefreshData();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        if AutoRefresh then
            RefreshData();
    end;

    local procedure RefreshData()
    var
        ChangeBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        TableCounts: Dictionary of [Integer, Integer];
        UserCounts: Dictionary of [Text, Integer];
        MaxCount: Integer;
        MaxTableId: Integer;
        TableName: Text[100];
        StartTime: DateTime;
        CurrentTime: DateTime;
        ElapsedMinutes: Decimal;
        LastChangeTime: DateTime;
        UserCount: Integer;
        TempTableId: Integer;
        TempCount: Integer;
        TempUser: Text;
        Keys: List of [Integer];
        UserKeys: List of [Text];
    begin
        // Get session data
        SessionManager.GetCurrentSessionData(ChangeBuffer);

        // Calculate metrics
        TotalChanges := 0;
        MaxCount := 0;
        MaxTableId := 0;
        LastChangeTime := 0DT;

        if ChangeBuffer.FindSet() then begin
            repeat
                TotalChanges += 1;

                // Track table activity
                if TableCounts.ContainsKey(ChangeBuffer."Table ID") then
                    TableCounts.Set(ChangeBuffer."Table ID", TableCounts.Get(ChangeBuffer."Table ID") + 1)
                else
                    TableCounts.Add(ChangeBuffer."Table ID", 1);

                // Track user activity
                if UserCounts.ContainsKey(ChangeBuffer."User ID") then
                    UserCounts.Set(ChangeBuffer."User ID", UserCounts.Get(ChangeBuffer."User ID") + 1)
                else
                    UserCounts.Add(ChangeBuffer."User ID", 1);

                // Track last activity
                if ChangeBuffer.Timestamp1 > LastChangeTime then
                    LastChangeTime := ChangeBuffer.Timestamp1;

            until ChangeBuffer.Next() = 0;
        end;

        // Find most active table
        Keys := TableCounts.Keys();
        foreach TempTableId in Keys do begin
            TempCount := TableCounts.Get(TempTableId);
            if TempCount > MaxCount then begin
                MaxCount := TempCount;
                MaxTableId := TempTableId;
            end;
        end;

        if MaxTableId > 0 then begin
            if MaxTableId >= 50000 then
                MostActiveTable := 'Custom Table (' + Format(MaxTableId) + ')'
            else
                MostActiveTable := 'System Table (' + Format(MaxTableId) + ')';
        end else
            MostActiveTable := 'None';

        // Count active users
        UserKeys := UserCounts.Keys();
        ActiveUsers := UserKeys.Count();

        // Calculate duration and rate
        StartTime := SessionManager.GetSessionStartTime();
        if StartTime <> 0DT then begin
            CurrentTime := CurrentDateTime();
            ElapsedMinutes := (CurrentTime - StartTime) / 60000;
            SessionDuration := Format(Round(ElapsedMinutes, 1)) + ' minutes';

            if ElapsedMinutes > 0 then
                ChangesPerMinute := Round(TotalChanges / ElapsedMinutes, 0.1)
            else
                ChangesPerMinute := 0;
        end else begin
            SessionDuration := 'Not started';
            ChangesPerMinute := 0;
        end;

        // Format last activity
        if LastChangeTime <> 0DT then
            LastActivity := Format(LastChangeTime, 0, '<Hours24,2>:<Minutes,2>:<Seconds,2>')
        else
            LastActivity := 'None';

        CurrPage.Update(false);
    end;
}
