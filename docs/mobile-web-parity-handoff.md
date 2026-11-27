# Mobile to web parity handoff

Date: 2026-11-27
Status: Web implementation pending. Mobile behavior is the reference.

## Product behavior to implement on web

1. **Show briefs before qualification and KYC.**
   - Remove `unlockedDiscoverBriefs` filtering from Discover.
   - Keep explicit status, tier, category, audience, sort and paging rules.
   - Do not hide unstarted live briefs from unqualified or tier-0 contributors.

2. **Gate Start, not viewing.**
   - Existing submissions still open normally.
   - Closed, full, past-deadline and outside-audience states keep their current priority.
   - Otherwise, Start opens a requirement dialog/sheet before submit.
   - The first unmet requirement is qualification, then KYC Tier 1.
   - Provide a clear graphic, short copy and one primary CTA.
   - After qualification or KYC completes, return to the brief and continue to submit.
   - Direct submit URLs and structured deliverable flows must use the same gate.

3. **Handle qualification states explicitly.**
   - Can take: proceed to qualification.
   - Can resume: continue the active test.
   - Unavailable/cooldown: explain without a misleading forward CTA.
   - Loading with no trusted answer: checking state, no forward CTA.
   - Passed: never show the qualification nudge again.

4. **Handle KYC states explicitly.**
   - Tier 0: route to identity verification.
   - Tier 1+: submission requirement is satisfied.
   - Loading with no status: checking state.
   - Error with no usable status: fail closed and offer retry.
   - A higher-tier withdrawal requirement does not block a C1 submission.
   - Discover's KYC nudge should explain both submission and withdrawal requirements.
   - Keep the web-style unavailable/error nudge.

5. **Use NIN for contributor Tier 1.**
   - Remove BVN from the Tier 1 identity selector and copy.
   - Force NIN even if a legacy status reports BVN.
   - Tier 2+ may retain BVN for existing verification flows.
   - Map `409 KYC_DUPLICATE` to generic copy: the identity is already linked to another account. Never reveal account details.

6. **Handle API refusals.**
   - `403 ASSESSMENT_REQUIRED` keeps precedence when both gates fail.
   - `403 KYC_REQUIRED` includes `{ requiredTier, currentTier, nextCheck }`.
   - Same-key replay is checked before eligibility and still returns the stored submission.
   - Existing submission reads are never gated.

## Mobile reference files

- `lib/features/submit/start_requirements.dart`
- `lib/features/submit/start_requirements_sheet.dart`
- `lib/features/submit/submit_screen.dart`
- `lib/features/kyc/kyc_status.dart`
- `lib/features/kyc/kyc_nudge.dart`
- `lib/features/kyc/kyc_sheet.dart`
- `lib/features/onboarding/setup_nudge_state.dart`
- `lib/data/assessment_service.dart`

## Suggested tests

- Unqualified and tier-0 users still see unstarted briefs.
- Start opens the requirement dialog, not submit.
- Direct submit cannot bypass either gate.
- Qualification completion returns to the originating brief.
- KYC completion returns to the originating brief or submit flow.
- Assessment refusal wins when both requirements fail.
- `KYC_REQUIRED` maps to the verification handoff.
- `KYC_DUPLICATE` never leaks another account.
- Tier 1 is NIN-only, including legacy BVN status.
- Existing submission redirect happens before either gate.
- Closed/full/deadline/audience states remain unchanged.

## Backend contract references

- Platform `docs/mobile-api.md`
- `apps/api/src/modules/submissions/submissions.service.ts`
- `apps/api/src/modules/verification/verification.service.ts`
- `apps/api/src/modules/verification/verification.exceptions.ts`
