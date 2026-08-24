enumextension 72930450 "Agent Metadata Prov_TSA_TSL" extends "Agent Metadata Provider"
{
    // Registers the Troubleshooting Assistance agent type and binds it to its three interface implementations.
    value(72930450; "Troubleshoot Agent_TSA_TSL")
    {
        Caption = 'Troubleshooting Assistance Agent';
        Implementation =
            IAgentFactory = "Agent Factory_TSA_TSL",
            IAgentMetadata = "Agent Metadata_TSA_TSL",
            IAgentTaskExecution = "Agent Task Execution_TSA_TSL";
    }
}
