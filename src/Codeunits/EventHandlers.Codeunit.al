codeunit 50001 "Data Debugger Event Handlers"
{
    // Automatic subscribers: these fire in every user session (like the base Change Log), which
    // is what lets the tool capture a *selected* user's operations no matter which session they
    // happen in. The runtime gate `SessionManager.ShouldCapture()` keeps only the recorded user's
    // changes while a recording is active; everything else exits immediately.
    //
    // IMPORTANT: these are AUTOMATIC subscribers (no EventSubscriberInstance = Manual). A manual
    // subscriber would only fire for the session that called BindSubscription, so it could never
    // capture a *different* user's operations. Automatic subscribers are active in every session;
    // ShouldCapture() then keeps only the recorded user's changes.
    SingleInstance = true;
    InherentEntitlements = X;
    InherentPermissions = X;


    var
        SessionManager: Codeunit "Data Debugger Session Manager";
        FilterManager: Codeunit "Data Debugger Filter Manager";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Global Triggers", 'GetDatabaseTableTriggerSetup', '', false, false)]
    local procedure GetDatabaseTableTriggerSetup(TableId: Integer; var OnDatabaseInsert: Boolean; var OnDatabaseModify: Boolean; var OnDatabaseDelete: Boolean; var OnDatabaseRename: Boolean)
    begin
        // Gated on table filters ONLY, NOT on whether a recording is active. The platform caches
        // this trigger setup per session, so gating on "is recording" would mean a session that was
        // already open when the setup was first evaluated caches "no triggers" and never raises them
        // after a recording later starts — which silently breaks capture. The On* handlers below do
        // the recording/user gating at runtime via ShouldCapture() instead, which is always correct.
        if not FilterManager.IsTableAllowed(TableId) then
            exit;

        OnDatabaseInsert := true;
        OnDatabaseModify := true;
        OnDatabaseDelete := true;
        OnDatabaseRename := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Global Triggers", 'OnDatabaseInsert', '', false, false)]
    local procedure OnAfterOnGlobalInsert(RecRef: RecordRef)
    begin
        if not SessionManager.ShouldCapture() then
            exit;
        if not FilterManager.IsTableAllowed(RecRef.Number()) then
            exit;
        if not FilterManager.CanCaptureNow() then
            exit;
        CaptureInsert(RecRef);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Global Triggers", 'OnDatabaseModify', '', false, false)]
    local procedure OnAfterOnGlobalModify(RecRef: RecordRef)
    var
        xRecRef: RecordRef;
    begin
        if not SessionManager.ShouldCapture() then
            exit;
        if not FilterManager.IsTableAllowed(RecRef.Number()) then
            exit;

        // xRecRef must be open before ShouldCaptureModification accesses its fields
        xRecRef.Open(RecRef.Number, false, RecRef.CurrentCompany());
        xRecRef.ReadIsolation := xRecRef.ReadIsolation::ReadCommitted;
        xRecRef."SecurityFiltering" := SECURITYFILTER::Filtered;

        if not FilterManager.ShouldCaptureModification(RecRef, xRecRef) then
            exit;
        if not FilterManager.CanCaptureNow() then
            exit;

        if not xRecRef.ReadPermission() then begin
            // old data unreadable — capture with marker so diff is traceable
            CaptureModify(RecRef, xRecRef);
            exit;
        end;
        if not xRecRef.Get(RecRef.RecordId) then
            exit;
        CaptureModify(RecRef, xRecRef);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Global Triggers", 'OnDatabaseDelete', '', false, false)]
    local procedure OnDatabaseDelete(RecRef: RecordRef)
    begin
        if not SessionManager.ShouldCapture() then
            exit;
        if not FilterManager.IsTableAllowed(RecRef.Number()) then
            exit;
        if not FilterManager.CanCaptureNow() then
            exit;
        CaptureDelete(RecRef);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Global Triggers", 'OnDatabaseRename', '', false, false)]
    local procedure OnDatabaseRename(RecRef: RecordRef; xRecRef: RecordRef)
    begin
        if not SessionManager.ShouldCapture() then
            exit;
        if not FilterManager.IsTableAllowed(RecRef.Number()) then
            exit;
        if not FilterManager.CanCaptureNow() then
            exit;

        CaptureRename(RecRef, xRecRef);
    end;



    local procedure CaptureInsert(RecRef: RecordRef)
    var
        ErrorMessage: Record "Error Message";
        TempBlob: Codeunit "Temp Blob";
        TypeHelper: Codeunit "Type Helper";
        FldRef: FieldRef;
        InStream: InStream;
        NewDataJson: Text;
        PrimaryKey: Text;
        ErrorCallStack: Text;
        IsTemporary: Boolean;
    begin
        NewDataJson := RecordToJson(RecRef);
        PrimaryKey := GetPrimaryKeyText(RecRef);
        IsTemporary := IsTemporaryTable(RecRef);

        // When Table 700 "Error Message" is being inserted, read the "Error Call Stack" blob
        // from the record and use it as our call stack. This gives us the actual error origin
        // rather than the synthetic capture-path stack.
        if RecRef.Number() = Database::"Error Message" then begin
            FldRef := RecRef.Field(ErrorMessage.FieldNo("Error Call Stack"));
            // Read the BLOB straight from the RecRef buffer (the row is not yet queryable from the
            // DB inside the insert trigger, so ErrorMessage.GetErrorCallStack()'s CalcFields would
            // come back empty). Match the platform's own encoding (Windows/ANSI, set by
            // SetErrorCallStack) and read every line — a call stack is multi-line, so a single
            // InStream.ReadText would keep only the first line.
            TempBlob.FromFieldRef(FldRef);
            if TempBlob.HasValue() then begin
                TempBlob.CreateInStream(InStream);
                ErrorCallStack := TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator());
            end;
            // For an Error entry the error-origin stack is the whole point, so never let it fall
            // back to the code-execution call stack (which BuildEntry would do for an empty string).
            if ErrorCallStack = '' then
                ErrorCallStack := '(no error call stack recorded on the Error Message record)';
            SessionManager.AddChange(
                RecRef.Number(),
                "Data Debugger Change Type"::Error,
                PrimaryKey,
                '',
                NewDataJson,
                IsTemporary,
                ErrorCallStack
            );
        end else
            SessionManager.AddChange(
                RecRef.Number(),
                "Data Debugger Change Type"::Insert,
                PrimaryKey,
                '', // No old data for insert
                NewDataJson,
                IsTemporary
            );
    end;

    local procedure CaptureModify(RecRef: RecordRef; xRecRef: RecordRef)
    var
        OldDataJson: Text;
        NewDataJson: Text;
        PrimaryKey: Text;
        IsTemporary: Boolean;
    begin
        // Use the provided xRecRef (old record) directly from the event
        OldDataJson := RecordToJson(xRecRef);
        NewDataJson := RecordToJson(RecRef);
        PrimaryKey := GetPrimaryKeyText(RecRef);
        IsTemporary := IsTemporaryTable(RecRef);

        SessionManager.AddChange(
            RecRef.Number(),
            "Data Debugger Change Type"::Modify,
            PrimaryKey,
            OldDataJson,
            NewDataJson,
            IsTemporary
        );
    end;

    local procedure CaptureDelete(RecRef: RecordRef)
    var
        OldDataJson: Text;
        PrimaryKey: Text;
        IsTemporary: Boolean;
    begin
        OldDataJson := RecordToJson(RecRef);
        PrimaryKey := GetPrimaryKeyText(RecRef);
        IsTemporary := IsTemporaryTable(RecRef);

        SessionManager.AddChange(
            RecRef.Number(),
            "Data Debugger Change Type"::Delete,
            PrimaryKey,
            OldDataJson,
            '', // No new data for delete
            IsTemporary
        );
    end;

    local procedure CaptureRename(RecRef: RecordRef; xRecRef: RecordRef)
    var
        OldDataJson: Text;
        NewDataJson: Text;
        PrimaryKey: Text;
        IsTemporary: Boolean;
    begin
        OldDataJson := RecordToJson(xRecRef);
        NewDataJson := RecordToJson(RecRef);
        PrimaryKey := GetPrimaryKeyText(xRecRef) + ' → ' + GetPrimaryKeyText(RecRef);
        IsTemporary := IsTemporaryTable(RecRef);

        SessionManager.AddChange(
            RecRef.Number(),
            "Data Debugger Change Type"::Rename,
            PrimaryKey,
            OldDataJson,
            NewDataJson,
            IsTemporary
        );
    end;

    local procedure RecordToJson(RecRef: RecordRef): Text
    var
        FieldRef: FieldRef;
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        ResultText: Text;
        i: Integer;
    begin
        for i := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(i);

            // Skip system fields and flowfields
            if (FieldRef.Class() = FieldClass::Normal) and (FieldRef.Type() <> FieldType::Blob) then begin
                case FieldRef.Type() of
                    FieldType::Boolean:
                        JsonObject.Add(FieldRef.Name(), Format(FieldRef.Value()));
                    FieldType::Integer, FieldType::BigInteger:
                        JsonObject.Add(FieldRef.Name(), Format(FieldRef.Value()));
                    FieldType::Decimal:
                        JsonObject.Add(FieldRef.Name(), Format(FieldRef.Value()));
                    FieldType::Date, FieldType::Time, FieldType::DateTime:
                        JsonObject.Add(FieldRef.Name(), Format(FieldRef.Value()));
                    FieldType::Guid:
                        JsonObject.Add(FieldRef.Name(), Format(FieldRef.Value()));
                    else
                        JsonObject.Add(FieldRef.Name(), Format(FieldRef.Value()));
                end;
            end;
        end;

        // Apply field-level filtering
        FilterManager.FilterFields(JsonObject, RecRef.Number());

        JsonObject.WriteTo(ResultText);
        exit(ResultText);
    end;

    local procedure GetPrimaryKeyText(RecRef: RecordRef): Text
    var
        KeyRef: KeyRef;
        FieldRef: FieldRef;
        PrimaryKey: Text;
        i: Integer;
    begin
        KeyRef := RecRef.KeyIndex(1); // First key is usually primary key

        for i := 1 to KeyRef.FieldCount() do begin
            FieldRef := KeyRef.FieldIndex(i);
            if PrimaryKey <> '' then
                PrimaryKey += ', ';
            PrimaryKey += Format(FieldRef.Value());
        end;

        exit(PrimaryKey);
    end;

    local procedure IsTemporaryTable(RecRef: RecordRef): Boolean
    var
        TableMetadata: Record "Table Metadata";
    begin
        // In Business Central, we can detect temporary tables by checking the TableType
        Exit(RecRef.IsTemporary());
    end;


}