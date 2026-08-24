codeunit 72930462 "Test Error Runner_TSA_TSL"
{
    // Test helper. Modifies the passed Customer and then raises an error. When invoked via
    // Codeunit.Run(), the platform rolls back the database change — but any Troubleshooting Assistance capture
    // that happened in memory (rollback-safe mode) survives, which is exactly what the tests assert.
    TableNo = Customer;

    trigger OnRun()
    begin
        Rec.Validate(Name, CopyStr(Rec.Name + 'QZX99', 1, MaxStrLen(Rec.Name)));
        Rec.Modify(true);
        Error('Simulated process failure to force a rollback.');
    end;
}
