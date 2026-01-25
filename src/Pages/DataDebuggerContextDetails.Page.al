page 50006 "Data Debugger Context Details"
{
    Caption = 'Context Details';
    PageType = Card;
    SourceTable = "Data Debugger Change Buffer";
    Editable = false;
    SourceTableTemporary = true;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            group(ChangeInfo)
            {
                Caption = 'Change Information';

                field("Table Name"; Rec."Table Name")
                {
                    ApplicationArea = All;
                }

                field("Change Type"; Rec."Change Type")
                {
                    ApplicationArea = All;
                }

                field("Primary Key"; Rec."Primary Key")
                {
                    ApplicationArea = All;
                }

                field(Timestamp; Rec.Timestamp1)
                {
                    ApplicationArea = All;
                }
            }

            group(UserContext)
            {
                Caption = 'User Context';

                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                }

                field("User Name"; Rec."User Name")
                {
                    ApplicationArea = All;
                }

                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                }

                field("Session ID"; Rec."Session ID")
                {
                    ApplicationArea = All;
                }

                field("Client Type"; Rec."Client Type")
                {
                    ApplicationArea = All;
                }
            }

            group(TransactionContext)
            {
                Caption = 'Transaction Context';

                field("Transaction ID"; Rec."Transaction ID")
                {
                    ApplicationArea = All;
                }

                field("Trigger Source"; Rec."Trigger Source")
                {
                    ApplicationArea = All;
                }
            }

            group(CallStackGroup)
            {
                Caption = 'Call Stack';

                field(CallStackField; CallStackText)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    ShowCaption = false;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewRelatedChanges)
            {
                Caption = 'View Related Changes';
                ToolTip = 'View all changes in the same transaction';
                Image = RelatedInformation;

                trigger OnAction()
                var
                    RelatedChanges: Record "Data Debugger Change Buffer";
                    RelatedPage: Page "Data Debugger Results";
                begin
                    RelatedChanges.SetRange("Transaction ID", Rec."Transaction ID");
                    RelatedPage.SetTableView(RelatedChanges);
                    RelatedPage.RunModal();
                end;
            }
        }
    }

    var
        CallStackText: Text;

    procedure SetChangeRecord(var ChangeRec: Record "Data Debugger Change Buffer")
    begin
        // Ensure BLOB fields are loaded
        ChangeRec.CalcFields("Call Stack");

        Rec := ChangeRec;
        CallStackText := Rec.GetCallStack();
        CurrPage.Update();
    end;
}
