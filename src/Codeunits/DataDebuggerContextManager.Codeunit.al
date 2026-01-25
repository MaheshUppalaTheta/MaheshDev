codeunit 50003 "Data Debugger Context Manager"
{
    SingleInstance = true;

    var
        CurrentTransactionId: Guid;
        TransactionStartTime: DateTime;
        TransactionChangeCount: Integer;

    procedure CaptureUserContext(var ChangeBuffer: Record "Data Debugger Change Buffer")
    var
        UserSetup: Record "User Setup";
        User: Record User;
    begin
        // Basic user information
        ChangeBuffer."User ID" := UserId();
        ChangeBuffer."Company Name" := CompanyName();
        ChangeBuffer."Session ID" := SessionId();

        // Get user name
        if User.Get(UserSecurityId()) then
            ChangeBuffer."User Name" := User."Full Name"
        else
            ChangeBuffer."User Name" := UserId();

        // Get client type
        ChangeBuffer."Client Type" := GetClientType();
    end;

    procedure CaptureTransactionContext(var ChangeBuffer: Record "Data Debugger Change Buffer")
    begin
        // Initialize transaction if not started
        if IsNullGuid(CurrentTransactionId) then
            StartNewTransaction();

        ChangeBuffer."Transaction ID" := CurrentTransactionId;
        TransactionChangeCount += 1;

        // Auto-reset transaction after timeout or too many changes
        if (CurrentDateTime() - TransactionStartTime > 30000) or (TransactionChangeCount > 1000) then
            StartNewTransaction();
    end;

    procedure CaptureCallStack(var ChangeBuffer: Record "Data Debugger Change Buffer")
    var
        CallStackText: Text;
        TriggerSource: Text;
    begin
        // Build call stack information
        CallStackText := BuildCallStackInfo();
        ChangeBuffer.SetCallStack(CallStackText);

        // Extract trigger source (simplified)
        TriggerSource := ExtractTriggerSource(CallStackText);
        ChangeBuffer."Trigger Source" := CopyStr(TriggerSource, 1, MaxStrLen(ChangeBuffer."Trigger Source"));
    end;

    procedure StartNewTransaction()
    begin
        CurrentTransactionId := CreateGuid();
        TransactionStartTime := CurrentDateTime();
        TransactionChangeCount := 0;
    end;

    procedure EndTransaction()
    begin
        Clear(CurrentTransactionId);
        TransactionChangeCount := 0;
    end;

    procedure GetCurrentTransactionId(): Guid
    begin
        exit(CurrentTransactionId);
    end;

    procedure GetTransactionChangeCount(): Integer
    begin
        exit(TransactionChangeCount);
    end;

    local procedure BuildCallStackInfo(): Text
    var
        CallStackBuilder: TextBuilder;
        StackLevel: Integer;
        ObjectInfo: Text;
    begin
        CallStackBuilder.AppendLine('=== CALL STACK ===');
        CallStackBuilder.AppendLine('Timestamp: ' + Format(CurrentDateTime()));
        CallStackBuilder.AppendLine('Session: ' + Format(SessionId()));
        CallStackBuilder.AppendLine('User: ' + UserId());
        CallStackBuilder.AppendLine('Company: ' + CompanyName());
        CallStackBuilder.AppendLine('');

        // Add execution context information
        CallStackBuilder.AppendLine('=== EXECUTION CONTEXT ===');
        CallStackBuilder.AppendLine('Current Codeunit: Database Triggers');
        CallStackBuilder.AppendLine('Trigger Type: Global Database Event');
        CallStackBuilder.AppendLine('Transaction ID: ' + Format(CurrentTransactionId));
        CallStackBuilder.AppendLine('Change #: ' + Format(TransactionChangeCount + 1));
        CallStackBuilder.AppendLine('');

        // Add environment information
        CallStackBuilder.AppendLine('=== ENVIRONMENT ===');
        CallStackBuilder.AppendLine('Client Type: ' + GetClientType());
        CallStackBuilder.AppendLine('Application Version: ' + ApplicationVersion());
        CallStackBuilder.AppendLine('Platform Version: ' + PlatformVersion());

        exit(CallStackBuilder.ToText());
    end;

    local procedure ExtractTriggerSource(CallStackText: Text): Text
    begin
        // Simplified trigger source extraction
        // In a real implementation, you might parse the call stack more thoroughly
        if StrPos(CallStackText, 'Global Database Event') > 0 then
            exit('Global Database Trigger')
        else
            exit('Unknown Source');
    end;

    local procedure GetClientType(): Text
    begin
        // Determine client type based on session information
        case true of
            (SessionId() = 0):
                exit('Server');
            (SessionId() > 0):
                exit('Client');
            else
                exit('Unknown');
        end;
    end;

    local procedure ApplicationVersion(): Text
    begin
        // Return a placeholder version - in real implementation you might use Environment Information
        exit('BC 26.0');
    end;

    local procedure PlatformVersion(): Text
    begin
        // Return a placeholder version - in real implementation you might use Environment Information
        exit('Platform 26.0');
    end;
}
