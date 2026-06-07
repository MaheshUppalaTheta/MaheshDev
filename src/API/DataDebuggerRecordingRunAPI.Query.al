// query 50101 "DD Recording Run API"
// {
//     QueryType = API;
//     Caption = 'Data Debugger Recording Run';
//     APIPublisher = 'theta';
//     APIGroup = 'dataDebugger';
//     APIVersion = 'v1.0';
//     EntityName = 'recordingRun';
//     EntitySetName = 'recordingRuns';

//     elements
//     {
//         dataitem(changeEntry; "Data Debugger Change Buffer")
//         {
//             // Grouped by Run ID (the only non-aggregated column).
//             column(runId; "Run ID")
//             {
//                 Caption = 'Run ID';
//             }
//             column(changeCount; "Entry No.")
//             {
//                 Caption = 'Change Count';
//                 Method = Count; // Count of entries per Run ID, since "Entry No." is auto-incremented for each change.;

//             }
//             column(firstChange; Timestamp1)
//             {
//                 Caption = 'First Change';
//                 Method = Min;
//             }
//             column(lastChange; Timestamp1)
//             {
//                 Caption = 'Last Change';
//                 Method = Max;
//             }
//         }
//     }
// }
