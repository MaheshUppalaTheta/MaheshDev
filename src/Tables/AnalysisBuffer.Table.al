table 50004 "Data Debugger Analysis Buffer"
{
    Caption = 'Data Debugger Analysis Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(10; "Analysis Type"; Enum "Data Debugger Analysis Type")
        {
            Caption = 'Analysis Type';
        }
        field(11; "Category"; Text[50])
        {
            Caption = 'Category';
        }
        field(12; "Description"; Text[250])
        {
            Caption = 'Description';
        }
        field(13; "Value"; Decimal)
        {
            Caption = 'Value';
            DecimalPlaces = 2 : 5;
        }
        field(14; "Value Text"; Text[100])
        {
            Caption = 'Value Text';
        }
        field(15; Severity; Enum "Data Debugger Severity")
        {
            Caption = 'Severity';
        }
        field(16; "Related Table ID"; Integer)
        {
            Caption = 'Related Table ID';
        }
        field(17; "Related Table Name"; Text[250])
        {
            Caption = 'Related Table Name';
        }
        field(18; "Details"; Blob)
        {
            Caption = 'Details';
        }
        field(19; "Analysis Timestamp"; DateTime)
        {
            Caption = 'Analysis Timestamp';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(AnalysisType; "Analysis Type", "Severity")
        {
        }
    }

    procedure SetDetails(DetailsText: Text)
    var
        OutStream: OutStream;
    begin
        Details.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(DetailsText);
    end;

    procedure GetDetails(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        InStream: InStream;
    begin
        CalcFields(Details);
        if not Details.HasValue() then
            exit('');
        Details.CreateInStream(InStream, TextEncoding::UTF8);
        // Read every line so multi-line detail text is not truncated to the first line.
        exit(TypeHelper.ReadAsTextWithSeparator(InStream, TypeHelper.LFSeparator()));
    end;
}
