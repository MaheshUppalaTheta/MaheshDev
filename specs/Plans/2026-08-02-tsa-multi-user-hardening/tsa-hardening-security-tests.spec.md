# Spec C: TroubleShooting Assitance Hardening Security and Tests

Date: 2026-08-02
Status: Approved
Source Architecture: specs/Plans/2026-08-02-tsa-multi-user-hardening/tsa-multi-user-hardening.architecture.md
Owner: AL Implementation Team

## 1. Goal
Finalize hardening through least-privilege permissions, release artifact hygiene, and expanded automated tests for multi-user scenarios.

## 2. Scope
### In Scope
- Permission-set redesign from broad generated permissions to role-based least privilege.
- Ensure non-production demo/test artifacts are excluded from production release package.
- Expand automated test coverage for multi-user and edge-case behaviors.

### Out of Scope
- New business features.
- Major architecture redesign away from global trigger approach.

## 3. Preconditions
- Spec A completed and merged.
- Spec B completed and merged.

## 4. Functional Requirements
1. Permission model split into at least:
- Reader
- Operator
- Admin

2. Reader role must not have destructive rights beyond viewing/reporting use cases.

3. Production artifact must not include demo-dangerous objects intended only for branch/local testing.

4. Test coverage must include:
- Multi-user recording flow (A starts, B acts).
- Table scope include/exclude behavior.
- Field-selection filtering behavior.
- Throttling behavior under burst changes.
- Regression checks for fixes from Spec A.

5. Test packaging strategy must avoid shipping test objects in production app artifacts.

## 5. Target Objects
- GeneratedPermission.permissionset.al (or replacement permission-set files)
- src/Tests/*.al
- app/test project structure files (if split introduced)
- src/Temp/DemoBadExtension.al (release exclusion strategy)
- ff.al (artifact hygiene review)

## 6. Design Notes
- Use composed permission sets where possible.
- Keep operational UX intact while tightening access.
- If branch needs demo object, enforce explicit release exclusion mechanism.

## 7. Non-Functional Requirements
- No blocking changes to expected admin workflows.
- Security posture improved without sacrificing diagnosability.

## 8. Acceptance Criteria
1. Permission sets are role-based and least-privilege.
2. Production package excludes demo-dangerous artifacts.
3. Expanded tests pass in CI.
4. Regression tests from Spec A remain green.
5. No unexpected analyzer violations introduced.

## 9. Test Plan
- Execute full AL test suite.
- Add dedicated multi-user scenario tests.
- Add permission-context tests where applicable.
- Validate packaging outputs do not contain excluded artifacts.

## 10. Delivery Tasks
1. Define and implement role-based permission sets.
2. Apply production artifact exclusion strategy for demo/test objects.
3. Expand test suite for multi-user and filter/throttle edge cases.
4. Validate CI pipeline for compile + tests + analyzers.

## 11. Dependencies
- Depends on Spec A and Spec B completion.

## 12. Done Definition
- All acceptance criteria met.
- Release-readiness checklist passes for permissions, packaging, and QA coverage.
