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
        // Note: this is gated on table filters only, NOT on whether a recording is active. The
        // platform caches the trigger setup per session, so gating on "is recording" would mean
        // already-open sessions never raise triggers after a recording starts. The On* handlers
        // below do the recording/user gating at runtime instead.

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
        IsReadable: Boolean;
    begin
        if not SessionManager.ShouldCapture() then
            exit;
        if not FilterManager.IsTableAllowed(RecRef.Number()) then
            exit;
        if not FilterManager.ShouldCaptureModification(RecRef, xRecRef) then
            exit;
        if not FilterManager.CanCaptureNow() then
            exit;

        xRecRef.Open(RecRef.Number, false, RecRef.CurrentCompany());
        xRecRef.ReadIsolation := xRecRef.ReadIsolation::ReadCommitted;
        xRecRef."SecurityFiltering" := SECURITYFILTER::Filtered;
        if xRecRef.ReadPermission() then begin
            IsReadable := true;
            if not xRecRef.Get(RecRef.RecordId) then
                exit;
        end;

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
        NewDataJson: Text;
        PrimaryKey: Text;
        IsTemporary: Boolean;
    begin
        NewDataJson := RecordToJson(RecRef);
        PrimaryKey := GetPrimaryKeyText(RecRef);
        IsTemporary := IsTemporaryTable(RecRef);

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
        if TableMetadata.Get(RecRef.Number()) then
            exit(TableMetadata.TableType = TableMetadata.TableType::Temporary);

        // If we can't find metadata, we can also try to detect based on RecordRef behavior
        // Temporary tables typically have different characteristics
        exit(false);
    end;
}