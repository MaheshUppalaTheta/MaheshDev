permissionset 72930450 "Full Access_TSA_TSL"
{
    Caption = 'Troubleshooting Assistant - Full Access (prefer Reader_TSA_TSL / Operator_TSA_TSL / Admin_TSA_TSL)';
    // Backward-compatible alias. Assign Reader_TSA_TSL, Operator_TSA_TSL, or Admin_TSA_TSL instead.
    Assignable = true;
    IncludedPermissionSets = "Admin_TSA_TSL";
}