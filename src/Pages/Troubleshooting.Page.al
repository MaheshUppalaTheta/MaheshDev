page 72930450 "Troubleshooting_TSA_TSL"
{
    Caption = 'Troubleshooting Assistance';
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

                field(RecordUserField; RecordUserId)
                {
                    Caption = 'Record User';
                    ToolTip = 'Select the user whose database operations will be captured. Only this user''s changes are recorded; everyone else is ignored. Defaults to you.';
                    Editable = StatusText <> 'RECORDING';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        User: Record User;
                        Users: Page "Users";
                    begin
                        Users.LookupMode(true);
                        if Users.RunModal() <> Action::LookupOK then
                            exit(false);

                        Users.GetRecord(User);
                        SetRecordUser(User);
                        Text := RecordUserId;
                        exit(true);
                    end;

                    trigger OnValidate()
                    var
                        User: Record User;
                    begin
                        if RecordUserId = '' then begin
                            Clear(RecordUserSecurityId);
                            RecordUserName := '';
                            exit;
                        end;

                        User.SetRange("User Name", RecordUserId);
                        if not User.FindFirst() then
                            Error('User ''%1'' was not found. Use the lookup to pick a valid user.', RecordUserId);
                        SetRecordUser(User);
                    end;
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
                    SetupPage: Page "Setup_TSA_TSL";

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
                    if IsNullGuid(RecordUserSecurityId) then
                        Error('Select a user in "Record User" before starting.');

                    SessionManager.StartRecording(RecordUserSecurityId, RecordUserId, RecordUserName);
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
                end;
            }
            action(ClearData)
            {
                Caption = 'Clear Captured Data';
                ToolTip = 'Delete all previously captured change entries before starting a new recording. Cannot be undone.';
                Image = Delete;
                Enabled = StatusText <> 'RECORDING';

                trigger OnAction()
                begin
                    if not Confirm('Delete all captured change entries? This cannot be undone.', false) then
                        exit;

                    SessionManager.ClearCapturedData();
                    UpdateStatus();
                    Message('Captured data cleared.');
                end;
            }

            action(ViewResults)
            {
                Caption = 'View All Results';
                ToolTip = 'Open the main results page';
                Image = View;

                trigger OnAction()
                var
                    SessionManager: Codeunit "Session Manager_TSA_TSL";
                begin
                    SessionManager.ShowResults();
                end;
            }

            action(ViewLiveAnalysis)
            {
                Caption = 'Live Analysis';
                ToolTip = 'View live statistics and advanced analysis of current session';
                Image = Statistics;

                trigger OnAction()
                var
                    LiveStatsPage: Page "Live Stats_TSA_TSL";
                begin
                    LiveStatsPage.RunModal();
                end;
            }

            action(CreateAgent)
            {
                Caption = 'Create Troubleshooting Assistance Agent';
                ToolTip = 'Create and activate the Troubleshooting Assistance Agent. Requires the Troubleshooting Assistance Agent Copilot capability to be enabled and billing configured.';
                Image = Sparkle;

                trigger OnAction()
                var
                    AgentProvision: Codeunit "Agent Provision_TSA_TSL";
                begin
                    if not Confirm('Create and activate the Troubleshooting Assistance Agent now?', false) then
                        exit;
                    AgentProvision.CreateTroubleshootingAgent();
                end;
            }
        }
    }

    var
        SessionManager: Codeunit "Session Manager_TSA_TSL";
        StatusText: Text;
        CurrentRunIdText: Text;
        RecordUserId: Code[50];
        RecordUserName: Text[80];
        RecordUserSecurityId: Guid;
        TotalChangesCount: Integer;
        ChangesPerSecond: Decimal;
        RecordingDuration: Text;
        LastCaptureInfo: Text;

        InstructionLabel: Label 'Select the user to record in "Record User" (defaults to you), then click "Start Recording". Only that user''s database operations are captured, anywhere in Business Central, subject to the table and field filters in Setup. Perform the business process as that user, then click "Stop Recording" to view the results. Captured data is persisted and is cleared when the next recording starts.';

    trigger OnOpenPage()
    var
        User: Record User;
    begin
        // Default the recorded user to the current user.
        if User.Get(UserSecurityId()) then
            SetRecordUser(User)
        else begin
            RecordUserId := CopyStr(UserId(), 1, MaxStrLen(RecordUserId));
            RecordUserSecurityId := UserSecurityId();
            RecordUserName := CopyStr(UserId(), 1, MaxStrLen(RecordUserName));
        end;

        UpdateStatus();
    end;

    local procedure SetRecordUser(User: Record User)
    begin
        RecordUserId := User."User Name";
        RecordUserSecurityId := User."User Security ID";
        if User."Full Name" <> '' then
            RecordUserName := CopyStr(User."Full Name", 1, MaxStrLen(RecordUserName))
        else
            RecordUserName := CopyStr(User."User Name", 1, MaxStrLen(RecordUserName));
    end;

    local procedure UpdateStatus()
    begin
        if SessionManager.IsActive() then begin
            StatusText := 'RECORDING';
            CurrentRunIdText := Format(SessionManager.GetCurrentRunId());
            // Reflect the user actually being recorded (set when the run started).
            RecordUserId := SessionManager.GetRecordingUserId();
        end else begin
            StatusText := 'STOPPED';
            CurrentRunIdText := '';
            ClearLiveStats();
        end;
    end;

    local procedure UpdateLiveStats()
    var
        Stats: Record "Live Stats_TSA_TSL";
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
