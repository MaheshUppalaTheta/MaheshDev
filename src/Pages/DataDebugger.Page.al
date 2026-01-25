page 50000 "Data Debugger"
{
    Caption = 'Data Debugger';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;

    layout
    {
        area(Content)
        {
            group(Control)
            {
                Caption = 'Recording Control';

                field(StatusField; StatusText)
                {
                    Caption = 'Status';
                    Editable = false;
                    Style = Strong;
                    StyleExpr = StatusText = 'RECORDING';
                }

                field(RunIdField; CurrentRunIdText)
                {
                    Caption = 'Current Run ID';
                    Editable = false;
                }
            }

            group(LiveStats)
            {
                Caption = 'Live Statistics';
                Visible = StatusText = 'RECORDING';

                field(TotalChangesField; TotalChangesCount)
                {
                    Caption = 'Total Changes';
                    Editable = false;
                    Style = Strong;
                }

                field(ChangesPerSecondField; ChangesPerSecond)
                {
                    Caption = 'Changes/Second';
                    Editable = false;
                }

                field(RecordingDurationField; RecordingDuration)
                {
                    Caption = 'Recording Duration';
                    Editable = false;
                }

                field(LastCaptureField; LastCaptureInfo)
                {
                    Caption = 'Last Capture';
                    Editable = false;
                }
            }

            group(Instructions)
            {
                Caption = 'Instructions';

                field(InstructionText; InstructionLabel)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Setup)
            {
                Caption = 'Setup';
                ToolTip = 'Configure filtering and performance options';
                Image = Setup;

                trigger OnAction()
                var
                    SetupPage: Page "Data Debugger Setup";

                begin

                    SetupPage.RunModal();

                end;
            }

            action(StartRecording)
            {
                Caption = 'Start Recording';
                ToolTip = 'Start recording database changes';
                Image = Start;

                trigger OnAction()
                begin
                    BindSubscription(DDEventHandler);
                    SessionManager.StartRecording();
                    UpdateStatus();
                    UpdateLiveStats();
                end;
            }

            action(RefreshStats)
            {
                Caption = 'Refresh Stats';
                ToolTip = 'Refresh live statistics';
                Image = Refresh;
                Visible = StatusText = 'RECORDING';

                trigger OnAction()
                begin
                    UpdateLiveStats();
                end;
            }

            action(StopRecording)
            {
                Caption = 'Stop Recording';
                ToolTip = 'Stop recording and view results';
                Image = Stop;

                trigger OnAction()
                begin
                    SessionManager.StopRecording();
                    UpdateStatus();
                    UnbindSubscription(DDEventHandler);
                end;
            }

            action(ViewLiveAnalysis)
            {
                Caption = 'Live Analysis';
                ToolTip = 'View live statistics and advanced analysis of current session';
                Image = Statistics;

                trigger OnAction()
                var
                    LiveStatsPage: Page "Data Debugger Live Stats";
                begin
                    LiveStatsPage.RunModal();
                end;
            }
        }
    }

    var
        SessionManager: Codeunit "Data Debugger Session Manager";
        DDEventHandler: Codeunit "Data Debugger Event Handlers";
        StatusText: Text;
        CurrentRunIdText: Text;
        TotalChangesCount: Integer;
        ChangesPerSecond: Decimal;
        RecordingDuration: Text;
        LastCaptureInfo: Text;

        InstructionLabel: Label 'Click "Start Recording" to begin capturing database changes. Perform your business process, then click "Stop Recording" to view the results. All captured data is temporary and will be discarded when you close the results page.';

    trigger OnOpenPage()
    begin
        UpdateStatus();
    end;

    local procedure UpdateStatus()
    begin
        if SessionManager.IsActive() then begin
            StatusText := 'RECORDING';
            CurrentRunIdText := Format(SessionManager.GetCurrentRunId());
        end else begin
            StatusText := 'STOPPED';
            CurrentRunIdText := '';
            ClearLiveStats();
        end;
    end;

    local procedure UpdateLiveStats()
    var
        Stats: Record "Data Debugger Live Stats";
    begin
        if not SessionManager.IsActive() then begin
            ClearLiveStats();
            exit;
        end;

        Stats := SessionManager.GetLiveStatistics();
        TotalChangesCount := Stats."Total Changes";
        ChangesPerSecond := Stats."Changes Per Second";
        RecordingDuration := Stats."Duration Text";
        LastCaptureInfo := Stats."Last Capture Info";

        CurrPage.Update(false);
    end;

    local procedure ClearLiveStats()
    begin
        TotalChangesCount := 0;
        ChangesPerSecond := 0;
        RecordingDuration := '';
        LastCaptureInfo := '';
    end;
}
