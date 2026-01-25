// Startup script for Data Debugger Record Comparison Control Add-in
// This script runs when the control add-in loads

console.log('Data Debugger Record Comparison Control Add-in loaded');

// Notify Business Central that the control is ready
if (typeof Microsoft !== 'undefined' && 
    Microsoft.Dynamics && 
    Microsoft.Dynamics.NAV && 
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod) {
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady', []);
    console.log('Control Add-in ready notification sent to AL');
}
