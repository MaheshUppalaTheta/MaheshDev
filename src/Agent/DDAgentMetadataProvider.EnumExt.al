enumextension 50006 "DD Agent Metadata Provider" extends "Agent Metadata Provider"
{
    // Registers the Data Debugger agent type and binds it to its three interface implementations.
    value(50100; "Data Debugger Agent")
    {
        Caption = 'Data Debugger Agent';
        Implementation =
            IAgentFactory = "DD Agent Factory",
            IAgentMetadata = "DD Agent Metadata",
            IAgentTaskExecution = "DD Agent Task Execution";
    }
}
