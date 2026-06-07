/// <summary>
/// Adds the DD Change Entry Preview page to the navigation
/// so the Data Debugger Agent can find and open it.
/// </summary>
pagecustomization "DD Agent Role Center Cust" customizes "Business Manager Role Center"
{
    actions
    {
        addfirst(Sections)
        {
            group("Data Debugger")
            {
                Caption = 'Data Debugger';

                action("DD Change Entry Preview")
                {
                    Caption = 'DD Change Entry Preview';
                    ApplicationArea = All;
                    RunObject = page "DD Change Entry Preview";
                }
            }
        }
    }
}
