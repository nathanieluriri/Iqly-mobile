# Mobile Requirement Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show all briefs, gate starting submissions through qualification then KYC Tier 1, make mobile Tier 1 NIN-only, and make setup/qualification nudges deterministic stale-while-revalidate state machines.

**Architecture:** Account-scoped synchronous nudge snapshots drive visible state; lifecycle coordinators refresh only stale nonterminal state. One shared requirement resolver drives phone, tablet and direct-submit gates. Existing pushed assessment/KYC flows return to their caller.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, GoRouter, existing iQLY sheet/button/illustration components, Flutter tests.

**Spec:** `docs/superpowers/specs/2026-11-27-mobile-nudge-state-design.md`

## Global Constraints

- Target the `1.1.2+17` mobile line; prefer a Shorebird patch after verification.
- Use Bun for platform work and Flutter 3.50.0 locally; never npm/yarn.
- Mobile commits use `nathanieluriri <uririnathaniel@gmail.com>`, no AI attribution and no em dashes.
- No web behavior changes in this pass, only TODO comments and a handoff document.
- Preserve existing submission, deadline, audience, full, payout, targeting, hold and fee behavior.
- No raw NIN storage in mobile beyond the existing KYC request flow.
- Do not run additional gauntlet/critic rounds.
- Full Flutter suite has known baseline failures; focused tests and analysis are the completion gate.

## Review Focus

- Expired cached qualification state must remain visible/hidden offline until successful replacement.
- A passed qualification must never regress to first-check after a cold launch or account switch.
- Partial Skip and web-completed onboarding must converge on the same complete state without stale local answers.
- Direct submit, drafts and tablet Start must not bypass qualification/KYC.
- Tier 1 legacy BVN status must still submit NIN and never show BVN copy.

---

### Task 1: Assessment snapshot controller

**Files:**
- Modify: `lib/data/assessment_data.dart`
- Modify: `lib/data/assessment_service.dart`
- Create: `test/data/assessment_access_state_test.dart`
- Modify: `test/data/assessment_nudge_test.dart`

**Interfaces:**
- Produces: `AssessmentAccessState`, `assessmentAccessProvider`, `AssessmentAccessController.refresh({bool force = false})`, `AssessmentAccessController.apply(AssessmentAccess)`.
- Consumes: account-scoped SharedPreferences and `accountScopeProvider`.

- [ ] Add `AssessmentAccess.toJson()` and a persisted `{access, fetchedAt}` snapshot model.
- [ ] Replace the bare `FutureProvider` with a synchronous `NotifierProvider<AssessmentAccessController, AssessmentAccessState>` containing `access`, `fetchedAt`, `refreshing`, `error`, `terminalPassed`.
- [ ] Read account-scoped snapshot and terminal receipt synchronously in `build()`.
- [ ] Implement 15-minute stale-while-revalidate refresh; failures retain value and `fetchedAt`.
- [ ] On pass, delete the access snapshot, write `assessment.qualified.<userId>`, enter terminal and skip requests.
- [ ] Guard all async writes/results with the current account scope and user ID.
- [ ] Write failing tests for expired offline retention, failed refresh timestamp retention, successful replacement, pass receipt, cold terminal launch and account isolation.
- [ ] Run `flutter test test/data/assessment_access_state_test.dart test/data/assessment_nudge_test.dart`.
- [ ] Commit `feat(mobile): cache qualification access state`.

### Task 2: Setup nudge reconciliation and state

**Files:**
- Modify: `lib/data/live/live_account.dart`
- Modify: `lib/features/onboarding/onboarding_draft.dart`
- Create: `lib/features/onboarding/setup_nudge_state.dart`
- Modify: `lib/features/onboarding/setup_nudge.dart`
- Modify: `lib/features/discover/home_screen.dart`
- Create: `test/features/onboarding/setup_nudge_state_test.dart`

**Interfaces:**
- Produces: `SetupNudgeState`, `setupNudgeStateProvider`, `OnboardingDraftNotifier.reconcileServer(ContributorProfile, pendingWrites)`.
- Consumes: `sessionProvider`, `onboardingDraftProvider`, `meProvider`, pending account outbox writes.

- [ ] Write failing tests for first run, partial Skip, locally completed draft, under-age reopening, never-started returning account and server/web completion.
- [ ] Map server profile fields over the local draft, then overlay pending onboarding/profile writes.
- [ ] Derive pending/complete reactively; server completion or zero effective steps completes and persists session/draft.
- [ ] Remove `_shown` and Home's permanent `_nudge` visibility latch.
- [ ] Invalidate/refresh `meProvider` on manual Home refresh and app resume with a 6-hour freshness policy.
- [ ] Ensure completion removes setup refresh listeners through provider disposal.
- [ ] Run setup, onboarding draft/flow and live account focused tests.
- [ ] Commit `feat(mobile): reconcile setup nudge state`.

### Task 3: Shared requirement resolver and sheet

**Files:**
- Create: `lib/features/submit/start_requirements.dart`
- Create: `lib/features/submit/start_requirements_sheet.dart`
- Create: `test/features/submit/start_requirements_test.dart`
- Create: `test/features/submit/start_requirements_sheet_test.dart`

**Interfaces:**
- Produces: `StartRequirement`, `resolveStartRequirements(AssessmentAccessState, KycState)`, `showStartRequirementsSheet(BuildContext, Brief)`.
- Consumes: `assessmentAccessProvider`, `kycControllerProvider`.

- [ ] Write failing resolver tests for checking, qualification, resume, unavailable, KYC, KYC unavailable and ready.
- [ ] Implement the exact priority table from the spec.
- [ ] Build the sheet with existing grabber/radius/footer patterns, writer/identity illustrations and `IqButton`.
- [ ] Watch assessment/KYC providers so completion advances or closes the sheet automatically.
- [ ] Return `true` only when ready; caller opens `Routes.submitTo(brief.id)`.
- [ ] Run resolver and sheet tests.
- [ ] Commit `feat(mobile): add start requirement sheet`.

### Task 4: Discover visibility and Start integration

**Files:**
- Modify: `lib/features/discover/home_screen.dart`
- Modify: `lib/features/discover/tablet_discover.dart`
- Modify: `lib/features/discover/brief_detail_screen.dart`
- Modify: `lib/features/discover/tablet_brief_detail.dart`
- Modify: `lib/data/assessment_data.dart`
- Modify: `test/data/assessment_nudge_test.dart`
- Create: `test/features/discover_requirement_visibility_test.dart`

**Interfaces:**
- Consumes: `showStartRequirementsSheet`.
- Produces: unfiltered live brief membership independent of assessment access.

- [ ] Write failing phone/tablet tests proving unqualified users see unstarted live briefs.
- [ ] Remove `unlockedDiscoverBriefs()` filtering and the qualification-specific empty feed.
- [ ] Keep explicit status/tier/category filters, sorting and paging unchanged.
- [ ] Route phone and tablet Start through the requirement sheet after existing submitted/closed/full/audience checks.
- [ ] Run Discover visibility and existing pure assessment tests.
- [ ] Commit `feat(mobile): show briefs before qualification`.

### Task 5: Assessment and KYC return navigation

**Files:**
- Modify: `lib/features/assessments/assessment_screen.dart`
- Modify: `lib/features/assessments/assessment_nudge.dart`
- Modify: `lib/router.dart`
- Modify: `lib/features/kyc/kyc_routes.dart`
- Modify: `lib/features/submit/submit_screen.dart`
- Modify: `test/features/submit_flow_test.dart`
- Create: `test/features/requirement_navigation_test.dart`

**Interfaces:**
- Consumes: `AssessmentAccessController.apply/refresh`, `KycScreen`.
- Produces: pushed assessment/KYC flows that pop back to their caller.

- [ ] Write failing navigation tests for brief to sheet to qualification to KYC to submit, plus direct-submit qualification and KYC guards.
- [ ] Publish assessment results into the controller instead of blind invalidation.
- [ ] On pass, pop to the caller; fall back Home only when no page can be popped.
- [ ] Mount `KycScreen` at `Routes.kyc` so completion pops and shared controller state updates.
- [ ] Replace SubmitScreen's assessment-only redirect with the shared requirement resolver; preserve already-submitted opening.
- [ ] Run navigation and focused submit tests, updating only expectations changed by the new sheet.
- [ ] Commit `feat(mobile): return requirement flows to briefs`.

### Task 6: NIN-only Tier 1 and KYC nudge/controller

**Files:**
- Modify: `lib/features/kyc/kyc_status.dart`
- Modify: `lib/features/kyc/kyc_sheet.dart`
- Modify: `lib/features/kyc/kyc_controller.dart`
- Modify: `lib/features/kyc/kyc_nudge.dart`
- Modify: `lib/features/wallet/kyc_sheet.dart`
- Modify: `test/data/kyc_service_test.dart`
- Modify: `test/features/kyc/kyc_flow_test.dart`
- Create: `test/features/kyc/kyc_submission_state_test.dart`

**Interfaces:**
- Produces: `KycStatus.canSubmit`, `KycStatus.ninOnly`, `KycNudgeSurface`, KYC `fetchedAt`/refresh retention.
- Consumes: existing KYC service and controller.

- [ ] Write failing tests for `canSubmit`, Tier 1 NIN-only with legacy BVN status, Tier 2 BVN availability and surface-aware nudge visibility/error copy.
- [ ] Force NIN for `requiredTier == 1`; hide selector and use NIN-only validation/copy.
- [ ] Preserve last good KYC status on refresh failure and add freshness metadata.
- [ ] Refresh KYC on resume/manual refresh while nonterminal; stop when Discover submission and withdrawal requirements are both complete.
- [ ] Refresh shared controller after withdrawal KYC completion.
- [ ] Run KYC service/flow/submission-state tests.
- [ ] Commit `feat(mobile): require nin for tier one`.

### Task 7: Web comments, handoff and verification

**Files:**
- Modify: `docs/superpowers/specs/2026-11-27-mobile-nudge-state-design.md`
- Create: `docs/mobile-web-parity-handoff.md`
- Modify: focused test fixtures only where the new requirement sheet adds a step

**Interfaces:**
- Produces: web handoff document and verified mobile branch.

- [ ] Update the spec checkboxes/status with delivered behavior and any implementation-specific names.
- [ ] Write `docs/mobile-web-parity-handoff.md` covering Discover visibility, requirement handoff, KYC gate errors, NIN-only Tier 1, nudge copy/error state and duplicate identity copy.
- [ ] Run `dart format --output=none --set-exit-if-changed lib test tool`.
- [ ] Run `flutter analyze --no-fatal-infos`.
- [ ] Run all focused tests touched by this plan plus Android inset/Saved regression tests.
- [ ] Run `git diff --check` and inspect the final diff.
- [ ] Commit `docs(mobile): add web parity handoff`.
- [ ] Confirm `pubspec.yaml` remains `1.1.2+17`; prepare Shorebird patch inputs without publishing until checks pass.
