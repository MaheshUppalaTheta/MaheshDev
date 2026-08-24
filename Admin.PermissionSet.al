permissionset 72930453 "Admin_TSA_TSL"
{
    Caption = 'Troubleshooting Assistance - Admin';
    Assignable = true;
    IncludedPermissionSets = "Operator_TSA_TSL";
    Permissions =
        tabledata "Setup_TSA_TSL" = RIMD,
        tabledata "Agent Cue_TSA_TSL" = RIMD,
        codeunit "Agent Diagnose_TSA_TSL" = X,
        codeunit "Agent Factory_TSA_TSL" = X,
        codeunit "Agent Metadata_TSA_TSL" = X,
        codeunit "Agent Task Execution_TSA_TSL" = X,
        codeunit "Agent Install_TSA_TSL" = X,
        codeunit "Agent Provision_TSA_TSL" = X,
        page "Setup_TSA_TSL" = X,
        page "Agent Activities_TSA_TSL" = X,
        page "Agent Role Center_TSA_TSL" = X,
        page "Agent Setup_TSA_TSL" = X;
}
