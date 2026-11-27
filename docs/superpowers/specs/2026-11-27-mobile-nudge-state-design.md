# Mobile requirement gates and nudge state design

Date: 2026-11-27
Status: Implemented on mobile; web handoff pending.
Scope: Flutter mobile first. Web receives comments and a handoff document only.

## 1. Product behavior

- Show every otherwise eligible live brief on Discover, regardless of qualification or KYC.
- Viewing a brief is always allowed.
- Starting a new submission requires, in order:
  1. Qualification access.
  2. Contributor KYC Tier 1.
- Tapping Start on an otherwise startable brief opens a requirement sheet.
- The sheet explains the first unmet requirement with an illustration, short copy and one primary CTA.
- Qualification and KYC happen in pushed flows. Completing them returns to the sheet or submit screen that launched them.
- When all requirements pass, the sheet closes and the original submit flow opens.
- Direct submit routes, drafts and tablet flows use the same requirement resolver and cannot bypass the gates.
- Existing submissions remain viewable. Closed, full, outside-audience and already-submitted briefs keep their current priority.
- Mobile contributor Tier 1 is NIN-only. BVN remains available for higher tiers and legacy status parsing.

## 2. Shared stale-while-revalidate contract

Freshness controls refresh scheduling only. It never invalidates visible state.

- A snapshot is `{ value, fetchedAt }`, scoped to the signed-in account.
- `stale = now >= fetchedAt + ttl`.
- A stale snapshot remains the visible value until a successful response replaces it.
- Offline, timeout and failed refresh keep both the snapshot and its original `fetchedAt`.
- A successful response atomically replaces the value and sets `fetchedAt = now`.
- No snapshot ever uses the documented first-check default.
- Late responses from a previous account scope are ignored.
- Terminal confirmation removes refresh listeners and unnecessary pending snapshots.
- Manual pull-to-refresh forces a refresh when nonterminal.
- App resume and restored connectivity refresh only when stale, or when a forced refresh is requested.

TTLs:

- Assessment access: 15 minutes.
- Onboarding/account reconciliation: 6 hours.
- KYC status: 15 minutes while a submission or withdrawal requirement remains incomplete.

## 3. Setup nudge state machine

The setup nudge is derived state, not a one-time visibility latch.

### State

- `pendingFirstRun`: session says onboarding is not done.
- `pendingUnderAge`: the local draft explicitly rejected the date of birth.
- `pendingPartial`: onboarding was skipped or deferred and relevant draft steps remain.
- `pendingServerIncomplete`: a server profile snapshot exists and its effective answers still leave relevant steps.
- `complete`: server completion is confirmed, or effective relevant answers are complete.
- `refreshing`: orthogonal flag; it does not change pending/complete visibility.

### Effective answers

1. If no server profile snapshot exists, use the local onboarding draft.
2. If a server profile exists, map its non-null values over the local draft.
3. Overlay pending onboarding/profile outbox writes last, because they are newer than the server snapshot.
4. `onboardingCompletedAt != null` is authoritative completion unless the local draft is explicitly under-age.
5. A returning account with `onboardingDone == true` and a never-started empty local draft does not create a new first-run nudge unless a server profile proves fields are incomplete.

### Transitions

| Event | Next state | Side effects |
| --- | --- | --- |
| Initial local state, no server answer | pending or complete from session/draft | Render immediately |
| Final Skip with relevant answers missing | `pendingPartial` | Keep draft and show nudge |
| Missing relevant answer is filled locally | `complete` when none remain | Stop setup refresh listeners |
| Under-age refusal | `pendingUnderAge` | Reopen setup even if previously done |
| `/me` refresh or cached `/me` has `onboardingCompletedAt` | `complete` | Set session done, reconcile draft, clear pending setup state |
| Server profile fills city/interests/other missing answers | `complete` when effective `stepsLeft == 0` | Persist reconciled draft and session done |
| Server profile is still partial | `pendingServerIncomplete` | Persist reconciled draft |
| Refresh fails/offline | unchanged | Keep cached/local state and timestamp |
| Account changes | reset | Ignore late responses and never leak state |

The existing onboarding draft is the local default cache. The existing account-scoped `/me` cache is the server snapshot. No extra setup boolean is introduced.

## 4. Qualification nudge state machine

### State

- `firstCheck`: no terminal receipt and no access snapshot.
- `showNeeded`: cached/live access can take the test.
- `showResume`: cached/live access can resume an active session.
- `hiddenWaiting`: cached/live access is unavailable or otherwise cannot take/resume.
- `terminalPassed`: server-confirmed pass.
- `refreshing` and `error`: orthogonal flags.

### Persistence

Use account-scoped SharedPreferences keys so the first frame is synchronous:

- `assessment.access.<userId>`: serialized `AssessmentAccess` plus `fetchedAt`.
- `assessment.qualified.<userId>`: minimal terminal receipt containing `qualifiedAt`.

The terminal receipt is not a refresh cache. It prevents a cold launch from looking like a first-ever user after the full snapshot is removed.

### Transitions

| Event | Next state | Side effects |
| --- | --- | --- |
| Cold launch with terminal receipt | `terminalPassed` | No request, no listener |
| Cold launch with snapshot | derive show/hidden from snapshot | Render immediately, then refresh if stale |
| Cold launch with neither | `firstCheck` | Show default while first refresh runs |
| Successful `canTake` | `showNeeded` | Replace snapshot and timestamp |
| Successful `canResume` | `showResume` | Replace snapshot and timestamp |
| Successful `unavailable` | `hiddenWaiting` | Replace snapshot and timestamp |
| Successful pass | `terminalPassed` | Delete access snapshot, write terminal receipt, stop listeners |
| Refresh fails/offline | unchanged | Preserve snapshot and timestamp |
| Snapshot expires | unchanged visible state | Mark stale; refresh on next trigger |
| Account changes | reset | Ignore late responses and use the new account key |

A pass is terminal in the current API (`passedAt` is not revoked), so no periodic qualification requests are made after the receipt exists.

## 5. Start requirement resolver

Inputs are assessment state, KYC state and existing brief/submission eligibility.

| Priority | Condition | Result |
| --- | --- | --- |
| 1 | Existing submission | View submission |
| 2 | Closed, full, deadline passed or outside audience | Existing disabled/blocked UI |
| 3 | Assessment is first-check/loading and no cached answer | `checking` |
| 4 | Assessment can resume | `qualificationResume` |
| 5 | Assessment can take | `qualification` |
| 6 | Assessment unavailable/other non-passing | `qualificationUnavailable` |
| 7 | Assessment passed, KYC loading with no status | `checking` |
| 8 | KYC status failed/offline with no usable status | `kycUnavailable` |
| 9 | KYC Tier 0 | `kyc` |
| 10 | KYC Tier 1+ | `ready` |

Primary actions:

- `qualification`: “Proceed to qualification”.
- `qualificationResume`: “Continue qualification”.
- `kyc`: “Proceed to verification”.
- `ready`: close the sheet and open submit.
- Unavailable states do not show a misleading forward CTA; they offer retry where useful.

The same resolver powers phone Start, tablet Start, direct SubmitScreen entry and draft entry.

## 6. Navigation and completion

- Requirement sheet is pushed with `showIqSheet`.
- Assessment is pushed above the sheet/screen.
- On pass, publish the authoritative access result, then pop to the caller. Fall back Home only when there is no page to pop.
- KYC route mounts `KycScreen`, whose completion callback pops to its caller.
- The requirement sheet watches provider changes:
  - Pass + KYC ready: close with `ready == true`, then open submit.
  - Pass + KYC missing: switch to the KYC step.
  - KYC complete: close with `ready == true`, then open submit.
- Direct SubmitScreen reacts to the same provider changes and reveals the form without rebuilding the navigation stack.

## 7. KYC status and nudge

- Add `KycStatus.canSubmit`: verified and effective tier at least 1.
- Add `KycStatus.ninOnly`: required Tier is exactly 1.
- Tier 1 forces NIN even if a legacy status says BVN, hides the method selector and uses NIN-only validation/copy.
- Tier 2+ retains NIN/BVN selection.
- KYC refresh preserves the last good status on failure and records `fetchedAt`, `refreshing` and `error`.
- Withdrawal completion refreshes the shared KYC controller.
- Nudge visibility is surface-aware:
  - Discover: show unless both submission and withdrawal requirements are satisfied.
  - Submission: show unless `canSubmit`.
  - Withdrawal: show unless `canWithdraw`.
  - Error without status: show an unavailable state instead of disappearing.
- Once both Discover requirements are complete, stop KYC refresh listeners.

## 8. Lifecycle and listeners

- Small nonterminal refresh coordinators watch app resume and connectivity.
- They are disposed automatically when their derived state becomes terminal.
- Home pull-to-refresh and dock re-entry force nonterminal nudge refreshes.
- `/me` is invalidated/refreshed on resume and pull so onboarding completed on web is detected.
- No timer polls indefinitely. TTL is evaluated on lifecycle, connectivity and manual refresh triggers.

## 9. Web handoff

Web behavior is not implemented in this pass. Add TODO comments at the relevant web gates and create `docs/mobile-web-parity-handoff.md` after mobile implementation, covering Discover visibility, requirement handoff, KYC submission errors, NIN-only Tier 1, KYC nudge copy and duplicate identity copy.

## 10. Acceptance checks

- Partial Skip keeps setup visible; completing missing fields hides it.
- Server/web completion reconciles city and interests and hides setup.
- Expired assessment snapshot remains visible/hidden offline until replaced.
- Failed assessment refresh preserves `fetchedAt`.
- Passed qualification writes a terminal receipt, removes the snapshot and stops requests.
- All live briefs remain visible to unqualified users on phone and tablet.
- Start opens the requirement sheet; direct submit cannot bypass it.
- Qualification/KYC completion returns to the originating flow.
- Tier 1 offers NIN only, including legacy BVN status input.
- Existing submitted, closed, full and audience rules are unchanged.

## 11. Delivered implementation map

- Qualification snapshot/controller: `lib/data/assessment_service.dart`.
- Setup reconciliation/state: `lib/features/onboarding/setup_nudge_state.dart`.
- Shared requirement resolver: `lib/features/submit/start_requirements.dart`.
- Requirement sheet: `lib/features/submit/start_requirements_sheet.dart`.
- Direct-submit guard: `lib/features/submit/submit_screen.dart`.
- NIN-only Tier 1 and KYC readiness: `lib/features/kyc/kyc_status.dart`.
- KYC nudge/error/freshness: `lib/features/kyc/kyc_nudge.dart`, `lib/features/kyc/kyc_controller.dart`.
- Web handoff: `docs/mobile-web-parity-handoff.md`.
