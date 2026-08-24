permissionset 72930452 "Operator_TSA_TSL"
{
    Caption = 'Troubleshooting Assistance - Operator';
    Assignable = true;
    IncludedPermissionSets = "Reader_TSA_TSL";
    Permissions =
        tabledata "Change Buffer_TSA_TSL" = RIMD,
        tabledata "Analysis Buffer_TSA_TSL" = RIMD,
        tabledata "Live Stats_TSA_TSL" = RIMD,
        tabledata "Recording State_TSA_TSL" = RIMD,
        tabledata "Table Filter_TSA_TSL" = RIMD,
        tabledata "Field Select Buffer_TSA_TSL" = RIMD,
        tabledata "Table Pick Buffer_TSA_TSL" = RIMD,
        codeunit "Session Manager_TSA_TSL" = X,
        codeunit "Filter Manager_TSA_TSL" = X,
        codeunit "Context Manager_TSA_TSL" = X,
        codeunit "Event Handlers_TSA_TSL" = X,
        codeunit "Analysis Engine_TSA_TSL" = X,
        page "Table Filters_TSA_TSL" = X,
        page "Field Selection_TSA_TSL" = X,
        page "Table Pick_TSA_TSL" = X;
}
