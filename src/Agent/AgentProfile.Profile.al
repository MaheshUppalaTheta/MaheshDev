/// <summary>
/// Profile for the Data Debugger Agent.
/// Uses a dedicated, minimal Role Center ("DD Agent Role Center") so the agent's surface is small
/// and it can reliably navigate to the Data Debugger Changes list via Role Center links/actions.
/// </summary>
profile "DD Agent Profile"
{
    Caption = 'Data Debugger Agent';
    Description = 'Profile for the Data Debugger Agent with access to the captured data changes.';
    RoleCenter = "DD Agent Role Center";
}
