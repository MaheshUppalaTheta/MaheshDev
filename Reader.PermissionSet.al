permissionset 72930451 "Reader_TSA_TSL"
{
    Caption = 'Troubleshooting Assistant - Reader';
    Assignable = true;
    Permissions =
        tabledata "Change Buffer_TSA_TSL" = R,
        tabledata "Analysis Buffer_TSA_TSL" = R,
        tabledata "Live Stats_TSA_TSL" = R,
        tabledata "Table Pick Buffer_TSA_TSL" = R,
        tabledata "Field Select Buffer_TSA_TSL" = R,
        page "Troubleshooting_TSA_TSL" = X,
        page "Results_TSA_TSL" = X,
        page "Field Changes_TSA_TSL" = X,
        page "Context Details_TSA_TSL" = X,
        page "Table Summary_TSA_TSL" = X,
        page "Transactions_TSA_TSL" = X,
        page "Live Stats_TSA_TSL" = X,
        page "Advanced Analysis_TSA_TSL" = X,
        page "Change Entry Preview_TSA_TSL" = X,
        page "Change Entry API_TSA_TSL" = X;
}
