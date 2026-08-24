codeunit 72930456 "Agent Factory_TSA_TSL" implements IAgentFactory
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
        exit(Page::"Agent Setup_TSA_TSL");
    end;

    procedure ShowCanCreateAgent(): Boolean
    begin
        // Allow creation from the UI; this is a single-purpose troubleshooting agent.
        exit(true);
    end;

    procedure GetCopilotCapability(): Enum "Copilot Capability"
    begin
        exit(Enum::"Copilot Capability"::"Troubleshoot Agent_TSA_TSL");
    end;

    procedure GetDefaultProfile(var TempAllProfile: Record "All Profile" temporary)
    var
        ModuleInfo: ModuleInfo;
    begin
        // Default the agent to the dedicated Troubleshooting Assistance Agent role center.
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        TempAllProfile."Profile ID" := 'Agent Profile_TSA_TSL';
        TempAllProfile."App ID" := ModuleInfo.Id();
        TempAllProfile.Insert();
    end;

    procedure GetDefaultAccessControls(var TempAccessControlBuffer: Record "Access Control Buffer" temporary)
    var
        ModuleInfo: ModuleInfo;
    begin
        // Grant the agent the Troubleshooting Assistance permission set so it can read the captured data and open
        // the Troubleshooting Assistance pages.
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        TempAccessControlBuffer."Role ID" := 'Full Access_TSA_TSL';
        TempAccessControlBuffer."App ID" := ModuleInfo.Id();
        TempAccessControlBuffer.Scope := TempAccessControlBuffer.Scope::System;
        TempAccessControlBuffer.Insert();
    end;
}
