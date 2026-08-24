# AL Development Standards

You are working on a Microsoft Dynamics 365 Business Central AL extension project.

## Naming Conventions
- Table extensions: `Tab-Ext{ID}.{PascalCaseName}.al`
- Page extensions: `Pag-Ext{ID}.{PascalCaseName}.al`
- Codeunits: `Cod{ID}.{PascalCaseName}.al`
- Enums: `Enum{ID}.{PascalCaseName}.al`
- Test codeunits: `Cod{ID}.{PascalCaseName}Tests.al`

## Object ID Ranges
- Use IDs in range 72930450–72930499

## AL Best Practices
- Always set `DataClassification` on every table field
- Use `ApplicationArea = All` on all page fields and actions
- Always include `ToolTip` on page fields
- Add `IntegrationEvent` publishers in codeunits for extensibility
- Use `CalcFields` before accessing FlowField values
- Follow GIVEN/WHEN/THEN pattern for test codeunits
- Prefix custom fields with a short app identifier if needed

## Target Environment
- Business Central Sandbox (Cronus demo data)
- Runtime: 14.0
- Application version: 24.0.0.0 or later

## Code Style
- Use meaningful variable names (not abbreviations)
- Add XML documentation comments (`/// <summary>`) on all procedures
- Keep procedures under 30 lines where possible
- Use `CopyStr` when assigning to Code/Text fields from expressions
