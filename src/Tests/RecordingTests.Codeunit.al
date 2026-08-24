codeunit 50140 "DD Recording Tests"
{
    // Automated tests for Data Debugger user-based recording.
    //
    // Run under the BC test runner (AL Test Tool / AL Test Runner extension, or headless via
    // BcContainerHelper in CI). They exercise the real capture path: start a recording, write to a
    // real table, and assert what was captured.
    //
    // StartRecording/StopRecording raise a Message, so every test that calls them is decorated with
    // [HandlerFunctions('MessageHandler')]; a test that shows no message must NOT declare the handler
    // (the runner fails a test whose declared handler is never called).
    Subtype = Test;
    TestPermissions = Disabled;

    // ---------------------------------------------------------------------------------------------
    // Basic capture + user gating
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure CapturesModifyForRecordedUser()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        RunId: Guid;
    begin
        // [SCENARIO] Recording the current user and modifying a Customer is captured.
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] A recording started for the current (test) user
        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        // [WHEN] The customer name changes
        Customer.Validate(Name, CopyStr(Customer.Name + 'X', 1, MaxStrLen(Customer.Name)));
        Customer.Modify(true);

        // [THEN] A Modify entry for the Customer table exists. Read via GetChanges so the test is
        // independent of the capture mode (in-memory vs direct-to-table).
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(not ResultBuffer.IsEmpty(), 'Expected a captured Modify entry for Customer, found none.');

        StopForTest();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure CapturesInsertForRecordedUser()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        RunId: Guid;
    begin
        // [SCENARIO] Inserting a record while recording the current user is captured.
        Initialize();

        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        // [WHEN] A new customer is inserted (raw insert: avoids No.-series/validation dependencies;
        // the global database trigger still fires regardless of the run-trigger flag)
        Customer.Init();
        Customer."No." := 'DD-INS-001';
        Customer.Insert(false);

        // [THEN] An Insert entry for the Customer table exists in this run
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Insert);
        AssertTrue(not ResultBuffer.IsEmpty(), 'Expected a captured Insert entry for Customer, found none.');

        StopForTest();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure IgnoresChangesFromOtherUsers()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        OtherUserSecurityId: Guid;
        RunId: Guid;
    begin
        // [SCENARIO] When the run targets a DIFFERENT user, the current user's change is ignored.
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] A recording started for some other user (not the test session user)
        OtherUserSecurityId := CreateGuid();
        RunId := SessionManager.StartRecording(OtherUserSecurityId, 'OTHERUSER', 'Other User');

        // [WHEN] The test (current) user modifies a customer
        Customer.Validate(Name, CopyStr(Customer.Name + 'Y', 1, MaxStrLen(Customer.Name)));
        Customer.Modify(true);

        // [THEN] Nothing is captured, because the acting user is not the recorded user
        SessionManager.GetChanges(ResultBuffer);
        AssertTrue(ResultBuffer.IsEmpty(), 'Expected NO captures (acting user differs from recorded user), but found some.');

        StopForTest();
    end;

    [Test]
    procedure CapturesNothingWhenNotRecording()
    var
        Customer: Record Customer;
        ChangeBuffer: Record "Data Debugger Change Buffer";
    begin
        // [SCENARIO] With no active recording, database changes are not captured.
        // (No StartRecording -> no Message -> intentionally no MessageHandler.)
        Initialize();
        EnsureCustomer(Customer);

        // [WHEN] A customer changes while no recording is active
        Customer.Validate(Name, CopyStr(Customer.Name + 'Z', 1, MaxStrLen(Customer.Name)));
        Customer.Modify(true);

        // [THEN] The buffer stays empty
        AssertTrue(ChangeBuffer.IsEmpty(), 'Expected an empty Change Buffer when not recording.');
    end;

    // ---------------------------------------------------------------------------------------------
    // Normal process: Stop flushes captures to the persisted table
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure NormalProcess_StopPersistsToRealTable()
    var
        Customer: Record Customer;
        ChangeBuffer: Record "Data Debugger Change Buffer";
        SessionManager: Codeunit "Data Debugger Session Manager";
        RunId: Guid;
    begin
        // [SCENARIO] A normal (no error) recording: after Stop the captures are persisted in the
        // real Change Buffer table.
        Initialize();
        EnsureCustomer(Customer);

        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        Customer.Validate(Name, CopyStr(Customer.Name + 'N', 1, MaxStrLen(Customer.Name)));
        Customer.Modify(true);

        // [WHEN] Recording stops (flushes the in-memory buffer to the real table)
        SessionManager.StopRecording();

        // [THEN] The persisted table holds the captured change for this run
        ChangeBuffer.SetRange("Run ID", RunId);
        ChangeBuffer.SetRange("Table ID", Database::Customer);
        AssertTrue(not ChangeBuffer.IsEmpty(), 'After Stop, captures should be persisted in the real table.');
    end;

    // ---------------------------------------------------------------------------------------------
    // Error process: rollback-safe (default) survives; direct mode does not
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure RollbackSafe_CapturesSurviveProcessError()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        ErrorRunner: Codeunit "DD Test Error Runner";
        RunId: Guid;
    begin
        // [SCENARIO] In rollback-safe mode (default), a process that modifies then errors gets its
        // database change rolled back, but the capture survives in memory.
        Initialize(); // leaves Direct Database Capture = false (rollback-safe)
        EnsureCustomer(Customer);

        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        // [WHEN] A process modifies the customer and then errors (Codeunit.Run rolls it back)
        if ErrorRunner.Run(Customer) then;

        // [THEN] The database change was rolled back...
        Customer.Get(Customer."No.");
        AssertTrue(StrPos(Customer.Name, 'QZX99') = 0, 'The failed process change should have been rolled back.');

        // [THEN] ...but the capture survived in the in-memory buffer
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(not ResultBuffer.IsEmpty(), 'Rollback-safe capture should survive a rolled-back process.');

        StopForTest();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure ErrorThenStop_PersistsSurvivingCaptures()
    var
        Customer: Record Customer;
        ChangeBuffer: Record "Data Debugger Change Buffer";
        SessionManager: Codeunit "Data Debugger Session Manager";
        ErrorRunner: Codeunit "DD Test Error Runner";
        RunId: Guid;
    begin
        // [SCENARIO] The full flow: rollback-safe recording, a process errors (rolls back), then
        // Stop persists the surviving capture to the real table.
        Initialize();
        EnsureCustomer(Customer);

        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        if ErrorRunner.Run(Customer) then;

        // [WHEN] Recording stops -> flushes the surviving in-memory capture
        SessionManager.StopRecording();

        // [THEN] The capture from the failed process is now persisted
        ChangeBuffer.SetRange("Run ID", RunId);
        ChangeBuffer.SetRange("Table ID", Database::Customer);
        AssertTrue(not ChangeBuffer.IsEmpty(), 'Captures from a rolled-back process should persist after Stop.');
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure DirectMode_CapturesLostOnProcessError()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        ErrorRunner: Codeunit "DD Test Error Runner";
        RunId: Guid;
    begin
        // [SCENARIO] In direct mode, captures are written straight to the table and therefore roll
        // back together with the failed process (this is the behavior rollback-safe mode fixes).
        Initialize();
        SetDirectCapture(true); // opt into direct-to-table capture BEFORE starting
        EnsureCustomer(Customer);

        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        if ErrorRunner.Run(Customer) then;

        // [THEN] Nothing remains: the direct-to-table inserts were rolled back with the process.
        // (Recording is active but NOT rollback-safe, so GetChanges reads the persisted table.)
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        AssertTrue(ResultBuffer.IsEmpty(), 'In direct mode, captures should be rolled back with the failed process.');

        StopForTest();
    end;

    // ---------------------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------------------

    local procedure Initialize()
    var
        State: Record "DD Recording State";
        ChangeBuffer: Record "Data Debugger Change Buffer";
    begin
        // Make every test independent: stop any recording, clear the persisted buffer, and reset
        // the capture mode to the rollback-safe default.
        if State.Get('') then begin
            State."Is Recording" := false;
            State.Modify();
        end;
        ChangeBuffer.Reset();
        ChangeBuffer.DeleteAll();
        SetDirectCapture(false);
    end;

    local procedure StopForTest()
    var
        State: Record "DD Recording State";
    begin
        // Turn recording off without going through StopRecording (which shows a Message / flushes).
        if State.Get('') then begin
            State."Is Recording" := false;
            State.Modify();
        end;
    end;

    local procedure SetDirectCapture(Enable: Boolean)
    var
        Setup: Record "Data Debugger Setup";
    begin
        Setup := Setup.GetSetup();
        Setup."Direct Database Capture" := Enable;
        Setup.Modify();
    end;

    local procedure EnsureCustomer(var Customer: Record Customer)
    begin
        if Customer.FindFirst() then
            exit;
        Customer.Init();
        Customer."No." := 'DD-TEST';
        Customer.Insert(true);
        Customer.Get(Customer."No.");
    end;

    local procedure AssertTrue(Condition: Boolean; FailMessage: Text)
    begin
        if not Condition then
            Error('TEST FAILED: %1', FailMessage);
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
        // Swallow StartRecording/StopRecording status messages so the test runner doesn't fail on
        // an unhandled UI dialog.
    end;

    // ---------------------------------------------------------------------------------------------
    // Spec A correctness tests
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure ClientType_CapturedCorrectly()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        RunId: Guid;
    begin
        // [SCENARIO] After capturing a change the Client Type reflects the actual session type,
        // not the hard-coded 'Client' that SessionId() > 0 always returned.
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] A recording started for the current user
        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        // [WHEN] A Customer record is modified
        Customer.Validate(Name, CopyStr(Customer.Name + 'C', 1, MaxStrLen(Customer.Name)));
        Customer.Modify(true);

        // [THEN] The captured entry has a non-empty Client Type that is NOT the literal 'Client'
        // (test runner sessions are Background, not Client)
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(not ResultBuffer.IsEmpty(), 'Expected a captured Modify entry for Client Type test.');
        if ResultBuffer.FindFirst() then begin
            AssertTrue(ResultBuffer."Client Type" <> '', 'Client Type must not be empty.');
            AssertTrue(ResultBuffer."Client Type" <> 'Client', 'Client type must reflect actual session type, not hard-coded Client.');
        end;

        StopForTest();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure ModifyCapture_DoesNotThrow()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        RunId: Guid;
    begin
        // [SCENARIO] The restructured xRecRef permission guard does not throw an exception on the
        // normal capture path (i.e. fixing the dead-code / pre-open regression didn't break capture).
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] A recording started for the current user
        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        // [WHEN] A Customer record is modified (exercises the fixed OnAfterOnGlobalModify)
        Customer.Validate(Name, CopyStr(Customer.Name + 'P', 1, MaxStrLen(Customer.Name)));
        Customer.Modify(true);

        // [THEN] At least one change is captured and no unhandled exception was raised
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        AssertTrue(not ResultBuffer.IsEmpty(), 'Expected at least one captured change after modify; no exception should have been raised.');

        StopForTest();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure TransactionGrouping_Setup_Valid()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        RunId: Guid;
        I: Integer;
    begin
        // [SCENARIO] Three sequential Customer modifies produce exactly 3 captured changes so the
        // transaction-grouping data path (used by the Transactions page) has correct input.
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] A recording is active for the current user
        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        // [WHEN] Three Customer modifies are made in sequence
        for I := 1 to 3 do begin
            Customer.Get(Customer."No.");
            Customer.Validate(Name, CopyStr('DD-TXN-' + Format(I), 1, MaxStrLen(Customer.Name)));
            Customer.Modify(true);
        end;

        // [THEN] GetChanges returns exactly 3 Customer Modify entries
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(ResultBuffer.Count() = 3, 'Expected exactly 3 captured Customer Modify entries for transaction grouping test.');

        StopForTest();
    end;
}
