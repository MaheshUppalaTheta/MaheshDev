codeunit 50140 "DD Recording Tests"
{
    // Automated tests for Data Debugger user-based recording.
    //
    // Run under the BC test runner (AL Test Tool / the AL Test Runner VS Code extension, or
    // headless via BcContainerHelper in CI). They exercise the real capture path: start a
    // recording for a user, write to a real table, and assert what landed in the persisted
    // Change Buffer.
    //
    // Self-contained (no Microsoft test-library dependency) so the app still compiles with only
    // the platform/base symbols. They deliberately do NOT call SessionManager.StopRecording(),
    // because that opens the Results page (RunModal), which cannot run headless.
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure CapturesModifyForRecordedUser()
    var
        Customer: Record Customer;
        ChangeBuffer: Record "Data Debugger Change Buffer";
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

        // [THEN] A Modify entry for the Customer table exists in this run
        ChangeBuffer.SetRange("Run ID", RunId);
        ChangeBuffer.SetRange("Table ID", Database::Customer);
        ChangeBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(not ChangeBuffer.IsEmpty(), 'Expected a captured Modify entry for Customer, found none.');

        StopForTest();
    end;

    [Test]
    procedure CapturesInsertForRecordedUser()
    var
        Customer: Record Customer;
        ChangeBuffer: Record "Data Debugger Change Buffer";
        SessionManager: Codeunit "Data Debugger Session Manager";
        RunId: Guid;
    begin
        // [SCENARIO] Inserting a record while recording the current user is captured.
        Initialize();

        RunId := SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Test User');

        // [WHEN] A new customer is inserted
        Customer.Init();
        Customer."No." := 'DD-INS-001';
        if Customer.Insert(true) then;

        // [THEN] An Insert entry for the Customer table exists in this run
        ChangeBuffer.SetRange("Run ID", RunId);
        ChangeBuffer.SetRange("Table ID", Database::Customer);
        ChangeBuffer.SetRange("Change Type", "Data Debugger Change Type"::Insert);
        AssertTrue(not ChangeBuffer.IsEmpty(), 'Expected a captured Insert entry for Customer, found none.');

        StopForTest();
    end;

    [Test]
    procedure IgnoresChangesFromOtherUsers()
    var
        Customer: Record Customer;
        ChangeBuffer: Record "Data Debugger Change Buffer";
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
        ChangeBuffer.SetRange("Run ID", RunId);
        AssertTrue(ChangeBuffer.IsEmpty(), 'Expected NO captures (acting user differs from recorded user), but found some.');

        StopForTest();
    end;

    [Test]
    procedure CapturesNothingWhenNotRecording()
    var
        Customer: Record Customer;
        ChangeBuffer: Record "Data Debugger Change Buffer";
    begin
        // [SCENARIO] With no active recording, database changes are not captured.
        Initialize();
        EnsureCustomer(Customer);

        // [WHEN] A customer changes while no recording is active
        Customer.Validate(Name, CopyStr(Customer.Name + 'Z', 1, MaxStrLen(Customer.Name)));
        Customer.Modify(true);

        // [THEN] The buffer stays empty
        AssertTrue(ChangeBuffer.IsEmpty(), 'Expected an empty Change Buffer when not recording.');
    end;

    local procedure Initialize()
    var
        State: Record "DD Recording State";
        ChangeBuffer: Record "Data Debugger Change Buffer";
    begin
        // Make every test independent: stop any recording and clear the persisted buffer.
        if State.Get('') then begin
            State."Is Recording" := false;
            State.Modify();
        end;
        ChangeBuffer.Reset();
        ChangeBuffer.DeleteAll();
    end;

    local procedure StopForTest()
    var
        State: Record "DD Recording State";
    begin
        // Turn recording off without opening the Results page (which StopRecording does).
        if State.Get('') then begin
            State."Is Recording" := false;
            State.Modify();
        end;
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
}
