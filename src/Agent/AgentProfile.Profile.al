/// <summary>
/// Profile for the Troubleshooting Assistance Agent.
/// Uses a dedicated, minimal Role Center ("Agent Role Center_TSA_TSL") so the agent's surface is small
/// and it can reliably navigate to the Troubleshooting Assistance Changes list via Role Center links/actions.
/// </summary>
profile "Agent Profile_TSA_TSL"
{
    Caption = 'Troubleshooting Assistance Agent';
    Description = 'Profile for the Troubleshooting Assistance Agent with access to the captured data changes.';
    RoleCenter = "Agent Role Center_TSA_TSL";
}
