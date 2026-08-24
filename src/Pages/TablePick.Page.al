page 72930466 "Table Pick_TSA_TSL"
{
    PageType = List;
    Caption = 'Tables in Results';
    SourceTable = "Table Pick Buffer_TSA_TSL";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = None;
    Editable = false;
    SourceTableView = sorting("Table Name");

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Table ID"; Rec."Table ID")
                {
                    ToolTip = 'The table ID.';
                }
                field("Table Name"; Rec."Table Name")
                {
                    ToolTip = 'The table name.';
                }
                field("Change Count"; Rec."Change Count")
                {
                    ToolTip = 'How many captured operations belong to this table.';
                }
            }
        }
    }

    procedure LoadTables(var Src: Record "Change Buffer_TSA_TSL" temporary)
    begin
        Rec.Reset();
        Rec.DeleteAll();

        Src.Reset();
        if Src.FindSet() then
            repeat
                if Rec.Get(Src."Table ID") then begin
                    Rec."Change Count" += 1;
                    Rec.Modify();
                end else begin
                    Rec.Init();
                    Rec."Table ID" := Src."Table ID";
                    Rec."Table Name" := Src."Table Name";
                    Rec."Change Count" := 1;
                    Rec.Insert();
                end;
            until Src.Next() = 0;

        Rec.Reset();
        if Rec.FindFirst() then;
    end;

    procedure GetSelected(var TableId: Integer; var TableName: Text)
    begin
        TableId := Rec."Table ID";
        TableName := Rec."Table Name";
    end;
}
