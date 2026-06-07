/// <summary>
/// Profile for the Data Debugger Agent.
/// Uses the standard Business Manager role center but gives
/// the agent a distinct profile so page customizations can be applied.
/// </summary>
profile "DD Agent Profile"
{
    Caption = 'Data Debugger Agent';
    Description = 'Profile for the Data Debugger Agent with access to DD Change Entry Preview.';
    RoleCenter = "Business Manager Role Center";
    Customizations = "DD Agent Role Center Cust";
}
