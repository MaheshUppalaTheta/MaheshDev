permissionset 50001 "DD-Reader"
{
    Caption = 'Data Debugger - Reader';
    Assignable = true;
    Permissions =
        tabledata "Data Debugger Change Buffer" = R,
        tabledata "Data Debugger Analysis Buffer" = R,
        tabledata "Data Debugger Live Stats" = R,
        tabledata "DD Table Pick Buffer" = R,
        tabledata "DD Field Selection Buffer" = R,
        page "Data Debugger" = X,
        page "Data Debugger Results" = X,
        page "Data Debugger Field Changes" = X,
        page "Data Debugger Context Details" = X,
        page "Data Debugger Table Summary" = X,
        page "Data Debugger Transactions" = X,
        page "Data Debugger Live Stats" = X,
        page "DD Advanced Analysis" = X,
        page "DD Change Entry Preview" = X,
        page "DD Change Entry API" = X;
}
