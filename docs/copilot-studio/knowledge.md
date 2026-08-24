# Troubleshooting Assistant — Knowledge Reference

Upload this file to the **Knowledge** section of your Copilot Studio agent. It provides reference data the agent needs when analyzing Troubleshooting Assistant change entries.

---

## Common Business Central Table IDs

Use these to filter change entries by table when investigating specific areas.

| Table ID | Table Name | Used In |
|----------|------------|---------|
| 15 | G/L Account | Chart of Accounts |
| 17 | G/L Entry | General Ledger postings |
| 18 | Customer | Customer master data |
| 21 | Cust. Ledger Entry | Customer postings |
| 23 | Vendor | Vendor master data |
| 25 | Vendor Ledger Entry | Vendor postings |
| 27 | Item | Item master data |
| 32 | Item Ledger Entry | Inventory postings |
| 36 | Sales Header | Sales document headers (Quotes, Orders, Invoices, Credit Memos) |
| 37 | Sales Line | Sales document lines |
| 38 | Purchase Header | Purchase document headers |
| 39 | Purchase Line | Purchase document lines |
| 81 | Gen. Journal Line | General journal lines |
| 83 | Item Journal Line | Item journal lines |
| 112 | Sales Invoice Header | Posted sales invoices |
| 113 | Sales Invoice Line | Posted sales invoice lines |
| 114 | Sales Cr.Memo Header | Posted sales credit memos |
| 115 | Sales Cr.Memo Line | Posted sales credit memo lines |
| 122 | Purch. Inv. Header | Posted purchase invoices |
| 123 | Purch. Inv. Line | Posted purchase invoice lines |
| 254 | VAT Entry | VAT/GST postings |
| 325 | VAT Posting Setup | VAT/GST rate configuration |
| 379 | Detailed Cust. Ledg. Entry | Detailed customer ledger |
| 380 | Detailed Vendor Ledg. Entry | Detailed vendor ledger |
| 5802 | Value Entry | Inventory valuation entries |
| 5407 | Prod. Order Line | Production order lines |
| 5773 | Registered Whse. Activity Line | Warehouse postings |

## Change Entry Fields

Each Troubleshooting Assistant change entry contains these fields:

| Field | Type | Description |
|-------|------|-------------|
| entryNo | Integer | Unique sequential ID of the change |
| runId | GUID | Groups all entries from one recording session |
| timestamp | DateTime | When the database operation occurred |
| tableId | Integer | The BC table that was changed |
| tableName | Text | Human-readable table name |
| changeType | Text | Insert, Modify, Delete, or Rename |
| primaryKey | Text | The primary key values of the affected record |
| userId | Text | Who triggered the change |
| userName | Text | Display name of the user |
| transactionId | GUID | Groups changes in the same database transaction |
| triggerSource | Text | What initiated the database operation |
| oldData | JSON | Field values BEFORE the change (empty for Insert) |
| newData | JSON | Field values AFTER the change (empty for Delete) |
| callStack | Text | Full AL call stack at the moment of the change |

## OData Filter Syntax for the API

The Change Entries API supports OData V4 filtering. Use these patterns:

| Goal | Filter |
|------|--------|
| Sales Line changes only | `tableId eq 37` |
| Sales Header changes only | `tableId eq 36` |
| Only Modify operations | `changeType eq 'Modify'` |
| Only Insert operations | `changeType eq 'Insert'` |
| Sales Line modifications | `tableId eq 37 and changeType eq 'Modify'` |
| Specific document | `contains(primaryKey, '101021')` |
| Specific user | `userId eq 'ADMIN'` |
| Multiple tables | `tableId eq 36 or tableId eq 37` |
| After a specific time | `timestamp gt 2026-06-01T00:00:00Z` |

Ordering: `timestamp desc` (most recent first) or `entryNo desc`

Select specific fields: `entryNo,timestamp,tableId,tableName,changeType,primaryKey,oldData,newData,callStack`

## Analysis Patterns

### Pattern: Unexpected field value change
**Symptom**: A field like Unit Price, VAT %, or Quantity changes to an unexpected value during posting.
**How to find**: Filter by the relevant table (e.g., `tableId eq 37` for Sales Line) and `changeType eq 'Modify'`. Compare oldData vs newData across consecutive entries. The first entry where the value changes is the culprit.
**Key evidence**: The callStack of that entry reveals which codeunit changed it.

### Pattern: Wrong setup data applied
**Symptom**: Posted entries have wrong VAT %, posting groups, or dimension values.
**How to find**: Look at Insert entries for the posted tables (e.g., `tableId eq 254` for VAT Entry). Check the newData for the wrong values. Then trace backward through the Modify entries on the source document to see if the values were wrong from the start or changed during posting.

### Pattern: Third-party extension interference
**Symptom**: Values change during posting but the standard BC logic should not change them.
**How to find**: In the callStack, look for codeunit names that are NOT from "Base Application by Microsoft". These are extensions. The extension name and procedure will be visible in the call stack line (e.g., `"My Custom Extension"(CodeUnit 50050).OnBeforePostSalesDoc`).

### Pattern: Missing or extra records
**Symptom**: Expected ledger entries are missing, or unexpected records were created.
**How to find**: Filter by the expected table and `changeType eq 'Insert'` (for missing) or look at `changeType eq 'Delete'` (for removed records). Check the callStack to see what created or deleted them.

### Pattern: Rounding or calculation error
**Symptom**: Amounts are slightly off (e.g., 99.99 instead of 100.00).
**How to find**: Track the Amount, Line Amount, or VAT Amount fields through consecutive Modify entries. The entry where the rounding goes wrong will show the calculation step in its callStack.

## Call Stack Reading Guide

Call stacks are listed from innermost (top) to outermost (bottom). Example:

```
"Sales Line"(Table 37).UpdateVATOnLines line 193 - Base Application by Microsoft
"Release Sales Document"(CodeUnit 414).CalcAndUpdateVATOnLines line 9 - Base Application by Microsoft
"Sales-Post"(CodeUnit 80).CheckAndUpdate line 48 - Base Application by Microsoft
"Demo Bad Extension"(CodeUnit 72930464).OnBeforePostSalesDoc line 12 - TroubleShooting Assistant by Theta Systems Limited
```

Reading this:
1. The actual database write happened in `UpdateVATOnLines` (Table 37)
2. It was called by `Release Sales Document` (CU 414)
3. Which was called during `Sales-Post` (CU 80)
4. BUT the chain was initiated by `Demo Bad Extension` (CU 72930464) — a non-Microsoft extension subscribing to `OnBeforePostSalesDoc`

**Rule of thumb**: Scan from bottom to top. The first non-Microsoft entry is usually the root cause.
