permissionset 50003 "DD-Admin"
{
    Caption = 'Data Debugger - Admin';
    Assignable = true;
    IncludedPermissionSets = "DD-Operator";
    Permissions =
        tabledata "Data Debugger Setup" = RIMD,
        tabledata "DD Agent Cue" = RIMD,
        codeunit "DD Agent Diagnose" = X,
        codeunit "DD Agent Factory" = X,
        codeunit "DD Agent Metadata" = X,
        codeunit "DD Agent Task Execution" = X,
        codeunit "DD Agent Install" = X,
        codeunit "DD Agent Provision" = X,
        page "Data Debugger Setup" = X,
        page "DD Agent Activities" = X,
        page "DD Agent Role Center" = X,
        page "DD Agent Setup" = X;
}
