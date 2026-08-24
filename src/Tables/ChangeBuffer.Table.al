table 72930450 "Change Buffer_TSA_TSL"
{
    Caption = 'Troubleshooting Assistant Change Buffer';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Run ID"; Guid)
        {
            Caption = 'Run ID';
        }
        field(3; Timestamp1; DateTime)
        {
            Caption = 'Timestamp';
        }
        field(4; "Table ID"; Integer)
        {
            Caption = 'Table ID';
        }
        field(5; "Table Name"; Text[250])
        {
            Caption = 'Table Name';
        }
        field(6; "Change Type"; Enum "Change Type_TSA_TSL")
        {
            Caption = 'Change Type';
        }
        field(7; "Primary Key"; Text[500])
        {
            Caption = 'Primary Key';
            DataClassification = CustomerContent;
        }
        field(8; "Old Data"; Blob)
        {
            Caption = 'Old Data';
            DataClassification = CustomerContent;
        }
        field(9; "New Data"; Blob)
        {
            Caption = 'New Data';
            DataClassification = CustomerContent;
        }
        field(10; "Record Count"; Integer)
        {
            Caption = 'Record Count';
            InitValue = 1;
        }
        field(11; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserPseudonymousIdentifiers;
        }
        field(12; "User Name"; Text[80])
        {
            Caption = 'User Name';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(13; "Company Name"; Text[30])
        {
            Caption = 'Company Name';
        }
        field(14; "Session ID"; Integer)
        {
            Caption = 'Session ID';
        }
        field(15; "Transaction ID"; Guid)
        {
            Caption = 'Transaction ID';
        }
        field(16; "Call Stack"; Blob)
        {
            Caption = 'Call Stack';
            DataClassification = CustomerContent;
        }
        field(17; "Trigger Source"; Text[250])
        {
            Caption = 'Trigger Source';
        }
        field(18; "Client Type"; Text[50])
        {
            Caption = 'Client Type';
        }
        field(19; "Is Temporary Table"; Boolean)
        {
            Caption = 'Is Temporary Table';
            ToolTip = 'Indicates whether the modification was made on a temporary table or a real database table';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(RunTimestamp; "Run ID", Timestamp1)
        {
        }
        key(TableType; "Run ID", "Table ID", "Change Type")
        {
        }
        key(Transaction; "Run ID", "Transaction ID", Timestamp1)
        {
        }
        key(User; "Run ID", "User ID", Timestamp1)
        {
        }
    }

    procedure SetOldData(DataText: Text)
    var
        OutStream: OutStream;
    begin
        "Old Data".CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(DataText);
    end;

    procedure GetOldData(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
    begin
        CalcFields("Old Data");
        if not "Old Data".HasValue() then
            exit('');

        "Old Data".CreateInStream(InStream, TextEncoding::UTF8);
        // Read every line: a single InStream.ReadText stops at the first line break, which would
        // truncate any multi-line content (e.g. a field value containing a newline).
        exit(TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator()));
    end;

    procedure SetNewData(DataText: Text)
    var
        OutStream: OutStream;
    begin
        "New Data".CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(DataText);
    end;

    procedure GetNewData(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
    begin
        CalcFields("New Data");
        if not "New Data".HasValue() then
            exit('');

        "New Data".CreateInStream(InStream, TextEncoding::UTF8);
        // Read every line (see GetOldData) so multi-line content is not truncated.
        exit(TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator()));
    end;

    procedure SetCallStack(CallStackText: Text)
    var
        OutStream: OutStream;
    begin
        "Call Stack".CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(CallStackText);
    end;

    procedure GetCallStack(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
    begin
        CalcFields("Call Stack");
        if not "Call Stack".HasValue() then
            exit('');

        "Call Stack".CreateInStream(InStream, TextEncoding::UTF8);
        // A call stack is multi-line: read all lines (a single InStream.ReadText would return only
        // the first frame). Rejoined with LF so the whole stack is shown/exported.
        exit(TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator()));
    end;
}
