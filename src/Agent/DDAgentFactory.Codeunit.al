codeunit 50006 "DD Agent Factory" implements IAgentFactory
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    procedure GetDefaultInitials(): Text[4]
    begin
        exit('DD');
    end;

    procedure GetFirstTimeSetupPageId(): Integer
    begin
        exit(Page::"DD Agent Setup");
    end;

    procedure ShowCanCreateAgent(): Boolean
    begin
        // Allow creation from the UI; this is a single-purpose troubleshooting agent.
        exit(true);
    end;

    procedure GetCopilotCapability(): Enum "Copilot Capability"
    begin
        exit(Enum::"Copilot Capability"::"Data Debugger Agent");
    end;

    procedure GetDefaultProfile(var TempAllProfile: Record "All Profile" temporary)
    var
        ModuleInfo: ModuleInfo;
    begin
        // Default the agent to the dedicated Data Debugger Agent role center.
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        TempAllProfile."Profile ID" := 'DD Agent Profile';
        TempAllProfile."App ID" := ModuleInfo.Id();
        TempAllProfile.Insert();
    end;

    procedure GetDefaultAccessControls(var TempAccessControlBuffer: Record "Access Control Buffer" temporary)
    var
        ModuleInfo: ModuleInfo;
    begin
        // Grant the agent the Data Debugger permission set so it can read the captured data and open
        // the Data Debugger pages.
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        TempAccessControlBuffer."Role ID" := 'GeneratedPermission';
        TempAccessControlBuffer."App ID" := ModuleInfo.Id();
        TempAccessControlBuffer.Scope := TempAccessControlBuffer.Scope::System;
        TempAccessControlBuffer.Insert();
    end;
}
