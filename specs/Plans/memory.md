## 2026-08-02 - tsa-multi-user-hardening
- Requirement approved with true multi-user recording as non-negotiable (Option B).
- Architecture documented at specs/Plans/2026-08-02-tsa-multi-user-hardening/tsa-multi-user-hardening.architecture.md.
- Priority sequence fixed: Wave 0 safety/correctness, Wave 1 AppSource compliance, Wave 2 runtime robustness, Wave 3 security/test hardening.
- Decomposition chosen: Spec A (core), Spec B (compliance), Spec C (security/tests) with order A+B parallel then C.

## 2026-08-02 - spec generation complete
- Created specs/Plans/2026-08-02-tsa-multi-user-hardening/tsa-hardening-core.spec.md.
- Created specs/Plans/2026-08-02-tsa-multi-user-hardening/tsa-hardening-compliance.spec.md.
- Created specs/Plans/2026-08-02-tsa-multi-user-hardening/tsa-hardening-security-tests.spec.md.
- Execution dependency confirmed: run Spec A and Spec B in parallel, then Spec C.

## 2026-08-02 - tsa-multi-user-hardening DONE
- Status: complete (all 4 phases)
- 16 AL objects modified or created; 17 tests in 2 codeunits (50140 + 50142)
- Critical bugs fixed: nested cursor, GetClientType, xRecRef pre-open, Modify/Delete permission guard
- AppSource compliance: app.json metadata, DataClassification overrides on 9 fields, LearnMoreUrl fixed
- Security: monolithic permissionset decomposed into DD-Reader/Operator/Admin (50001-50003)
- Demo subscriber deactivated: DemoBadExtension [EventSubscriber] attribute removed
- Known deviations: DataDebuggerSetup.GetSetup() has Insert() re-added by user; ff.al remains compiled
- BCQuality: active, bundled — all blockers/majors resolved before commit
- Next: author real privacy policy, run full test suite in BC Sandbox, PR targeting main
