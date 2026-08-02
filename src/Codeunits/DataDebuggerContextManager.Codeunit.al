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
    begin
        CallStackText := SessionInformation.Callstack();
        ChangeBuffer.SetCallStack(CallStackText);
        ChangeBuffer."Trigger Source" := CopyStr(ExtractTriggerSource(CallStackText), 1, MaxStrLen(ChangeBuffer."Trigger Source"));
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

    local procedure ExtractTriggerSource(CallStackText: Text): Text
    begin
        if (StrPos(CallStackText, 'OnDatabaseInsert') > 0) or (StrPos(CallStackText, 'OnGlobalInsert') > 0) then
            exit('Database Insert');
        if (StrPos(CallStackText, 'OnDatabaseModify') > 0) or (StrPos(CallStackText, 'OnGlobalModify') > 0) then
            exit('Database Modify');
        if (StrPos(CallStackText, 'OnDatabaseDelete') > 0) or (StrPos(CallStackText, 'OnGlobalDelete') > 0) then
            exit('Database Delete');
        if (StrPos(CallStackText, 'OnDatabaseRename') > 0) or (StrPos(CallStackText, 'OnGlobalRename') > 0) then
            exit('Database Rename');
        exit('Unknown Source');
    end;

    local procedure GetClientType(): Text
    begin
        exit(Format(CurrentClientType()));
    end;
}
