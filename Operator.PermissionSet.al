permissionset 50002 "DD-Operator"
{
    Caption = 'Data Debugger - Operator';
    Assignable = true;
    IncludedPermissionSets = "DD-Reader";
    Permissions =
        tabledata "Data Debugger Change Buffer" = RIMD,
        tabledata "Data Debugger Analysis Buffer" = RIMD,
        tabledata "Data Debugger Live Stats" = RIMD,
        tabledata "DD Recording State" = RIMD,
        tabledata "Data Debugger Table Filter" = RIMD,
        tabledata "DD Field Selection Buffer" = RIMD,
        tabledata "DD Table Pick Buffer" = RIMD,
        codeunit "Data Debugger Session Manager" = X,
        codeunit "Data Debugger Filter Manager" = X,
        codeunit "Data Debugger Context Manager" = X,
        codeunit "Data Debugger Event Handlers" = X,
        codeunit "Data Debugger Analysis Engine" = X,
        page "Data Debugger Table Filters" = X,
        page "DD Field Selection" = X,
        page "DD Table Pick" = X;
}
