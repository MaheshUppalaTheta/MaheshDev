codeunit 50142 "DD Hardening Tests"
{
    // Regression tests for the security-and-correctness hardening delivered in Spec C:
    //   - Multi-user gate (user filter works in both directions)
    //   - Table scope filters (whitelist and blacklist)
    //   - Field selection does not block capture on a selected field
    //   - Performance throttle does not block capture when under the configured limit
    //
    // Run inside the BC test runner (AL Test Tool / BcContainerHelper CI).
    // Initialize() resets recording state, capture buffer, table filters, field selection,
    // and Setup before every test so all tests are fully independent.
    Subtype = Test;
    TestPermissions = Disabled;

    // ---------------------------------------------------------------------------------------------
    // Multi-user gate
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure MultiUser_OtherUser_NotCaptured()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        FakeUserId: Guid;
    begin
        // [SCENARIO] A recording targeted at a DIFFERENT user does not capture the current
        // user's changes. This is the critical security gate for multi-user recordings.
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] A recording started for a fictitious other user (not the current session)
        FakeUserId := CreateGuid();
        SessionManager.StartRecording(FakeUserId, 'FAKEUSER', 'Fake User');

        // [WHEN] The current (test) session user modifies a Customer
        Customer.Validate(Name, 'DD Hardening - Other User');
        Customer.Modify(true);

        // [THEN] Nothing captured: the acting user is not the recorded user
        SessionManager.GetChanges(ResultBuffer);
        AssertTrue(ResultBuffer.IsEmpty(), 'Expected NO captures when the acting user differs from the recorded user.');

        StopForTest();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure MultiUser_CurrentUser_Captured()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
    begin
        // [SCENARIO] A recording explicitly targeted at UserSecurityId() captures the current
        // session's changes. Confirms the positive path of the multi-user gate.
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] A recording started for the current test-session user
        SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Current User');

        // [WHEN] The current user modifies a Customer
        Customer.Validate(Name, 'DD Hardening - Current User');
        Customer.Modify(true);

        // [THEN] A Modify entry for Customer is captured
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(not ResultBuffer.IsEmpty(), 'Expected a captured Modify entry for the current user.');

        StopForTest();
    end;

    // ---------------------------------------------------------------------------------------------
    // Table scope filters
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure TableScope_Whitelist_UnlistedTableIgnored()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
    begin
        // [SCENARIO] When scope is "Only Selected Tables" and Vendor is the only listed table,
        // modifying Customer is not captured (Customer is not in the whitelist).
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] Scope = Only Selected Tables; only Vendor (23) in the filter list
        SetCaptureScope("DD Capture Scope"::"Only Selected Tables");
        AddTableFilter(Database::Vendor);
        // StartRecording calls FilterManager.ReloadSetup() so the new scope takes effect.
        SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Current User');

        // [WHEN] The current user modifies a Customer (NOT in the whitelist)
        Customer.Validate(Name, 'DD Hardening - Whitelist Test');
        Customer.Modify(true);

        // [THEN] No Customer change is captured
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        AssertTrue(ResultBuffer.IsEmpty(), 'Expected NO Customer captures when Customer is not in the whitelist.');

        StopForTest();
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure TableScope_Blacklist_ListedTableIgnored()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
    begin
        // [SCENARIO] When scope is "All Except Selected Tables" and Customer is in the list,
        // modifying Customer is not captured (blacklisted).
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] Scope = All Except Selected Tables; Customer (18) is blacklisted
        SetCaptureScope("DD Capture Scope"::"All Except Selected Tables");
        AddTableFilter(Database::Customer);
        SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Current User');

        // [WHEN] The current user modifies a Customer
        Customer.Validate(Name, 'DD Hardening - Blacklist Test');
        Customer.Modify(true);

        // [THEN] No Customer change is captured (Customer is blacklisted)
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        AssertTrue(ResultBuffer.IsEmpty(), 'Expected NO Customer captures when Customer is in the blacklist.');

        StopForTest();
    end;

    // ---------------------------------------------------------------------------------------------
    // Field selection
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure FieldFilter_WithSelection_CaptureNotBlocked()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
    begin
        // [SCENARIO] Enabling field selection for Customer (selecting Name) does not prevent the
        // change entry from being created when Name is modified. Field selection controls the JSON
        // payload content, not whether an entry is captured.
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] Field selection active for Customer: only the Name field is selected
        AddFieldSelection(Database::Customer, Customer.FieldNo(Name), 'Name');
        SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Current User');

        // [WHEN] Customer Name (a selected field) is modified
        Customer.Validate(Name, 'DD Hardening - Field Filter Test');
        Customer.Modify(true);

        // [THEN] The change is still captured (field selection does not block entry creation)
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(not ResultBuffer.IsEmpty(), 'Expected Customer Modify capture to succeed when the modified field is in the field selection.');

        StopForTest();
    end;

    // ---------------------------------------------------------------------------------------------
    // Performance throttle
    // ---------------------------------------------------------------------------------------------

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure Throttle_Enabled_UnderLimit_AllCaptured()
    var
        Customer: Record Customer;
        ResultBuffer: Record "Data Debugger Change Buffer" temporary;
        SessionManager: Codeunit "Data Debugger Session Manager";
        ChangeIndex: Integer;
    begin
        // [SCENARIO] With throttle enabled and MaxCapturesPerSecond well above the number of
        // changes made, all changes are captured (throttle path is exercised but not capping).
        Initialize();
        EnsureCustomer(Customer);

        // [GIVEN] Throttle enabled with a generous limit; 3 changes will stay well below it
        SetThrottle(100);
        // StartRecording calls FilterManager.ReloadSetup() → throttle is activated
        SessionManager.StartRecording(UserSecurityId(), CopyStr(UserId(), 1, 50), 'Current User');

        // [WHEN] 3 sequential Customer modifies are made
        for ChangeIndex := 1 to 3 do begin
            Customer.Get(Customer."No.");
            Customer.Validate(Name, CopyStr('DD-THR-' + Format(ChangeIndex), 1, MaxStrLen(Customer.Name)));
            Customer.Modify(true);
        end;

        // [THEN] All 3 changes are captured (throttle did not suppress any)
        SessionManager.GetChanges(ResultBuffer);
        ResultBuffer.SetRange("Table ID", Database::Customer);
        ResultBuffer.SetRange("Change Type", "Data Debugger Change Type"::Modify);
        AssertTrue(ResultBuffer.Count() = 3, 'Expected all 3 changes captured when throttle limit is not reached.');

        StopForTest();
    end;

    // ---------------------------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------------------------

    local procedure Initialize()
    var
        State: Record "DD Recording State";
        ChangeBuffer: Record "Data Debugger Change Buffer";
        TableFilter: Record "Data Debugger Table Filter";
        FieldSelection: Record "DD Field Selection Buffer";
        Setup: Record "Data Debugger Setup";
        Customer: Record Customer;
    begin
        if State.Get('') then begin
            State."Is Recording" := false;
            State.Modify();
        end;
        ChangeBuffer.Reset();
        ChangeBuffer.DeleteAll();
        TableFilter.Reset();
        TableFilter.DeleteAll();
        FieldSelection.Reset();
        FieldSelection.DeleteAll();
        if not Setup.Get('') then begin
            Setup.Init();
            Setup.Insert(false);
        end;
        Setup."Table Capture Scope" := Setup."Table Capture Scope"::"All Tables";
        Setup."Enable Performance Throttling" := false;
        Setup."Direct Database Capture" := false;
        Setup.Modify();
        // Reset the test Customer to a stable name so name-suffix tests are idempotent.
        if Customer.Get('DD-HRD') then begin
            Customer.Name := 'DD Hardening Test Customer';
            Customer.Modify(false);
        end;
    end;

    local procedure StopForTest()
    var
        State: Record "DD Recording State";
    begin
        if State.Get('') then begin
            State."Is Recording" := false;
            State.Modify();
        end;
    end;

    local procedure SetCaptureScope(Scope: Enum "DD Capture Scope")
    var
        Setup: Record "Data Debugger Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup.Insert(false);
        end;
        Setup."Table Capture Scope" := Scope;
        Setup.Modify();
    end;

    local procedure AddTableFilter(TableId: Integer)
    var
        TableFilter: Record "Data Debugger Table Filter";
    begin
        TableFilter.Init();
        TableFilter."Table ID" := TableId;
        TableFilter.Enabled := true;
        TableFilter.Insert(true);
    end;

    local procedure AddFieldSelection(TableId: Integer; FieldNo: Integer; FieldName: Text[30])
    var
        FieldSelection: Record "DD Field Selection Buffer";
    begin
        FieldSelection.Init();
        FieldSelection."Table ID" := TableId;
        FieldSelection."Field No." := FieldNo;
        FieldSelection."Field Name" := FieldName;
        FieldSelection.Selected := true;
        FieldSelection.Insert(false);
    end;

    local procedure SetThrottle(MaxPerSecond: Integer)
    var
        Setup: Record "Data Debugger Setup";
    begin
        if not Setup.Get('') then begin
            Setup.Init();
            Setup.Insert(false);
        end;
        Setup."Enable Performance Throttling" := true;
        Setup."Max Captures Per Second" := MaxPerSecond;
        Setup.Modify();
    end;

    local procedure EnsureCustomer(var Customer: Record Customer)
    begin
        if Customer.FindFirst() then
            exit;
        Customer.Init();
        Customer."No." := 'DD-HRD';
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
        // Swallow StartRecording / StopRecording status messages.
    end;
}
